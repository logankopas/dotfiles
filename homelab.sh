#!/usr/bin/env bash
# Homelab provisioning script — idempotent, safe to run multiple times
# Target: Zorin OS 18+ / Ubuntu 24.04+
#
# Usage: sudo ./homelab.sh [--skip-docker] [--skip-services] [--skip-secrets]
#
# This script provisions a fresh homelab:
# - System users and groups (selfhosted group)
# - Docker
# - Secrets management (pass-cli + Proton Pass)
# - Service symlinks (docker files from dotfiles repo)
# - Service permissions (proper ownership for container UIDs)
# - Systemd services (link, daemon-reload, enable)
# - Docker image builds
# - Borg backup setup (borg/ -> /etc/borg, /usr/local/sbin/borg-backup, README onto /mnt/borg; see docs/operators-manual.md)
# - Login message (motd/ -> /etc/update-motd.d, noisy Ubuntu scripts disabled)
#
# SERVICE PATTERN:
# ----------------
# Config files live in dotfiles/services/<name>/ and are symlinked to /var/selfhosted/<name>/
# Data directories (volumes, databases, uploads) stay in /var/selfhosted/<name>/
#
# Secrets handling:
# - Secrets live in Proton Pass vault "homelab"
# - If a service has .env.template, the script generates .env from pass-cli
# - Template uses ${SECRET_NAME} placeholders that get replaced with actual values
#
# To add a new service:
# 1. Create dotfiles/services/<name>/ with docker-compose.yml
# 2. If service needs secrets, add .env.template with ${PLACEHOLDER} values
# 3. Add corresponding items to Proton Pass vault "homelab"
# 4. Create systemd/<name>.service if the service should auto-start
# 5. Run this script — it generates .env, sets permissions, builds images, enables services

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get path to dotfiles repo (where this script lives)
DOTFILES_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Ensure ~/.local/bin is in PATH for pass-cli
export PATH="$HOME/.local/bin:$PATH"

# Proton Pass key provider for headless environments
export PROTON_PASS_KEY_PROVIDER=fs

# Source secrets library
source "$DOTFILES_DIR/lib/secrets.sh"

# Parse arguments
SKIP_DOCKER=false
SKIP_SERVICES=false
SKIP_SECRETS=false
for arg in "$@"; do
    case $arg in
        --skip-docker) SKIP_DOCKER=true ;;
        --skip-services) SKIP_SERVICES=true ;;
        --skip-secrets) SKIP_SECRETS=true ;;
        *) log_warn "Unknown argument: $arg" ;;
    esac
done

# ============================================================================
# 1. SYSTEM USERS AND GROUPS
setup_users() {
    log_info "Setting up users and groups..."

    # Create selfhosted group if it doesn't exist
    if ! getent group selfhosted &>/dev/null; then
        groupadd selfhosted
        log_info "Created selfhosted group"
    else
        log_info "Selfhosted group already exists"
    fi

    # Ensure docker group exists (needed for user membership below)
    if ! getent group docker &>/dev/null; then
        groupadd docker
        log_info "Created docker group"
    fi

    # Create /var/selfhosted directory
    if [[ ! -d /var/selfhosted ]]; then
        mkdir -p /var/selfhosted
        chown root:selfhosted /var/selfhosted
        chmod 2775 /var/selfhosted  # setgid so new files inherit group
        log_info "Created /var/selfhosted with selfhosted group"
    else
        log_info "/var/selfhosted already exists"
    fi

    # Create logan user if it doesn't exist (primary user)
    if ! id logan &>/dev/null; then
        useradd -m -s /bin/bash logan
        usermod -aG sudo,selfhosted,docker logan
        log_info "Created logan user with sudo, selfhosted, docker groups"
    else
        usermod -aG selfhosted,docker logan 2>/dev/null || true
        log_info "Logan user exists, ensured group membership"
    fi

    # Create agent user if it doesn't exist (for UID/GID matching with container)
    if ! id agent &>/dev/null; then
        useradd -m -s /bin/bash agent
        usermod -aG selfhosted,docker agent
        log_info "Created agent user with selfhosted, docker groups"
    else
        usermod -aG selfhosted,docker agent 2>/dev/null || true
        log_info "Agent user exists, ensured group membership"
    fi
}

