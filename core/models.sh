#!/bin/bash

# AI Models Manager
# Generic model management that delegates to AI providers

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the models interface
source "$SCRIPT_DIR/../lib/models_interface.sh"

# Check dependencies that all providers need
check_dependencies() {
    local deps=("jq" "curl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
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
            esac
            echo "" >&2
        done
        exit 1
    fi
}

# Get the provider to use
get_provider() {
    get_selected_provider
}

# Get provider script path
get_provider_script() {
    local provider="$1"
    echo "$SCRIPT_DIR/../providers/${provider}/models.sh"
}

show_help() {
    echo "AI Models Manager"
    echo ""
    echo "Usage: $0 {list|detailed|current|set|refresh|menu|provider}"
    echo ""
    echo "Commands:"
    echo "  list      - List available models (simple)"
    echo "  detailed  - List available models (detailed)"
    echo "  current   - Show currently selected model"
    echo "  set ID    - Set selected model by ID"
    echo "  refresh   - Refresh models cache from API"
    echo "  menu      - Output format for lazygit menu"
    echo "  provider [NAME] - Get or set AI provider"
    echo ""
}

main() {
    local action="${1:-help}"
    local provider provider_script
    
    case "$action" in
        provider)
            if [[ -n "${2:-}" ]]; then
                # Set provider
                local new_provider="$2"
                local new_provider_script
                new_provider_script=$(get_provider_script "$new_provider")
                
                if [[ ! -f "$new_provider_script" ]]; then
                    echo "Error: Provider '$new_provider' not found. Expected: $new_provider_script" >&2
                    exit 1
                fi
                
                set_selected_provider "$new_provider"
                echo "✓ AI provider set to: $new_provider"
            else
                # Get provider
                echo "Current provider: $(get_provider)"
            fi
            return 0
            ;;
        help|--help|-h)
            show_help
            return 0
            ;;
    esac
    
    # For all other commands, we need to get the provider and check dependencies
    provider=$(get_provider)
    provider_script=$(get_provider_script "$provider")
    
    if [[ ! -f "$provider_script" ]]; then
        echo "Error: Provider '$provider' not found. Expected: $provider_script" >&2
        echo "Use '$0 provider <name>' to set a valid provider" >&2
        exit 1
    fi
    
    # Check dependencies for commands that need them
    case "$action" in
        list|detailed|detail|refresh|menu)
            check_dependencies
            ;;
        current|selected)
            # These commands only read files, don't need curl/jq
            ;;
        set)
            check_dependencies
            ;;
    esac
    
    case "$action" in
        list)
            list_models_simple "$provider_script"
            ;;
        detailed|detail)
            list_models_detailed "$provider_script"
            ;;
        current|selected)
            echo "Current model: $(get_selected_model "$provider_script")"
            ;;
        set)
            if [[ -n "${2:-}" ]]; then
                set_selected_model "$provider_script" "$2"
            else
                echo "Usage: $0 set <model_id>"
                exit 1
            fi
            ;;
        refresh)
            refresh_models "$provider_script"
            ;;
        menu)
            # Special format for lazygit menu
            get_model_ids "$provider_script" | while read -r model_id; do
                echo "$model_id"
            done
            ;;
        *)
            echo "Unknown action: $action"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"