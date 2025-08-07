#!/bin/bash

# GitHub Copilot Authentication Utilities
# Shared utilities for authentication system

set -euo pipefail

# Configuration
readonly CLIENT_ID="Iv1.b507a08c87ecfe98"
readonly DEVICE_CODE_URL="https://github.com/login/device/code"
readonly ACCESS_TOKEN_URL="https://github.com/login/oauth/access_token"
readonly COPILOT_API_KEY_URL="https://api.github.com/copilot_internal/v2/token"
readonly USER_AGENT="GitHubCopilotChat/0.26.7"

# File paths
readonly AUTH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AUTH_FILE="$AUTH_SCRIPT_DIR/auth.json"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_AUTH_ERROR=1
readonly EXIT_NETWORK_ERROR=2
readonly EXIT_JSON_ERROR=3

log_info() {
    echo "Info: $*" >&2
}

log_error() {
    echo "Error: $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "Debug: $*" >&2
    fi
}

check_dependencies() {
    local deps=("jq" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
}

create_auth_file() {
    local auth_dir
    auth_dir="$(dirname "$AUTH_FILE")"
    
    if [[ ! -d "$auth_dir" ]]; then
        mkdir -p "$auth_dir"
    fi
    
    if [[ ! -f "$AUTH_FILE" ]]; then
        echo '{}' > "$AUTH_FILE"
        chmod 600 "$AUTH_FILE"
    fi
}

get_auth_field() {
    local field="$1"
    local default="${2:-}"
    
    if [[ ! -f "$AUTH_FILE" ]]; then
        echo "$default"
        return
    fi
    
    local value
    value=$(jq -r ".$field // \"$default\"" "$AUTH_FILE" 2>/dev/null || echo "$default")
    echo "$value"
}

set_auth_field() {
    local field="$1"
    local value="$2"
    
    create_auth_file
    
    local temp_file
    temp_file=$(mktemp)
    
    if jq --arg field "$field" --arg value "$value" '.[$field] = $value' "$AUTH_FILE" > "$temp_file"; then
        mv "$temp_file" "$AUTH_FILE"
        chmod 600 "$AUTH_FILE"
    else
        rm -f "$temp_file"
        log_error "Failed to update auth file"
        exit $EXIT_JSON_ERROR
    fi
}

is_authenticated() {
    local github_token copilot_token copilot_expires
    
    github_token=$(get_auth_field "github_token" "")
    copilot_token=$(get_auth_field "copilot_token" "")
    copilot_expires=$(get_auth_field "copilot_expires" "0")
    
    if [[ -z "$github_token" ]]; then
        return 1
    fi
    
    # Check if we have a valid Copilot token
    if [[ -n "$copilot_token" && "$copilot_expires" -gt "$(date +%s)" ]]; then
        return 0
    fi
    
    # Try to refresh Copilot token
    if refresh_copilot_token; then
        return 0
    fi
    
    return 1
}

refresh_copilot_token() {
    local github_token
    github_token=$(get_auth_field "github_token" "")
    
    if [[ -z "$github_token" ]]; then
        return 1
    fi
    
    log_debug "Refreshing Copilot token..."
    
    local response
    response=$(curl -s "$COPILOT_API_KEY_URL" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $github_token" \
        -H "User-Agent: $USER_AGENT" \
        -H "Editor-Version: vscode/1.99.3" \
        -H "Editor-Plugin-Version: copilot-chat/0.26.7")
    
    if ! echo "$response" | jq -e '.token' > /dev/null 2>&1; then
        log_debug "Failed to refresh Copilot token: $response"
        return 1
    fi
    
    local copilot_token copilot_expires
    copilot_token=$(echo "$response" | jq -r '.token')
    copilot_expires=$(echo "$response" | jq -r '.expires_at')
    
    set_auth_field "copilot_token" "$copilot_token"
    set_auth_field "copilot_expires" "$copilot_expires"
    
    log_debug "Copilot token refreshed successfully"
    return 0
}

get_copilot_token() {
    if ! is_authenticated; then
        return 1
    fi
    
    get_auth_field "copilot_token" ""
}

clear_auth() {
    if [[ -f "$AUTH_FILE" ]]; then
        rm -f "$AUTH_FILE"
    fi
}