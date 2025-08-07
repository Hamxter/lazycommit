#!/bin/bash

set -euo pipefail

# AI Commit Message Generator for Lazygit
# Generates conventional commit messages using GitHub Copilot API

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROMPT_FILE="$SCRIPT_DIR/../commit_prompt.txt"

# Source authentication utilities
source "$SCRIPT_DIR/auth_utils.sh"

# Configuration
readonly API_URL="https://api.githubcopilot.com/chat/completions"
readonly MAX_TOKENS=500
readonly TEMPERATURE=0.7

# Get selected model or use fallback
get_selected_model() {
    if [[ -f "$SCRIPT_DIR/models.sh" ]]; then
        "$SCRIPT_DIR/models.sh" current 2>/dev/null | sed 's/Current model: //' || echo "gpt-4o-mini"
    else
        echo "gpt-4o-mini"
    fi
}

# Exit codes
readonly AI_EXIT_SUCCESS=0
readonly AI_EXIT_AUTH_ERROR=1
readonly AI_EXIT_NO_CHANGES=2
readonly AI_EXIT_API_ERROR=3

log_error() {
    echo "Error: $*" >&2
}

check_dependencies() {
    local deps=("jq" "curl" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
    
    # Check authentication
    if ! is_authenticated; then
        log_error "GitHub Copilot not authenticated. Use Ctrl+G in lazygit to authenticate."
        exit $AI_EXIT_AUTH_ERROR
    fi
}

get_access_token() {
    local token
    token=$(get_copilot_token)
    
    if [[ -z "$token" ]]; then
        log_error "GitHub Copilot not authenticated. Use Ctrl+G in lazygit to authenticate."
        exit $AI_EXIT_AUTH_ERROR
    fi
    
    echo "$token"
}

check_staged_changes() {
    if ! git diff --cached --quiet; then
        return 0
    else
        log_error "No changes in staging. Add changes first."
        exit $AI_EXIT_NO_CHANGES
    fi
}

collect_git_context() {
    local recent_commits filestat diff_content
    
    recent_commits=$(git log --oneline -5)
    filestat=$(git diff --stat --cached | head -10)
    diff_content=$(git diff --cached | head -50)
    
    {
        cat "$PROMPT_FILE"
        echo
        echo "Recent commits:"
        echo "$recent_commits"
        echo
        echo "Changes:"
        echo "$filestat"
        echo
        echo "Diff:"
        echo "$diff_content"
    }
}

create_api_payload() {
    local content model
    content=$(collect_git_context)
    model=$(get_selected_model)
    
    jq -n \
        --arg model "$model" \
        --arg content "$content" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        '{
            model: $model,
            messages: [{"role": "user", "content": $content}],
            max_tokens: $max_tokens,
            temperature: $temperature
        }'
}

call_copilot_api() {
    local access_token="$1"
    local payload="$2"
    
    curl -s "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $access_token" \
        -H "Editor-Version: vscode/1.83.1" \
        -H "Editor-Plugin-Version: copilot-chat/0.8.0" \
        -H "Openai-Organization: github-copilot" \
        -H "Openai-Intent: conversation-panel" \
        -d "$payload"
}

extract_commit_messages() {
    local response="$1"
    
    if ! echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        log_error "GitHub Copilot API request failed"
        echo "Response: $response" >&2
        exit $AI_EXIT_API_ERROR
    fi
    
    echo "$response" | \
        jq -r '.choices[0].message.content' | \
        grep -E '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)' | \
        head -10
}

main() {
    check_dependencies
    check_staged_changes
    
    local access_token payload response
    
    access_token=$(get_access_token)
    payload=$(create_api_payload)
    response=$(call_copilot_api "$access_token" "$payload")
    
    extract_commit_messages "$response"
}

main "$@"