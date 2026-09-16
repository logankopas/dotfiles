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

# Boot wiring: QWEN.md symlink (ephemeral home dir, persistent workspace)
# Run as agent so the symlink is owned by the right user
su -s /bin/bash agent -c "ln -sf workspace/QWEN.md /home/agent/QWEN.md"

# Boot wiring: merge hooks into ephemeral settings.json
# The hooks config lives in the persistent workspace; settings.json dies on rebuild.
# This runs as agent so it writes to the right settings location.
su -s /bin/bash agent -c "python3 -c \"
import json, os
settings_path = os.path.expanduser('~/.qwen/settings.json')
hooks_path = '/home/agent/workspace/hooks/settings-hooks.json'
try:
    with open(settings_path) as f:
        settings = json.load(f)
    with open(hooks_path) as f:
        hooks = json.load(f)
    settings['hooks'] = hooks['hooks']
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
except Exception as e:
    print(f'Boot wiring error: {e}')
\""

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

# Start SSH daemon
/usr/sbin/sshd

# Start tmux session for interactive access
su -s /bin/bash agent -c "tmux new-session -d -s agent"

# Keep container running
tail -f /dev/null
