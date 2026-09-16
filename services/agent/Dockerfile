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
    && rm -rf /var/lib/apt/lists/*

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

# SSHD setup
# Generate RSA host key only if missing
RUN [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' -q

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
    echo "set -as terminal-features 'xterm*:extkeys'" >> /home/agent/.tmux.conf

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
RUN curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash

USER root

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
