#!/bin/bash

# GitHub Copilot Model Provider Implementation
# Implements the model provider interface for GitHub Copilot

set -euo pipefail

COPILOT_MODELS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required utilities
source "$COPILOT_MODELS_SCRIPT_DIR/auth_utils.sh"

# Configuration
MODELS_API_URL="https://api.githubcopilot.com/models"
COPILOT_MODELS_CACHE_FILE="$COPILOT_MODELS_SCRIPT_DIR/../../models_cache.json"
COPILOT_USER_MODEL_FILE="$COPILOT_MODELS_SCRIPT_DIR/../../selected_model.txt"

# Default fallback models (in order of preference) - These are Copilot-compatible
DEFAULT_COPILOT_MODELS=(
    "gpt-4o-mini"
    "gpt-4o"
    "gpt-3.5-turbo"
    "text-davinci-003"
)

# Implementation of Model Provider Interface

provider_fetch_models() {
    local copilot_token
    copilot_token=$(get_copilot_token)
    
    if [[ -z "$copilot_token" ]]; then
        log_debug "No Copilot token available for models API"
        return 1
    fi
    
    log_debug "Fetching models from GitHub Copilot API..."
    
    local response
    if ! response=$(curl -s "$MODELS_API_URL" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $copilot_token" \
        -H "User-Agent: ${USER_AGENT:-lazycommit/1.0}" \
        -H "Editor-Version: vscode/1.99.3" \
        -H "Editor-Plugin-Version: copilot-chat/0.26.7" 2>&1); then
        log_debug "curl failed when fetching models from API"
        return 1
    fi
    
    if echo "$response" | jq -e '.data[0].id' > /dev/null 2>&1; then
        echo "$response" > "$COPILOT_MODELS_CACHE_FILE"
        log_debug "Models cache updated successfully"
        return 0
    else
        log_debug "Failed to fetch models from API: $response"
        return 1
    fi
}

provider_get_default_models() {
    printf '%s\n' "${DEFAULT_COPILOT_MODELS[@]}"
}

provider_is_authenticated() {
    is_authenticated
}

provider_get_cache_file() {
    echo "$COPILOT_MODELS_CACHE_FILE"
}

provider_get_user_model_file() {
    echo "$COPILOT_USER_MODEL_FILE"
}