FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Edmonton
ENV TERM=xterm-256color

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
    && rm -rf /var/lib/apt/lists/*

# Install just (command runner) - available to all users
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
# Install asdf — used ONLY as the installer for Erlang/Elixir at build time. It is not on PATH
# at runtime: its bin/asdf resolves ../lib relative to the symlink (so /usr/local/bin/asdf broke),
# and its shims need a per-user .tool-versions + ASDF_DATA_DIR that the agent user never had.
RUN git clone https://github.com/asdf-vm/asdf.git /opt/asdf --branch v0.14.1

# Install Erlang and Elixir (shared, all users). ASDF_DATA_DIR is what decides where installs go;
# without it they land in the build user's $HOME/.asdf (/root, mode 700) — which is exactly what
# the Sep-22 image did, leaving /opt/asdf/installs empty and every shim symlink dangling.
# Note: Erlang builds from source (~2 min with pre-cached deps), Elixir is precompiled
ARG ERLANG_VERSION=26.2.5
ARG ELIXIR_VERSION=1.17.3
ENV ASDF_DIR=/opt/asdf
ENV ASDF_DATA_DIR=/opt/asdf
RUN . /opt/asdf/asdf.sh && \
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git && \
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git && \
    asdf install erlang ${ERLANG_VERSION} && \
    asdf install elixir ${ELIXIR_VERSION} && \
    chmod -R a+rX /opt/asdf && \
    test -x /opt/asdf/installs/erlang/${ERLANG_VERSION}/bin/erl && \
    test -x /opt/asdf/installs/elixir/${ELIXIR_VERSION}/bin/elixir
# Real bin dirs on PATH: no shims, no asdf at runtime, same toolchain for every user and for
# non-interactive processes (claude's Bash tool, gardenOS System.cmd children, hooks).
ENV PATH="/opt/asdf/installs/elixir/${ELIXIR_VERSION}/bin:/opt/asdf/installs/erlang/${ERLANG_VERSION}/bin:$PATH"
# Elixir expects a UTF-8 locale; without it the VM runs latin1 filename encoding and warns on every call.
ENV LANG=C.UTF-8
ENV ELIXIR_ERL_OPTIONS="+fnu"
# Build-time proof that the toolchain resolves through PATH alone (no shim, no asdf, no rc file):
# the Sep-22 image passed every file test above and still had a dangling `mix`.
RUN test "$(command -v mix)" = "/opt/asdf/installs/elixir/${ELIXIR_VERSION}/bin/mix" && \
    mix --version 2>&1 | tee /dev/stderr | grep -q "Mix ${ELIXIR_VERSION}" && \
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

RUN npm install -g @qwen-code/qwen-code@latest
RUN curl -fsSL https://omp.sh/install | sh
# Claude Code (native installer → /home/agent/.local/bin/claude, already on PATH)
RUN curl -fsSL https://claude.ai/install.sh | bash
# claude-statusbar (`cs`): status line for every session, wired by managed settings in entrypoint.sh.
# CS_SKIP_SETUP: its own --setup writes ~/.claude/settings.json, which ignores CLAUDE_CONFIG_DIR.
RUN CS_SKIP_SETUP=1 bash -c "curl -fsSL https://raw.githubusercontent.com/leeguooooo/claude-code-usage-bar/main/install.sh | bash"
RUN curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash

USER root

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
