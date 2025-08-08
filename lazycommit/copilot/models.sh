#!/bin/bash

# GitHub Copilot Model Management
# Handles fetching available models and user preferences

set -euo pipefail

readonly MODELS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODELS_SCRIPT_DIR/auth_utils.sh"

# Configuration
readonly MODELS_API_URL="https://api.githubcopilot.com/models"
readonly MODELS_CACHE_FILE="$MODELS_SCRIPT_DIR/../models_cache.json"
readonly USER_MODEL_FILE="$MODELS_SCRIPT_DIR/../selected_model.txt"
readonly CACHE_EXPIRY_HOURS=24

# Default fallback models (in order of preference) - These are Copilot-compatible
readonly DEFAULT_MODELS=(
    "gpt-4o-mini"
    "gpt-4o"
    "gpt-3.5-turbo"
    "text-davinci-003"
)

fetch_models_from_api() {
    local copilot_token
    copilot_token=$(get_copilot_token)
    
    if [[ -z "$copilot_token" ]]; then
        log_error "No Copilot token available for models API"
        return 1
    fi
    
    log_debug "Fetching models from GitHub Copilot API..."
    
    local response
    if ! response=$(curl -s "$MODELS_API_URL" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $copilot_token" \
        -H "User-Agent: $USER_AGENT" \
        -H "Editor-Version: vscode/1.99.3" \
        -H "Editor-Plugin-Version: copilot-chat/0.26.7" 2>&1); then
        log_debug "curl failed when fetching models from API"
        return 1
    fi
    
    if echo "$response" | jq -e '.data[0].id' > /dev/null 2>&1; then
        echo "$response" > "$MODELS_CACHE_FILE"
        log_debug "Models cache updated successfully"
        return 0
    else
        log_debug "Failed to fetch models from API: $response"
        return 1
    fi
}

is_cache_valid() {
    if [[ ! -f "$MODELS_CACHE_FILE" ]]; then
        return 1
    fi
    
    local cache_time current_time age_hours
    cache_time=$(stat -c %Y "$MODELS_CACHE_FILE" 2>/dev/null || stat -f %m "$MODELS_CACHE_FILE" 2>/dev/null || echo "0")
    current_time=$(date +%s)
    age_hours=$(( (current_time - cache_time) / 3600 ))
    
    if [[ $age_hours -lt $CACHE_EXPIRY_HOURS ]]; then
        return 0
    else
        return 1
    fi
}

get_cached_models() {
    if [[ -f "$MODELS_CACHE_FILE" ]] && jq -e '.data[0].id' "$MODELS_CACHE_FILE" > /dev/null 2>&1; then
        cat "$MODELS_CACHE_FILE"
        return 0
    else
        return 1
    fi
}

create_fallback_models() {
    log_debug "Creating fallback models list"
    
    local fallback_json='[]'
    for model in "${DEFAULT_MODELS[@]}"; do
        fallback_json=$(echo "$fallback_json" | jq --arg id "$model" --arg name "$model (fallback)" \
            '. += [{
                "id": $id,
                "name": $name,
                "publisher": "Default",
                "summary": "Fallback model when API is unavailable"
            }]')
    done
    
    echo "$fallback_json"
}

get_available_models() {
    local models
    
    # Try to get fresh models if cache is expired
    if ! is_cache_valid; then
        if is_authenticated; then
            fetch_models_from_api || true
        fi
    fi
    
    # Try to use cached models
    if models=$(get_cached_models); then
        echo "$models"
        return 0
    fi
    
    # Fall back to default models
    log_debug "Using fallback models"
    create_fallback_models
}

list_models_simple() {
    local models
    models=$(get_available_models)
    
    if echo "$models" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "$models" | jq -r '.data[] | "\(.id) - \(.name // .id)"' 2>/dev/null
    else
        # Fallback if jq fails or no data
        for model in "${DEFAULT_MODELS[@]}"; do
            echo "$model - $model (fallback)"
        done
    fi
}

list_models_detailed() {
    local models
    models=$(get_available_models)
    
    if echo "$models" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "Available Models:"
        echo "================="
        echo "$models" | jq -r '.data[] | "ID: \(.id)\nName: \(.name // .id)\nPublisher: \(.publisher // "GitHub")\nSummary: \(.summary // "No description")\n---"' 2>/dev/null
    else
        echo "Available Models (Fallback):"
        echo "============================"
        for model in "${DEFAULT_MODELS[@]}"; do
            echo "ID: $model"
            echo "Name: $model"
            echo "Publisher: Default"
            echo "Summary: Fallback model"
            echo "---"
        done
    fi
}

get_model_ids() {
    local models
    models=$(get_available_models)
    
    if echo "$models" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "$models" | jq -r '.data[].id' 2>/dev/null
    else
        printf '%s\n' "${DEFAULT_MODELS[@]}"
    fi
}

set_selected_model() {
    local model_id="$1"
    local available_models
    
    # Validate model exists
    available_models=$(get_model_ids)
    if echo "$available_models" | grep -Fxq "$model_id"; then
        echo "$model_id" > "$USER_MODEL_FILE"
        chmod 600 "$USER_MODEL_FILE"
        echo "✓ Model set to: $model_id"
        return 0
    else
        log_error "Model '$model_id' not found in available models"
        return 1
    fi
}

get_selected_model() {
    local selected_model default_model
    
    # Try to get user-selected model
    if [[ -f "$USER_MODEL_FILE" ]]; then
        selected_model=$(cat "$USER_MODEL_FILE" 2>/dev/null || true)
        if [[ -n "$selected_model" ]]; then
            # Validate it's still available
            if get_model_ids | grep -Fxq "$selected_model"; then
                echo "$selected_model"
                return 0
            fi
        fi
    fi
    
    # Fall back to first available model
    default_model=$(get_model_ids | head -n 1)
    if [[ -n "$default_model" ]]; then
        echo "$default_model"
        return 0
    fi
    
    # Ultimate fallback
    echo "${DEFAULT_MODELS[0]}"
}

refresh_models() {
    if is_authenticated; then
        if fetch_models_from_api; then
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

# Check dependencies before running any command that needs them
case "${1:-list}" in
    list|detailed|detail|ids|refresh|menu)
        check_dependencies
        ;;
    current|selected)
        # These commands only read files, don't need curl/jq
        ;;
    set)
        check_dependencies
        ;;
esac

case "${1:-list}" in
    list)
        list_models_simple
        ;;
    detailed|detail)
        list_models_detailed
        ;;
    ids)
        get_model_ids
        ;;
    current|selected)
        echo "Current model: $(get_selected_model)"
        ;;
    set)
        if [[ -n "${2:-}" ]]; then
            set_selected_model "$2"
        else
            echo "Usage: $0 set <model_id>"
            exit 1
        fi
        ;;
    refresh)
        refresh_models
        ;;
    menu)
        # Special format for lazygit menu
        get_model_ids | while read -r model_id; do
            echo "$model_id"
        done
        ;;
    *)
        echo "GitHub Copilot Model Manager"
        echo ""
        echo "Usage: $0 {list|detailed|current|set|refresh|menu}"
        echo ""
        echo "Commands:"
        echo "  list      - List available models (simple)"
        echo "  detailed  - List available models (detailed)"
        echo "  current   - Show currently selected model"
        echo "  set ID    - Set selected model by ID"
        echo "  refresh   - Refresh models cache from API"
        echo "  menu      - Output format for lazygit menu"
        echo ""
        exit 1
        ;;
esac