FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Edmonton
ENV TERM=xterm-256color
# Opt out of tool telemetry wherever the DO_NOT_TRACK convention is honoured (bd 1.3.4 metrics: verified
# 2026-11-06, OFF with DO_NOT_TRACK=1 and a fresh HOME). `bd metrics off` alone lives in ~/.config, lost on rebuild.
ENV DO_NOT_TRACK=1

# Base packages
RUN apt-get update && apt-get install -y \
    sudo \
    git \
    curl \
    wget \
    vim \
    nano \
    python3 \
    python3-pip \
    build-essential \
    tmux \
    openssh-server \
    tzdata \
    jq \
    ca-certificates \
    gnupg \
    unzip \
    autoconf \
    libncurses-dev \
    libssl-dev \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install just (command runner) - available to all users
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
# Install dolt (pinned): the beads tracker runs in Dolt server mode (alm-cywx), where `bd` starts
# `dolt sql-server` on demand. Measured 2026-10-19 with this version; embedded mode serialises
# concurrent bd calls and was the cause of the 60 s bd timeouts.
ARG DOLT_VERSION=2.5.0
RUN curl -fsSL "https://github.com/dolthub/dolt/releases/download/v${DOLT_VERSION}/dolt-linux-$(dpkg --print-architecture).tar.gz" \
    | tar -xz -C /tmp \
    && install -m 0755 "/tmp/dolt-linux-$(dpkg --print-architecture)/bin/dolt" /usr/local/bin/dolt \
    && rm -rf /tmp/dolt-linux-* \
    && dolt version | grep -q "${DOLT_VERSION}"
# Install asdf — used ONLY as the installer for Erlang/Elixir at build time. It is not on PATH
# at runtime: its bin/asdf resolves ../lib relative to the symlink (so /usr/local/bin/asdf broke),
# and its shims need a per-user .tool-versions + ASDF_DATA_DIR that the agent user never had.
RUN git clone https://github.com/asdf-vm/asdf.git /opt/asdf --branch v0.14.1

# Install Erlang and Elixir (shared, all users). ASDF_DATA_DIR is what decides where installs go;
# without it they land in the build user's $HOME/.asdf (/root, mode 700) — which is exactly what
# the Sep-22 image did, leaving /opt/asdf/installs empty and every shim symlink dangling.
# ASDF_* is set for this RUN only, and the shims are deleted: the 10-22 image exported both as ENV,
# so `. /opt/asdf/asdf.sh` looked like the way in, and its shims point MIX_ARCHIVES into the
# root-owned install (`mix local.hex` → permission denied).
# Note: Erlang builds from source (~2 min with pre-cached deps), Elixir is precompiled
ARG ERLANG_VERSION=26.2.5.21
ARG ELIXIR_VERSION=1.17.3
RUN export ASDF_DIR=/opt/asdf ASDF_DATA_DIR=/opt/asdf && \
    . /opt/asdf/asdf.sh && \
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git && \
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git && \
    asdf install erlang ${ERLANG_VERSION} && \
    asdf install elixir ${ELIXIR_VERSION} && \
    rm -rf /opt/asdf/shims && \
    chmod -R a+rX /opt/asdf && \
    test -x /opt/asdf/installs/erlang/${ERLANG_VERSION}/bin/erl && \
    test -x /opt/asdf/installs/elixir/${ELIXIR_VERSION}/bin/elixir
# Link the real binaries into /usr/local/bin, which every PATH here contains: Docker's, the
# /etc/environment one that PAM installs for ssh and `su` (entrypoint starts tmux via `su`), and
# systemd's default. An `ENV PATH=` entry reaches none of the PAM paths — the 10-22 image had one,
# and `mix` was missing in every tmux shell. Symlinks to real files are safe; elixir and erl resolve
# their own location through the link.
RUN for f in /opt/asdf/installs/elixir/${ELIXIR_VERSION}/bin/* /opt/asdf/installs/erlang/${ERLANG_VERSION}/bin/*; do \
        ln -sf "$f" /usr/local/bin/; \
    done
# Elixir expects a UTF-8 locale; without it the VM runs latin1 filename encoding and warns on every call.
ENV LANG=C.UTF-8
ENV ELIXIR_ERL_OPTIONS="+fnu"
# Build-time proof that the toolchain resolves through a minimal PATH (no shim, no asdf, no rc file):
# the Sep-22 image passed every file test above and still had a dangling `mix`. The PAM-path proof
# (`su agent`) runs after the user exists, below.
RUN env -i HOME=/root PATH=/usr/local/bin:/usr/bin:/bin mix --version 2>&1 | tee /dev/stderr | grep -q "Mix ${ELIXIR_VERSION}" && \
    ! command -v asdf

# Docker CLI + compose plugin (for Docker-out-of-Docker: socket mounted from host)
# Pre-create docker group with host's GID (985) so docker-ce-cli adopts it
RUN groupadd -g 985 docker 2>/dev/null || true
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL for doc-editor/ZedDocs development and tests (MVP spec 2026-11-06: Postgres from the
# start). From the PGDG repo, not Ubuntu's 14, so dev runs the major version production will.
# postgresql-common is told not to create its default cluster under /var/lib (ephemeral, owned by
# a `postgres` user): the entrypoint initialises one cluster on the workspace, owned by agent, and
# supervisord runs it (conf.d/postgres.conf). The data directory is per major version, so a bump
# starts a fresh, empty cluster instead of failing on the old one's files.
ARG PG_MAJOR=17
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt $(. /etc/os-release && echo "$VERSION_CODENAME")-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y postgresql-common \
    && sed -i 's/^#\?create_main_cluster.*/create_main_cluster = false/' /etc/postgresql-common/createcluster.conf \
    && apt-get install -y postgresql-${PG_MAJOR} postgresql-client-${PG_MAJOR} \
    && rm -rf /var/lib/apt/lists/* \
    && /usr/lib/postgresql/${PG_MAJOR}/bin/postgres --version | grep -q "(PostgreSQL) ${PG_MAJOR}\." \
    && test -f /usr/share/postgresql/${PG_MAJOR}/extension/ltree.control \
    && test -z "$(ls -A /var/lib/postgresql/${PG_MAJOR} 2>/dev/null)"

