#!/bin/bash

# GitHub Device Code Flow Implementation
# Handles device code generation and polling for OAuth authentication

set -euo pipefail

readonly DEVICE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DEVICE_SCRIPT_DIR/auth_utils.sh"

start_device_flow() {
    log_debug "Starting device code flow..."
    
    local response
    response=$(curl -s "$DEVICE_CODE_URL" \
        -X POST \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "User-Agent: $USER_AGENT" \
        -d "{\"client_id\": \"$CLIENT_ID\", \"scope\": \"read:user\"}")
    
    if ! echo "$response" | jq -e '.device_code' > /dev/null 2>&1; then
        log_error "Failed to get device code: $response"
        exit $EXIT_NETWORK_ERROR
    fi
    
    local device_code user_code verification_uri interval expires_in
    device_code=$(echo "$response" | jq -r '.device_code')
    user_code=$(echo "$response" | jq -r '.user_code')
    verification_uri=$(echo "$response" | jq -r '.verification_uri')
    interval=$(echo "$response" | jq -r '.interval // 5')
    expires_in=$(echo "$response" | jq -r '.expires_in')
    
    # Store device code temporarily
    set_auth_field "device_code" "$device_code"
    set_auth_field "device_expires" "$(($(date +%s) + expires_in))"
    
    # Output for lazygit to display
    cat << EOF
Device Code: $user_code
Verification URL: $verification_uri

1. Open the URL above in your browser
2. Enter the device code: $user_code
3. Press Enter in lazygit to continue polling for authorization

This code expires in $((expires_in / 60)) minutes.
EOF
}

poll_device_authorization() {
    local device_code interval max_attempts attempt
    device_code=$(get_auth_field "device_code" "")
    interval=$(get_auth_field "poll_interval" "5")
    max_attempts=120  # 10 minutes with 5-second intervals
    attempt=0
    
    if [[ -z "$device_code" ]]; then
        log_error "No device code found. Please run the device flow first."
        exit $EXIT_AUTH_ERROR
    fi
    
    # Check if device code expired
    local device_expires
    device_expires=$(get_auth_field "device_expires" "0")
    if [[ "$(date +%s)" -gt "$device_expires" ]]; then
        log_error "Device code has expired. Please start the authentication flow again."
        exit $EXIT_AUTH_ERROR
    fi
    
    log_info "Polling for authorization... (this may take a moment)"
    
    while [[ $attempt -lt $max_attempts ]]; do
        local response
        response=$(curl -s "$ACCESS_TOKEN_URL" \
            -X POST \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "User-Agent: $USER_AGENT" \
            -d "{
                \"client_id\": \"$CLIENT_ID\",
                \"device_code\": \"$device_code\",
                \"grant_type\": \"urn:ietf:params:oauth:grant-type:device_code\"
            }")
        
        local error access_token
        error=$(echo "$response" | jq -r '.error // ""')
        access_token=$(echo "$response" | jq -r '.access_token // ""')
        
        if [[ -n "$access_token" ]]; then
            # Success! Store the GitHub token
            set_auth_field "github_token" "$access_token"
            
            # Clear temporary device code data
            set_auth_field "device_code" ""
            set_auth_field "device_expires" ""
            
            # Get initial Copilot token
            if refresh_copilot_token; then
                echo "✓ Authentication successful!"
                echo "GitHub Copilot is now ready to use."
                return 0
            else
                log_error "GitHub authentication succeeded, but failed to get Copilot token"
                exit $EXIT_AUTH_ERROR
            fi
        elif [[ "$error" == "authorization_pending" ]]; then
            log_debug "Authorization pending, waiting $interval seconds..."
            sleep "$interval"
            ((attempt++))
        elif [[ "$error" == "slow_down" ]]; then
            log_debug "Rate limited, increasing wait time..."
            interval=$((interval + 5))
            sleep "$interval"
            ((attempt++))
        elif [[ "$error" == "expired_token" ]]; then
            log_error "Device code has expired. Please start the authentication flow again."
            exit $EXIT_AUTH_ERROR
        elif [[ "$error" == "access_denied" ]]; then
            log_error "Access denied. Authentication was cancelled or rejected."
            exit $EXIT_AUTH_ERROR
        else
            log_error "Authentication failed: $error"
            log_debug "Response: $response"
            exit $EXIT_AUTH_ERROR
        fi
    done
    
    log_error "Authentication timed out. Please try again."
    exit $EXIT_AUTH_ERROR
}

case "${1:-}" in
    start)
        check_dependencies
        start_device_flow
        ;;
    poll)
        check_dependencies
        poll_device_authorization
        ;;
    *)
        echo "Usage: $0 {start|poll}"
        echo "  start - Begin device code flow and display user code"
        echo "  poll  - Poll for authorization completion"
        exit 1
        ;;
esac