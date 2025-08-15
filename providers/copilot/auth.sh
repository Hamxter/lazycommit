#!/bin/bash

# GitHub Copilot Authentication Manager
# Main entry point for authentication operations

set -euo pipefail

readonly AUTH_MAIN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$AUTH_MAIN_SCRIPT_DIR/auth_utils.sh"

show_auth_status() {
    if is_authenticated; then
        local github_token copilot_expires
        github_token=$(get_auth_field "github_token" "")
        copilot_expires=$(get_auth_field "copilot_expires" "0")
        
        echo "✓ GitHub Copilot Authentication Status: AUTHENTICATED"
        echo ""
        echo "GitHub Token: ${github_token:0:10}..."
        
        if [[ "$copilot_expires" -gt "$(date +%s)" ]]; then
            local expires_date
            expires_date=$(date -d "@$copilot_expires" 2>/dev/null || date -r "$copilot_expires" 2>/dev/null || echo "Unknown")
            echo "Copilot Token: Valid until $expires_date"
        else
            echo "Copilot Token: Expired (will refresh automatically)"
        fi
        echo ""
        echo "Ready to generate AI commit messages!"
    else
        echo "✗ GitHub Copilot Authentication Status: NOT AUTHENTICATED"
        echo ""
        echo "You need to authenticate with GitHub to use AI commit features."
        echo "Use the authentication command to get started."
    fi
}

authenticate() {
    if is_authenticated; then
        echo "Already authenticated with GitHub Copilot."
        echo ""
        show_auth_status
        return 0
    fi
    
    echo "Starting GitHub authentication flow..."
    echo ""
    
    # Start device flow
    "$AUTH_MAIN_SCRIPT_DIR/device_flow.sh" start
}

complete_authentication() {
    "$AUTH_MAIN_SCRIPT_DIR/device_flow.sh" poll
}

logout() {
    if [[ -f "$AUTH_FILE" ]]; then
        clear_auth
        echo "✓ Successfully logged out from GitHub Copilot."
        echo "Authentication data has been cleared."
    else
        echo "Not currently authenticated."
    fi
}

test_authentication() {
    if ! is_authenticated; then
        echo "Not authenticated. Please authenticate first."
        exit $EXIT_AUTH_ERROR
    fi
    
    local token
    token=$(get_copilot_token)
    
    if [[ -n "$token" ]]; then
        echo "✓ Authentication test successful!"
        echo "Copilot token is valid and ready to use."
        return 0
    else
        echo "✗ Authentication test failed!"
        echo "Unable to get valid Copilot token."
        exit $EXIT_AUTH_ERROR
    fi
}

case "${1:-status}" in
    status)
        show_auth_status
        ;;
    login|auth|authenticate)
        check_dependencies
        authenticate
        ;;
    complete|poll)
        check_dependencies
        complete_authentication
        ;;
    logout|clear)
        logout
        ;;
    test)
        check_dependencies
        test_authentication
        ;;
    token)
        # Hidden command to get token for scripts
        if token=$(get_copilot_token); then
            echo "$token"
        else
            exit $EXIT_AUTH_ERROR
        fi
        ;;
    *)
        echo "GitHub Copilot Authentication Manager"
        echo ""
        echo "Usage: $0 {status|login|complete|logout|test}"
        echo ""
        echo "Commands:"
        echo "  status   - Show current authentication status"
        echo "  login    - Start authentication flow"
        echo "  complete - Complete authentication after entering device code"
        echo "  logout   - Clear authentication data"
        echo "  test     - Test current authentication"
        echo ""
        exit 1
        ;;
esac