# Create homelab group for shared access (GID 1005)
# This group will be used for shared directories between host and container
RUN groupadd -g 1005 homelab

# SSHD host keys are NOT generated here. The entrypoint installs stable host keys
# from ~/secrets at boot so known_hosts survives rebuilds; the build-time keys
# openssh-server generates are overwritten there.

# Create group with gid 1004 and user with uid 1003 to match host bind-mount ownership
# Also add agent to homelab (shared access) and docker (socket access) groups
RUN groupadd -g 1004 agent \
    && useradd -m -s /bin/bash -u 1003 -g 1004 -G homelab,docker agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir /var/run/sshd && \
    mkdir -p /home/agent/.ssh && \
    chown agent:agent /home/agent/.ssh && \
    chmod 700 /home/agent/.ssh

COPY ./authorized_keys /home/agent/.ssh/authorized_keys

RUN chown agent:agent /home/agent/.ssh/authorized_keys && \
    chmod 644 /home/agent/.ssh/authorized_keys

# The shell Logan works in: tmux started through `su`, which resets PATH from /etc/environment.
RUN su -s /bin/bash agent -c 'mix --version' | grep -q "Mix ${ELIXIR_VERSION}"
# PAM shells (ssh, `su`) drop the ENV LANG/ELIXIR_ERL_OPTIONS above, so Elixir ran latin1 there and
# warned on every call. pam_env reads /etc/environment for both; prove a login shell is UTF-8.
RUN printf 'LANG=C.UTF-8\nELIXIR_ERL_OPTIONS=+fnu\nDO_NOT_TRACK=1\n' >> /etc/environment && \
    su - agent -c 'elixir -e "IO.puts :file.native_name_encoding()"' 2>&1 | tee /dev/stderr | grep -qx utf8 && \
    su - agent -c 'printenv DO_NOT_TRACK' | grep -qx 1

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# User packages
USER agent
WORKDIR /home/agent

# Install pass-cli (Proton Pass CLI for secrets management)
# Must run as agent so it installs to /home/agent/.local/bin/
RUN curl -fsSL https://proton.me/download/pass-cli/install.sh | bash

# Tmux config: enable extended keys for modified inputs like Ctrl+Enter
RUN echo '# Enable extended keys so tmux can recognize modified inputs like Ctrl+Enter' > /home/agent/.tmux.conf && \
    echo 'set -s extended-keys on' >> /home/agent/.tmux.conf && \
    echo '' >> /home/agent/.tmux.conf && \
    echo '# Tell tmux to enable extended keys if you are using an xterm-based terminal' >> /home/agent/.tmux.conf && \
    echo "set -as terminal-features 'xterm*:extkeys'" >> /home/agent/.tmux.conf && \
    echo '# Use the mouse' >> /home/agent/.tmux.conf && \
    echo "set -g mouse on" >> /home/agent/.tmux.conf

# NVM install
ENV NVM_DIR=/home/agent/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
ENV BASH_ENV="$NVM_DIR/nvm.sh"
SHELL ["/bin/bash", "-c"]
ENV NODE_VERSION=24.21.0
RUN nvm install $NODE_VERSION
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"
ENV PATH="$PATH:/home/agent/.local/bin"

# Claude Code (native installer → /home/agent/.local/bin/claude, already on PATH)
RUN curl -fsSL https://claude.ai/install.sh | bash
# claude-statusbar (`cs`): status line for every session, wired by managed settings in entrypoint.sh.
# CS_SKIP_SETUP: its own --setup writes ~/.claude/settings.json, which ignores CLAUDE_CONFIG_DIR.
RUN CS_SKIP_SETUP=1 bash -c "curl -fsSL https://raw.githubusercontent.com/leeguooooo/claude-code-usage-bar/main/install.sh | bash"
RUN curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
# Hex and rebar in ~/.mix: without Hex, mix cannot load gardenOS at all ("Could not find an SCM for
# dependency :ecto_sql"), even with deps/ already fetched on the volume.
RUN mix local.hex --force && mix local.rebar --force
# dolt checks for a newer release on every CLI call and prints a warning; that is a network call
# per bd invocation and noise in bd's output.
RUN dolt config --global --add versioncheck.disabled true

USER root

# supervisord is PID 1 (entrypoint.sh execs it); its config replaces the package default.
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY postgres.conf /etc/supervisor/conf.d/postgres.conf
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
