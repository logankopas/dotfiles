#!/bin/bash
set -e

# Fix timezone (tzdata is now installed in the Dockerfile)
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo "$TZ" > /etc/timezone

# SSH key permissions
chown agent:agent /home/agent/.ssh/authorized_keys
chmod 644 /home/agent/.ssh/authorized_keys

# Install the GitHub deploy key from the read-only secrets mount.
# ~/.ssh is ephemeral, and ssh requires the private key to be 0600 and owned by
# the using user, so it cannot be used in place from ~/secrets (600, owner 1000).
if [ -f /home/agent/secrets/id_ed25519 ]; then
    install -m 600 -o agent -g agent /home/agent/secrets/id_ed25519 /home/agent/.ssh/id_ed25519
    if [ -f /home/agent/secrets/id_ed25519.pub ]; then
        install -m 644 -o agent -g agent /home/agent/secrets/id_ed25519.pub /home/agent/.ssh/id_ed25519.pub
    fi
fi

# Pin GitHub's SSH host keys so non-interactive git push/pull works on first use.
# ~/.ssh/known_hosts is ephemeral; without this, the first `git push` after a
# rebuild dies with "Host key verification failed". Keys are GitHub's published
# set (https://api.github.com/meta, ssh_keys) as of 2026-10-15; they rotate
# rarely and a mismatch fails closed rather than trusting a new key.
install -d -m 700 -o agent -g agent /home/agent/.ssh
cat > /home/agent/.ssh/known_hosts <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF
chown agent:agent /home/agent/.ssh/known_hosts
chmod 644 /home/agent/.ssh/known_hosts

# Claude Code managed settings: apply to every claude session on this box,
# whatever CLAUDE_CONFIG_DIR a seat uses (highest-precedence settings source).
# Status line = claude-statusbar (`cs`, installed in the Dockerfile). Verified
# 2026-10-15: `claude -p` never runs the statusLine, so fleet workers pay nothing.
# CLAUDE_STATUSBAR_NO_UPDATE also disables cs's self-upgrade; the Dockerfile owns its version.
install -d -m 755 /etc/claude-code
cat > /etc/claude-code/managed-settings.json <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "CLAUDE_STATUSBAR_NO_UPDATE=1 /home/agent/.local/bin/cs render",
    "refreshInterval": 1
  }
}
EOF
chmod 644 /etc/claude-code/managed-settings.json

# Boot wiring for seats is gone (2026-10-16): every seat, Cairn included, boots from
# ~/workspace/seats/<seat>/ via `just seat` / seats/seat.sh; hooks register in the
# seat's persistent .claude/settings.json. Nothing here to merge or symlink.

# Boot wiring: login to Proton Pass for secrets management
# PAT is mounted from host at ~/secrets (read-only)
PAT_FILE="/home/agent/secrets/proton-pass-pat"
if [ -f "$PAT_FILE" ]; then
    su -s /bin/bash agent -c "export PATH=\"/home/agent/.local/bin:\$PATH\" && export PROTON_PASS_KEY_PROVIDER=fs && /home/agent/.local/bin/pass-cli login --pat \$(cat $PAT_FILE)" || echo "Warning: Proton Pass login failed"
else
    echo "Warning: Proton Pass PAT file not found at $PAT_FILE"
fi

# Boot wiring: source bash functions from persistent workspace (idempotent)
BASHRC_LINE='source /home/agent/workspace/hooks/bash-functions.sh'
if ! grep -qF 'bash-functions.sh' /home/agent/.bashrc 2>/dev/null; then
    echo "$BASHRC_LINE" >> /home/agent/.bashrc
fi

# Install stable sshd host keys from the read-only secrets mount, before sshd
# starts. Keys baked at image build change on every rebuild, which forces the
# known_hosts entry for [localhost]:2222 to be re-accepted each time; a stable
# key here keeps it constant. Runs as root. Any key type present is installed.
for keytype in ed25519 rsa ecdsa; do
    if [ -f "/home/agent/secrets/ssh_host_${keytype}_key" ]; then
        install -m 600 -o root -g root "/home/agent/secrets/ssh_host_${keytype}_key" "/etc/ssh/ssh_host_${keytype}_key"
        if [ -f "/home/agent/secrets/ssh_host_${keytype}_key.pub" ]; then
            install -m 644 -o root -g root "/home/agent/secrets/ssh_host_${keytype}_key.pub" "/etc/ssh/ssh_host_${keytype}_key.pub"
        fi
    fi
done

# Boot wiring: persist omp config across rebuilds
# ~/.omp/agent/config.yml is ephemeral; ~/workspace/.omp-config/ is persistent.
# Restore if ephemeral missing, then always backup ephemeral → persistent so the
# persistent copy stays current (one session behind is better than forever stale).
su -s /bin/bash agent -c "
mkdir -p /home/agent/.omp/agent /home/agent/workspace/.omp-config/agent
if [ ! -f /home/agent/.omp/agent/config.yml ] && [ -f /home/agent/workspace/.omp-config/agent/config.yml ]; then
    cp /home/agent/workspace/.omp-config/agent/config.yml /home/agent/.omp/agent/config.yml
fi
if [ -f /home/agent/.omp/agent/config.yml ]; then
    cp /home/agent/.omp/agent/config.yml /home/agent/workspace/.omp-config/agent/config.yml
fi
"


 # Start SSH daemon
 /usr/sbin/sshd
su -s /bin/bash agent -c "tmux new-session -d -s agent"

# gardenOS's home (GARDENOS_HOME default): its supervisord program logs here, and
# supervisord opens that log before the program runs. Home is ephemeral, so every boot.
install -d -o agent -g agent /home/agent/.gardenos

# PID 1 from here on: reaps orphans, runs the programs the [include] globs find, and on
# `docker stop` stops each one within its stopwaitsecs (compose stop_grace_period covers it).
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