# ============================================================================
# 3. DOCKER INSTALLATION
# ============================================================================
setup_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        log_info "Skipping Docker installation (--skip-docker)"
        return
    fi

    log_info "Setting up Docker..."

    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        log_info "Docker already installed: $(docker --version)"
    else
        # Remove old versions
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

        # Install prerequisites
        apt-get update -qq
        apt-get install -y -qq \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # Set up the repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker Engine
        apt-get update -qq
        apt-get install -y -qq \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin

        log_info "Docker installed: $(docker --version)"
    fi

    # Enable and start Docker
    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || true

    log_info "Docker setup complete"
}

# ============================================================================
# 4. SECRETS MANAGEMENT (pass-cli + Proton Pass)
# ============================================================================
setup_secrets() {
    if [[ "$SKIP_SECRETS" == "true" ]]; then
        log_info "Skipping secrets setup (--skip-secrets)"
        return
    fi
    log_info "Setting up secrets management..."

    # Ensure ~/.local/bin is in PATH for pass-cli
    export PATH="$HOME/.local/bin:$PATH"

    # Install pass-cli if not present
    if ! command -v pass-cli &>/dev/null; then
        log_info "Installing pass-cli..."
        curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
        log_info "pass-cli installed: $(pass-cli --version 2>/dev/null || echo 'installed')"
    else
        log_info "pass-cli already installed"
    fi

    # Check for Proton Pass PAT
    local pat_file="/home/logan/secrets/proton-pass-pat"
    if [[ ! -f "$pat_file" ]]; then
        # Create secrets directory
        mkdir -p "/home/logan/secrets"
        chown logan:selfhosted "/home/logan/secrets"
        chmod 770 "/home/logan/secrets"

        # If interactive, prompt for PAT
        if [[ -t 0 ]]; then
            log_warn "Proton Pass PAT not found at $pat_file"
            log_info "Enter your Proton Pass PAT (or press Enter to skip):"
            read -r -s pat
            if [[ -n "$pat" ]]; then
                echo "$pat" > "$pat_file"
                chown logan:selfhosted "$pat_file"
                chmod 640 "$pat_file"
                log_info "PAT saved to $pat_file"
            else
                log_warn "Skipping Proton Pass setup"
                return
            fi
        else
            log_warn "Proton Pass PAT not found at $pat_file"
            log_warn "Create a PAT in Proton Pass (homelab vault, 6-month expiry)"
            log_warn "Then run: echo 'pst_...' > $pat_file && chmod 640 $pat_file && chown logan:selfhosted $pat_file"
            return
        fi
    fi

    # Login to Proton Pass
    log_info "Proton Pass PAT found"
    local pat=$(cat "$pat_file")
    if PROTON_PASS_KEY_PROVIDER=fs pass-cli login --pat "$pat" 2>/dev/null; then
        log_info "Logged into Proton Pass"
    else
        log_warn "Proton Pass login failed — PAT may be expired"
    fi

    log_info "Secrets management setup complete"
}

