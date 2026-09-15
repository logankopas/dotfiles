#!/usr/bin/env bash
# Homelab provisioning script — idempotent, safe to run multiple times
# Target: Zorin OS 18+ / Ubuntu 24.04+
#
# Usage: sudo ./homelab.sh [--skip-docker] [--skip-services]
#
# This script provisions a fresh homelab:
# - System users and groups (selfhosted group)
# - Docker
# - Secrets management (pass-cli + Proton Pass)
# - Service symlinks (docker files from dotfiles repo)
# - Service permissions (proper ownership for container UIDs)
# - Systemd services (link, daemon-reload, enable)
# - Docker image builds
# - Borg backup setup
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
for arg in "$@"; do
    case $arg in
        --skip-docker) SKIP_DOCKER=true ;;
        --skip-services) SKIP_SERVICES=true ;;
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
# 4. SECRETS MANAGEMENT (pass-cli + Proton Pass)
# ============================================================================
setup_secrets() {
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
setup_borg() {
    log_info "Setting up borg backup..."

    # Install borg if not present
    if ! command -v borg &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq borgbackup
        log_info "Installed borgbackup"
    else
        log_info "Borg already installed: $(borg --version)"
    fi

    # Create backup scripts directory
    local backup_dir="/var/selfhosted/backups"
    mkdir -p "$backup_dir"
    chown logan:selfhosted "$backup_dir"
    chmod 770 "$backup_dir"

    # Generate backup.sh from template
    local template_file="$DOTFILES_DIR/systemd/backup.sh.template"
    local backup_script="$backup_dir/backup.sh"

    if [[ -f "$template_file" ]]; then
        # Check if backup.sh already exists
        if [[ -f "$backup_script" ]]; then
            log_info "Backup script already exists (skipping generation)"
            log_info "To regenerate: rm $backup_script && re-run this script"
        else
            log_info "Generating backup.sh from template..."
            
            # Get the passphrase from Proton Pass
            local passphrase=$(get_secret "homelab" "BORG_PASSPHRASE" "password" 2>/dev/null || echo "")
            
            if [[ -n "$passphrase" ]]; then
                # Replace placeholder with actual value
                local script_content=$(cat "$template_file")
                script_content="${script_content//\$\{BORG_PASSPHRASE\}/$passphrase}"
                
                # Write the script
                echo "$script_content" > "$backup_script"
                chown logan:selfhosted "$backup_script"
                chmod 750 "$backup_script"
                log_info "Generated $backup_script"
            else
                log_warn "Could not retrieve BORG_PASSPHRASE from Proton Pass"
                log_warn "Add it to Proton Pass vault 'homelab', then re-run this script"
            fi
        fi
    else
        log_warn "Template not found: $template_file"
    fi

    log_info "Borg setup complete"
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

    setup_systemd
    echo ""

    build_images
    echo ""

    setup_borg
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
