#!/bin/bash

# Generic Model Management Interface
# Defines the interface that all AI providers must implement for model management

set -euo pipefail

readonly MODEL_INTERFACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
readonly GLOBAL_USER_MODEL_FILE="$MODEL_INTERFACE_DIR/../selected_model.txt"
readonly GLOBAL_PROVIDER_FILE="$MODEL_INTERFACE_DIR/../selected_provider.txt"
readonly DEFAULT_PROVIDER="copilot"

# Model Provider Interface Contract:
# Each provider must implement these functions:
#
# provider_fetch_models() - Fetch models from provider API
# provider_get_default_models() - Get fallback models array
# provider_is_authenticated() - Check if provider is authenticated
# provider_get_cache_file() - Get path to provider's cache file
# provider_get_user_model_file() - Get path to provider's user model file

# Common model management functions

get_selected_provider() {
    if [[ -f "$GLOBAL_PROVIDER_FILE" ]]; then
        cat "$GLOBAL_PROVIDER_FILE" 2>/dev/null || echo "$DEFAULT_PROVIDER"
    else
        echo "$DEFAULT_PROVIDER"
    fi
}

set_selected_provider() {
    local provider="$1"
    echo "$provider" > "$GLOBAL_PROVIDER_FILE"
    chmod 600 "$GLOBAL_PROVIDER_FILE"
}

# Generic cache validation
is_cache_valid() {
    local cache_file="$1"
    local cache_expiry_hours="${2:-24}"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local cache_time current_time age_hours
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo "0")
    current_time=$(date +%s)
    age_hours=$(( (current_time - cache_time) / 3600 ))
    
    if [[ $age_hours -lt $cache_expiry_hours ]]; then
        return 0
    else
        return 1
    fi
}

# Generic cached models getter
get_cached_models() {
    local cache_file="$1"
    if [[ -f "$cache_file" ]] && jq -e '.data[0].id' "$cache_file" > /dev/null 2>&1; then
        cat "$cache_file"
        return 0
    else
        return 1
    fi
}

# Generic fallback models creator
create_fallback_models() {
    local provider_name="$1"
    shift
    local default_models=("$@")
    
    local fallback_json='{"data": []}'
    for model in "${default_models[@]}"; do
        fallback_json=$(echo "$fallback_json" | jq --arg id "$model" --arg name "$model (fallback)" --arg provider "$provider_name" \
            '.data += [{
                "id": $id,
                "name": $name,
                "publisher": $provider,
                "summary": "Fallback model when API is unavailable"
            }]')
    done
    
    echo "$fallback_json"
}

# Generic model management workflow
# This calls provider-specific functions that must be implemented
get_available_models() {
    local provider_script="$1"
    
    # Source the provider script to get its functions
    source "$provider_script"
    
    local cache_file
    cache_file=$(provider_get_cache_file)
    
    # Try to get fresh models if cache is expired
    if ! is_cache_valid "$cache_file" 24; then
        if provider_is_authenticated; then
            provider_fetch_models || true
        fi
    fi
    
    # Try to use cached models
    local models
    if models=$(get_cached_models "$cache_file"); then
        echo "$models"
        return 0
    fi
    
    # Fall back to provider default models
    local default_models provider_name
    provider_name=$(basename "$provider_script" .sh)
    readarray -t default_models < <(provider_get_default_models)
    create_fallback_models "$provider_name" "${default_models[@]}"
}

list_models_simple() {
    local provider_script="$1"
    local models
    models=$(get_available_models "$provider_script")
    
    if echo "$models" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "$models" | jq -r '.data[] | "\(.id) - \(.name // .id)"' 2>/dev/null
    else
        # Source provider for fallback
        source "$provider_script"
        local default_models
        readarray -t default_models < <(provider_get_default_models)
        for model in "${default_models[@]}"; do
            echo "$model - $model (fallback)"
        done
    fi
}

list_models_detailed() {
    local provider_script="$1"
    local models
    models=$(get_available_models "$provider_script")
    
    if echo "$models" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "Available Models:"
        echo "================="
        echo "$models" | jq -r '.data[] | "ID: \(.id)\nName: \(.name // .id)\nPublisher: \(.publisher // "Unknown")\nSummary: \(.summary // "No description")\n---"' 2>/dev/null
    else
        source "$provider_script"
        echo "Available Models (Fallback):"
        echo "============================"
        local default_models
        readarray -t default_models < <(provider_get_default_models)
        for model in "${default_models[@]}"; do
            echo "ID: $model"
            echo "Name: $model"
            echo "Publisher: $(basename "$provider_script" .sh)"
            echo "Summary: Fallback model"
            echo "---"
        done
    fi
}

get_model_ids() {
    local provider_script="$1"
    local models
    models=$(get_available_models "$provider_script")
    
    if echo "$models" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "$models" | jq -r '.data[].id' 2>/dev/null
    else
        source "$provider_script"
        provider_get_default_models
    fi
}

set_selected_model() {
    local provider_script="$1"
    local model_id="$2"
    
    # Validate model exists
    local available_models
    available_models=$(get_model_ids "$provider_script")
    if echo "$available_models" | grep -Fxq "$model_id"; then
        source "$provider_script"
        local user_model_file
        user_model_file=$(provider_get_user_model_file)
        echo "$model_id" > "$user_model_file"
        chmod 600 "$user_model_file"
        echo "✓ Model set to: $model_id"
        return 0
    else
        echo "Error: Model '$model_id' not found in available models" >&2
        return 1
    fi
}

get_selected_model() {
    local provider_script="$1"
    source "$provider_script"
    
    local user_model_file selected_model default_model
    user_model_file=$(provider_get_user_model_file)
    
    # Try to get user-selected model
    if [[ -f "$user_model_file" ]]; then
        selected_model=$(cat "$user_model_file" 2>/dev/null || true)
        if [[ -n "$selected_model" ]]; then
            # Validate it's still available
            if get_model_ids "$provider_script" | grep -Fxq "$selected_model"; then
                echo "$selected_model"
                return 0
            fi
        fi
    fi
    
    # Fall back to first available model
    default_model=$(get_model_ids "$provider_script" | head -n 1)
    if [[ -n "$default_model" ]]; then
        echo "$default_model"
        return 0
    fi
    
    # Ultimate fallback
    provider_get_default_models | head -n 1
}

refresh_models() {
    local provider_script="$1"
    source "$provider_script"
    
    if provider_is_authenticated; then
        if provider_fetch_models; then
            echo "✓ Models cache refreshed successfully"
        else
            echo "✗ Failed to refresh models cache"
            return 1
        fi
    else
        echo "✗ Not authenticated - cannot refresh models cache"
        return 1
    fi
}