#!/usr/bin/env bash
# Secret retrieval helpers using pass-cli (Proton Pass)
# Source this file to use get_secret function

# get_secret <vault> <item> <field>
# Retrieves a secret from Proton Pass vault
# Returns the secret value, or empty string on failure
get_secret() {
    local vault="$1"
    local item="$2"
    local field="$3"
    
    if [[ -z "$vault" || -z "$item" || -z "$field" ]]; then
        echo "Usage: get_secret <vault> <item> <field>" >&2
        return 1
    fi
    
    # Check if pass-cli is available
    if ! command -v pass-cli &>/dev/null; then
        echo "pass-cli not found" >&2
        return 1
    fi
    
    # Retrieve the secret
    pass-cli item view --vault-name "$vault" --item-title "$item" --field "$field" 2>/dev/null
}

# check_secret <vault> <item> <field>
# Returns 0 if secret exists and is non-empty, 1 otherwise
check_secret() {
    local value=$(get_secret "$@")
    [[ -n "$value" ]]
}
