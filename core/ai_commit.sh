#!/bin/bash

# AI Commit Message Generator
# Main entry point that delegates to AI providers

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the AI interface
source "$SCRIPT_DIR/../lib/ai_interface.sh"

# Default provider
readonly DEFAULT_PROVIDER="copilot"

# Get the provider to use (could be extended to read from config)
get_provider() {
    # For now, default to copilot
    # Future: could read from ~/.config/lazygit/ai_provider.txt or config
    echo "$DEFAULT_PROVIDER"
}

main() {
    local provider
    provider=$(get_provider)
    
    local provider_script="$SCRIPT_DIR/../providers/${provider}/provider.sh"
    
    if [[ ! -f "$provider_script" ]]; then
        log_error "Provider '$provider' not found. Expected: $provider_script"
        exit 1
    fi
    
    # Generate commit using the provider
    generate_ai_commit "$provider_script"
}

main "$@"