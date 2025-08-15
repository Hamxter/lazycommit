#!/bin/bash

# AI Provider Interface
# Defines the interface that all AI providers must implement

set -euo pipefail

# Source prompt utilities
readonly INTERFACE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INTERFACE_SCRIPT_DIR/prompt_utils.sh"

# AI Provider Interface Contract:
# Each provider must implement these functions:
#
# check_provider_auth() - Check if provider is authenticated
# get_provider_token() - Get authentication token
# call_provider_api(content, model) - Call the AI API
# extract_response(api_response) - Extract message from API response

# Exit codes for consistency across providers
readonly AI_EXIT_SUCCESS=0
readonly AI_EXIT_AUTH_ERROR=1
readonly AI_EXIT_NO_CHANGES=2
readonly AI_EXIT_API_ERROR=3

# Common logging function
log_error() {
    echo "Error: $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "Debug: $*" >&2
    fi
}

# Check dependencies that all providers need
check_common_dependencies() {
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
}

# Generic AI commit generation workflow
# This calls provider-specific functions that must be implemented
generate_ai_commit() {
    local provider_script="$1"
    
    # Source the provider script to get its functions
    source "$provider_script"
    
    # Check common dependencies
    check_common_dependencies
    
    # Check provider-specific authentication
    if ! check_provider_auth; then
        log_error "Provider not authenticated"
        exit $AI_EXIT_AUTH_ERROR
    fi
    
    # Check for staged changes
    if ! git diff --cached --quiet; then
        : # Changes exist, continue
    else
        log_error "No changes in staging. Add changes first."
        exit $AI_EXIT_NO_CHANGES
    fi
    
    # Get prompt file
    local prompt_file
    prompt_file=$(get_prompt_file)
    
    # Collect git context
    local content
    content=$(collect_git_context "$prompt_file")
    
    # Get model (provider-specific)
    local model
    if command -v get_provider_model > /dev/null 2>&1; then
        model=$(get_provider_model)
    else
        model="" # Let provider use default
    fi
    
    # Call provider API
    local api_response
    if ! api_response=$(call_provider_api "$content" "$model"); then
        log_error "Failed to call provider API"
        exit $AI_EXIT_API_ERROR
    fi
    
    # Extract and clean response
    local commit_message
    if ! commit_message=$(extract_response "$api_response"); then
        log_error "Failed to extract response from API"
        exit $AI_EXIT_API_ERROR
    fi
    
    # Clean and format for lazygit
    clean_commit_response "$commit_message"
}