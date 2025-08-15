#!/bin/bash

# GitHub Copilot Main Controller
# Handles all GitHub Copilot operations including authentication and model management

set -euo pipefail

readonly COPILOT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COPILOT_SCRIPT_DIR/auth_utils.sh"

show_help() {
    echo "GitHub Copilot Authentication Manager"
    echo ""
    echo "Usage: $0 {status|login|complete|logout|test}"
    echo ""
    echo "Authentication Commands:"
    echo "  status   - Show current authentication status"
    echo "  login    - Start authentication flow"
    echo "  complete - Complete authentication after entering device code"
    echo "  logout   - Clear authentication data"
    echo "  test     - Test current authentication"
    echo ""
}

handle_authentication() {
    local action="$1"
    "$COPILOT_SCRIPT_DIR/auth.sh" "$action"
}

case "${1:-help}" in
status|login|complete|logout|test)
    check_dependencies
    handle_authentication "$1"
    ;;
help|--help|-h)
    show_help
    ;;
*)
    echo "Unknown action: ${1:-}"
    echo ""
    show_help
    exit 1
    ;;
esac