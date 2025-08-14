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
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo "" >&2
        echo "Please install the missing dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "jq")
                    echo "  • jq: JSON processor" >&2
                    echo "    Ubuntu/Debian: sudo apt-get install jq" >&2
                    echo "    macOS: brew install jq" >&2
                    echo "    Arch: sudo pacman -S jq" >&2
                    ;;
                "curl")
                    echo "  • curl: HTTP client" >&2
                    echo "    Ubuntu/Debian: sudo apt-get install curl" >&2
                    echo "    macOS: brew install curl (or use system curl)" >&2
                    echo "    Arch: sudo pacman -S curl" >&2
                    ;;
                "git")
                    echo "  • git: Version control system" >&2
                    echo "    Ubuntu/Debian: sudo apt-get install git" >&2
                    echo "    macOS: brew install git (or use Xcode tools)" >&2
                    echo "    Arch: sudo pacman -S git" >&2
                    ;;
            esac
            echo "" >&2
        done
        exit 1
    fi
    
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
    
    if ! curl -s "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $access_token" \
        -H "Editor-Version: vscode/1.83.1" \
        -H "Editor-Plugin-Version: copilot-chat/0.8.0" \
        -H "Openai-Organization: github-copilot" \
        -H "Openai-Intent: conversation-panel" \
        -d "$payload" 2>&1; then
        log_error "curl failed when calling Copilot API"
        exit $AI_EXIT_API_ERROR
    fi
}

extract_commit_messages() {
    local response="$1"
    
    if ! echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        log_error "GitHub Copilot API request failed"
        echo "Response: $response" >&2
        exit $AI_EXIT_API_ERROR
    fi
    
    local content
    if ! content=$(echo "$response" | jq -r '.choices[0].message.content' 2>&1); then
        log_error "jq failed to parse content from API response"
        exit $AI_EXIT_API_ERROR
    fi
    
    # Clean the content and encode multi-line as single line with ¦ as delimiter
    # This allows lazygit's menuFromCommand to show it as one option
    echo "$content" | \
        sed 's/```[a-zA-Z]*//g' | \
        sed 's/```//g' | \
        sed '/^[[:space:]]*$/d' | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
        tr '\n' '¦' | \
        sed 's/¦$//'
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