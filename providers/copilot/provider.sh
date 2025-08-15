#!/bin/bash

# GitHub Copilot Provider Implementation
# Implements the AI provider interface for GitHub Copilot

set -euo pipefail

readonly PROVIDER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required utilities
source "$PROVIDER_SCRIPT_DIR/../../lib/prompt_utils.sh"
source "$PROVIDER_SCRIPT_DIR/auth_utils.sh"

# Configuration
readonly API_URL="https://api.githubcopilot.com/chat/completions"
readonly MAX_TOKENS=500
readonly TEMPERATURE=0.7

# Implementation of AI Provider Interface

check_provider_auth() {
    is_authenticated
}

get_provider_token() {
    local token
    token=$(get_copilot_token)
    
    if [[ -z "$token" ]]; then
        return 1
    fi
    
    echo "$token"
}

get_provider_model() {
    if [[ -f "$PROVIDER_SCRIPT_DIR/../../core/models.sh" ]]; then
        "$PROVIDER_SCRIPT_DIR/../../core/models.sh" current 2>/dev/null | sed 's/Current model: //' || echo "gpt-4o-mini"
    else
        echo "gpt-4o-mini"
    fi
}

call_provider_api() {
    local content="$1"
    local model="${2:-$(get_provider_model)}"
    local access_token
    
    access_token=$(get_provider_token)
    if [[ -z "$access_token" ]]; then
        return 1
    fi
    
    local payload
    payload=$(jq -n \
        --arg model "$model" \
        --arg content "$content" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        '{
            model: $model,
            messages: [{"role": "user", "content": $content}],
            max_tokens: $max_tokens,
            temperature: $temperature
        }')
    
    if ! curl -s "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $access_token" \
        -H "Editor-Version: vscode/1.83.1" \
        -H "Editor-Plugin-Version: copilot-chat/0.8.0" \
        -H "Openai-Organization: github-copilot" \
        -H "Openai-Intent: conversation-panel" \
        -d "$payload" 2>&1; then
        return 1
    fi
}

extract_response() {
    local response="$1"
    
    if ! echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        log_error "GitHub Copilot API request failed"
        echo "Response: $response" >&2
        return 1
    fi
    
    if ! echo "$response" | jq -r '.choices[0].message.content' 2>&1; then
        log_error "jq failed to parse content from API response"
        return 1
    fi
}