# ============================================================================
# 5. SERVICE SYMLINKS (docker files from dotfiles repo)
# ============================================================================
setup_services() {
    if [[ "$SKIP_SERVICES" == "true" ]]; then
        log_info "Skipping service setup (--skip-services)"
        return
    fi

    log_info "Setting up service symlinks..."

    # Link service directories from dotfiles repo to /var/selfhosted
    local services_source="$DOTFILES_DIR/services"

    if [[ ! -d "$services_source" ]]; then
        log_warn "No services directory found at $services_source"
        return
    fi

    # For each service in dotfiles/services/, create symlink in /var/selfhosted/
    for service_dir in "$services_source"/*/; do
        if [[ ! -d "$service_dir" ]]; then
            continue
        fi

        local service_name=$(basename "$service_dir")
        local target="/var/selfhosted/$service_name"

        # Create target directory if it doesn't exist
        if [[ ! -d "$target" ]]; then
            mkdir -p "$target"
            chown root:selfhosted "$target"
            chmod 2775 "$target"
            log_info "Created $target"
        fi

        # Check if this service has a .env.template (meaning .env comes from pass-cli)
        local has_env_template=false
        if [[ -f "$service_dir/.env.template" ]]; then
            has_env_template=true
        fi

        # Link individual files from dotfiles to the target
        for file in "$service_dir"/*; do
            if [[ ! -f "$file" ]]; then
                continue
            fi

            local filename=$(basename "$file")
            local link_target="$target/$filename"

            # Skip .env.template — it's documentation, not deployed
            if [[ "$filename" == ".env.template" ]]; then
                continue
            fi

            # Skip if already a correct symlink

            # Remove existing file/symlink if present
            if [[ -e "$link_target" ]] || [[ -L "$link_target" ]]; then
                rm -f "$link_target"
            fi

            # Create symlink
            ln  "$file" "$link_target"
            log_info "Linked $link_target -> $file"
        done

        # If service has .env.template, generate .env from pass-cli
        if [[ "$has_env_template" == "true" ]]; then
            local env_file="$target/.env"
            local template_file="$service_dir/.env.template"

            # Check if .env already exists and is up to date
            if [[ -f "$env_file" ]]; then
                log_info ".env already exists for $service_name (skipping generation)"
                log_info "To regenerate: rm $env_file && re-run this script"
                continue
            fi

            # Generate .env from template by replacing ${PLACEHOLDER} with values from pass-cli
            log_info "Generating .env for $service_name from Proton Pass..."
            
            local env_content=$(cat "$template_file")
            local missing_secrets=()

            while IFS= read -r placeholder; do
                # Extract the secret name (remove ${ and })
                local secret_name="${placeholder#\$\{}"
                secret_name="${secret_name%\}}"
                
                # Try to get the secret from pass-cli
                local secret_value=$(get_secret "homelab" "$secret_name" "password" 2>/dev/null || echo "")
                
                if [[ -n "$secret_value" ]]; then
                    # Replace placeholder with actual value
                    env_content="${env_content//\$\{$secret_name\}/$secret_value}"
                else
                    missing_secrets+=("$secret_name")
                fi
            done < <(grep -v '^\s*#' "$template_file" | grep -oE '\$\{[A-Z0-9_]+\}' | sort -u)

            # Write the .env file
            if [[ ${#missing_secrets[@]} -eq 0 ]]; then
                echo "$env_content" > "$env_file"
                chown logan:selfhosted "$env_file"
                chmod 640 "$env_file"
                log_info "Generated $env_file from Proton Pass"
            else
                log_warn "Missing secrets in Proton Pass vault 'homelab':"
                for secret in "${missing_secrets[@]}"; do
                    log_warn "  - $secret"
                done
                log_warn "Add these to Proton Pass, then re-run this script"
                log_warn "Or manually create $env_file"
            fi
        fi
    done

    log_info "Service symlinks setup complete"
}

# ============================================================================
# 6. BORG BACKUP SETUP
# ============================================================================
# Files are COPIED (install) into root-owned system paths, never symlinked: root must not
# execute or source a file that is writable by the logan user.
setup_borg() {
    log_info "Setting up borg backup..."

    if ! command -v borg &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq borgbackup
        log_info "Installed borgbackup"
    else
        log_info "Borg already installed: $(borg --version)"
    fi

    install -d -m 0750 -o root -g root /etc/borg /etc/borg/jobs /etc/borg/hooks
    install -d -m 0750 -o root -g root /var/log/borg
    install -d -m 0755 -o root -g root /var/lib/borg

    install -m 0755 -o root -g root "$DOTFILES_DIR/borg/borg-backup.sh" /usr/local/sbin/borg-backup
    local f
    for f in "$DOTFILES_DIR"/borg/jobs/*.conf; do
        install -m 0640 -o root -g root "$f" "/etc/borg/jobs/$(basename "$f")"
    done
    for f in "$DOTFILES_DIR"/borg/excludes-*; do
        install -m 0644 -o root -g root "$f" "/etc/borg/$(basename "$f")"
    done
    for f in "$DOTFILES_DIR"/borg/hooks/*; do
        [[ -f "$f" ]] && install -m 0755 -o root -g root "$f" "/etc/borg/hooks/$(basename "$f")"
    done
    log_info "Installed borg-backup, jobs, excludes and hooks"

    # The recovery README lives on the backup disk itself, next to the repos, for whoever
    # has to read the disk without this machine.
    if mountpoint -q /mnt/borg; then
        install -m 0644 -o root -g root "$DOTFILES_DIR/borg/README-blue-disk.md" /mnt/borg/README.md
        log_info "Installed /mnt/borg/README.md"
    else
        log_warn "/mnt/borg not mounted; README-blue-disk.md not copied to the backup disk"
    fi

    # Passphrase: root-only file read via BORG_PASSCOMMAND. Never substituted into scripts.
    # The value is Proton Pass vault "homelab", item BORG_PASSPHRASE.
    local pf=/etc/borg/passphrase
    if [[ ! -s "$pf" ]]; then
        local passphrase=""
        if command -v pass-cli &>/dev/null; then
            passphrase=$(get_secret "homelab" "BORG_PASSPHRASE" "password" 2>/dev/null || echo "")
        fi
        if [[ -z "$passphrase" && -t 0 ]]; then
            log_warn "$pf not found. Paste the borg passphrase from Proton Pass (homelab/BORG_PASSPHRASE):"
            read -r -s passphrase; echo
        fi
        if [[ -n "$passphrase" ]]; then
            (umask 077; printf '%s\n' "$passphrase" > "$pf")
            log_info "Wrote $pf"
        else
            log_warn "No passphrase available; create $pf by hand (0600 root:root) before any backup runs"
        fi
    fi
    if [[ -f "$pf" ]]; then
        chown root:root "$pf"
        chmod 0600 "$pf"
    fi

    # Remove the legacy generated script (it contained a passphrase and was group-readable)
    if [[ -f /var/selfhosted/backups/backup.sh ]]; then
        shred -u /var/selfhosted/backups/backup.sh && log_info "Removed legacy /var/selfhosted/backups/backup.sh"
        rmdir /var/selfhosted/backups 2>/dev/null || true
    fi

    log_info "Borg setup complete"
}

# ============================================================================
# 6b. LOGIN MESSAGE (MOTD)
# ============================================================================
setup_motd() {
    log_info "Setting up login message..."

    install -m 0755 -o root -g root "$DOTFILES_DIR/motd/40-backup-status" /etc/update-motd.d/40-backup-status

    # Silence the noise. Re-applied every run because package upgrades can restore +x.
    local f
    for f in 10-help-text 50-motd-news 85-fwupd 91-release-upgrade 95-hwe-eol; do
        [[ -f "/etc/update-motd.d/$f" ]] && chmod -x "/etc/update-motd.d/$f"
    done
    printf 'ENABLED=0\n' > /etc/default/motd-news
    systemctl disable --now motd-news.timer 2>/dev/null || true

    log_info "Login message setup complete"
}

# ============================================================================
# MAIN
# ============================================================================

# ============================================================================
# 7. SYSTEMD SERVICES
# ============================================================================
setup_systemd() {
    log_info "Setting up systemd services..."

    local systemd_source="$DOTFILES_DIR/systemd"
    local systemd_target="/etc/systemd/system"

    if [[ ! -d "$systemd_source" ]]; then
        log_warn "No systemd directory found at $systemd_source"
        return
    fi

    # Remove links that point into dotfiles but whose source no longer exists (renamed/removed units)
    local link
    for link in "$systemd_target"/*; do
        if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "$systemd_source"/* ]] && [[ ! -e "$link" ]]; then
            local stale=$(basename "$link")
            systemctl disable --now "$stale" 2>/dev/null || true
            rm -f "$link"
            log_info "Removed stale unit link $stale"
        fi
    done

    # Link service files
    for file in "$systemd_source"/*.service "$systemd_source"/*.timer; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local filename=$(basename "$file")
        local link_target="$systemd_target/$filename"

        # Skip if already a correct symlink
        if [[ -L "$link_target" ]] && [[ "$(readlink "$link_target")" == "$file" ]]; then
            continue
        fi

        # Remove existing file/symlink if present
        if [[ -e "$link_target" ]] || [[ -L "$link_target" ]]; then
            rm -f "$link_target"
        fi

        # Create symlink
        ln -s "$file" "$link_target"
        log_info "Linked $link_target -> $file"
    done

    # Reload systemd and enable services
    systemctl daemon-reload 2>/dev/null || true
    log_info "Systemd daemon reloaded"

    # Enable and start services
    for file in "$systemd_source"/*.service; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local service_name=$(basename "$file")
        [[ "$service_name" == *@.service ]] && continue   # templates are activated by their timers
        systemctl enable "$service_name" 2>/dev/null || true
        log_info "Enabled $service_name"
    done

    for file in "$systemd_source"/*.timer; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local timer_name=$(basename "$file")
        systemctl enable "$timer_name" 2>/dev/null || true
        systemctl start "$timer_name" 2>/dev/null || true
        log_info "Enabled and started $timer_name"
    done

    log_info "Systemd services setup complete"
}

# ============================================================================
# 8. SERVICE PERMISSIONS
# ============================================================================
setup_permissions() {
    log_info "Setting up service permissions..."

    # Immich permissions
    if [[ -d /var/selfhosted/immich ]]; then
        mkdir -p /var/selfhosted/immich/library
        chown -R 1000:1000 /var/selfhosted/immich/library
        chmod -R 755 /var/selfhosted/immich/library

        mkdir -p /var/selfhosted/immich/postgres
        chown -R 999:999 /var/selfhosted/immich/postgres
        chmod -R 700 /var/selfhosted/immich/postgres

        log_info "Immich permissions set"
    fi

    # Nginx proxy permissions
    if [[ -d /var/selfhosted/nginxproxy ]]; then
        mkdir -p /var/selfhosted/nginxproxy/data
        mkdir -p /var/selfhosted/nginxproxy/letsencrypt
        chown -R root:root /var/selfhosted/nginxproxy/data
        chown -R root:root /var/selfhosted/nginxproxy/letsencrypt
        log_info "Nginx proxy permissions set"
    fi

    # Agent container permissions
    if [[ -d /var/selfhosted/agent ]]; then
        mkdir -p /var/selfhosted/agent/workspace
        chown -R 1000:1000 /var/selfhosted/agent/workspace
        log_info "Agent permissions set"
    fi

    log_info "Service permissions setup complete"
}

# ============================================================================
# 9. BUILD DOCKER IMAGES
# ============================================================================
build_images() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        log_info "Skipping Docker installation (--skip-docker)"
        return
    fi
    log_info "Building docker images..."
    # Skip if docker is not available
    if ! command -v docker &>/dev/null; then
        log_info "Docker not available, skipping image build"
        return
    fi

    if [[ -f /var/selfhosted/agent/Dockerfile ]]; then
        log_info "Building agent image..."
        cd /var/selfhosted/agent
        docker build -t agent:local . 2>&1 | tail -5
        log_info "Agent image built"
    fi

    log_info "Docker images build complete"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_info "=========================================="
    log_info "Homelab Installation"
    log_info "=========================================="
    log_info "Target: Zorin OS 18+ / Ubuntu 24.04+"
    log_info "Dotfiles repo: $DOTFILES_DIR"
    echo ""

    setup_users
    echo ""

    setup_docker
    echo ""

    setup_secrets
    echo ""

    setup_services
    echo ""

    setup_permissions
    echo ""

    setup_borg
    echo ""

    setup_motd
    echo ""

    setup_systemd
    echo ""

    build_images
    echo ""

    log_info "=========================================="
    log_info "Homelab installation complete!"
    log_info "=========================================="
    echo ""
    log_info "Next steps:"
    log_info "1. Add your SSH public key to /home/agent/.ssh/authorized_keys"
    log_info "2. Ensure Proton Pass vault 'homelab' has required secrets"
    log_info "3. Services are enabled and will start on boot"
    log_info "4. Test agent SSH: ssh -p 2222 agent@localhost"
}

main "$@"
