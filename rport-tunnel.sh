#!/bin/bash

# Creates or reuses an SSH tunnel for a given rport client.
# On success, it prints the connection details pipe-separated:
# <ssh-user>|<rport-host>|<tunnel-port>

set -euo pipefail

# --- Helper Functions ---
# A function to print error messages to stderr and exit.
fail() {
    printf >&2 "Error: %s\n" "$1"
    exit 1
}

# A function to make authenticated API calls to rport.
# It separates the body from the HTTP status code to allow for robust error handling.
# Usage: rport_api <method> "/endpoint"
rport_api() {
    local method="$1"
    local endpoint="$2"
    local response
    
    # -w "\n%{http_code}" appends the status code to the output
    response=$(curl -s -X "$method" -w "\n%{http_code}" -u "${RPORT_CREDENTIALS}" "${RPORT_URL_ROOT}${endpoint}")
    
    local http_code
    http_code=$(tail -n1 <<< "$response")
    local body
    body=$(sed '$ d' <<< "$response")

    if [[ "$http_code" -ne 200 ]]; then
        # Try to get a meaningful error from the JSON response, otherwise show the body
        local err_msg
        err_msg=$(echo "$body" | jq -r '.error.text // .')
        fail "API request failed for ${endpoint}: HTTP ${http_code} - ${err_msg}"
    fi
    echo "$body"
}
# --- End Helper Functions ---

# --- Main Script ---
main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <client_name>" >&2
        exit 1
    fi
    local client_name="$1"

    # Check for required environment variables
    [ -z "${RPORT_HOST:-}" ] && fail "RPORT_HOST environment variable not set."
    [ -z "${RPORT_CREDENTIALS:-}" ] && fail "RPORT_CREDENTIALS environment variable not set."

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."

    readonly RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"

    # 1. Get the client id from the name
    local clients_json
    clients_json=$(rport_api "GET" "/clients?filter[name]=${client_name}")
    
    [ "$(echo "${clients_json}" | jq -r '.data | length')" -ne 1 ] && fail "Unable to find exact match for client: ${client_name}"
    local client_id
    client_id=$(echo "${clients_json}" | jq -r '.data[0].id')

    # 2. Get client info and check connection state
    local client_info_json
    client_info_json=$(rport_api "GET" "/clients/${client_id}")
    [ "$(echo "${client_info_json}" | jq -r '.data.connection_state')" != "connected" ] && fail "Client ${client_name} is not connected."

    # 3. Check for an existing tunnel or create a new one
    local tunnel_info_json
    if [ "$(echo "${client_info_json}" | jq '.data.tunnels | length')" -gt 0 ]; then
        tunnel_info_json=$(echo "${client_info_json}" | jq '.data.tunnels[0]')
    else
        local my_ip
        my_ip=$(curl -s https://checkip.amazonaws.com)
        [ -z "${my_ip}" ] && fail "Could not determine public IP address."
        
        local tunnel_response
        tunnel_response=$(rport_api "PUT" "/clients/${client_id}/tunnels?remote=22&scheme=ssh&acl=${my_ip}&idle-timeout-minutes=5&protocol=tcp")
        tunnel_info_json=$(echo "${tunnel_response}" | jq '.data')
    fi
    local lport
    lport=$(echo "${tunnel_info_json}" | jq -r '.lport')

    # 4. Get the ssh-user from the vault
    local vault_items_json
    vault_items_json=$(rport_api "GET" "/vault?filter[client_id]=${client_id}")
    local ssh_user_vault_id
    ssh_user_vault_id=$(echo "${vault_items_json}" | jq -r '.data[] | select(.key == "ssh-user") | .id')
    [ -z "${ssh_user_vault_id}" ] && fail "Client ${client_name}: Failed to look up 'ssh-user' in vault."

    local ssh_user_value_json
    ssh_user_value_json=$(rport_api "GET" "/vault/${ssh_user_vault_id}")
    local ssh_user
    ssh_user=$(echo "${ssh_user_value_json}" | jq -r '.data.value')
    [ -z "${ssh_user}" ] && fail "Client ${client_name}: Vault key 'ssh-user' has no value."

    # 5. Print the connection details for other scripts to use
    echo "${ssh_user}|${RPORT_HOST}|${lport}"
}

main "$@"