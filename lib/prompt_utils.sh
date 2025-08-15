#!/bin/bash

# Prompt Utilities
# Shared utilities for managing AI prompts across different providers

set -euo pipefail

# Check for custom prompt file in lazygit config first, fallback to default
get_prompt_file() {
    local custom_prompt="$HOME/.config/lazygit/commit_prompt.txt"
    local default_prompt="$(dirname "${BASH_SOURCE[0]}")/../commit_prompt.txt"
    
    if [[ -f "$custom_prompt" ]]; then
        echo "$custom_prompt"
    else
        echo "$default_prompt"
    fi
}

# Collect git context for commit message generation
collect_git_context() {
    local prompt_file="$1"
    local recent_commits filestat diff_content
    
    recent_commits=$(git log --oneline -5)
    filestat=$(git diff --stat --cached | head -10)
    diff_content=$(git diff --cached | head -10000)
    
    {
        cat "$prompt_file"
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

# Check if there are staged changes
check_staged_changes() {
    if ! git diff --cached --quiet; then
        return 0
    else
        echo "Error: No changes in staging. Add changes first." >&2
        exit 2
    fi
}

# Clean and format AI response for commit message
clean_commit_response() {
    local response="$1"
    
    # Clean the content and encode multi-line as single line with ¦ as delimiter
    # This allows lazygit's menuFromCommand to show it as one option
    echo "$response" | \
        sed 's/```[a-zA-Z]*//g' | \
        sed 's/```//g' | \
        sed '/^[[:space:]]*$/d' | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
        tr '\n' '¦' | \
        sed 's/¦$//'
}