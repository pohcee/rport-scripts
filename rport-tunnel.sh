#!/bin/bash

# Creates or reuses an SSH tunnel for a given rport client.
# On success, it prints the connection details pipe-separated:
# <ssh-user>|<rport-host>|<tunnel-port>

set -euo pipefail

# Source the utility functions
# readlink -f resolves symlinks to find the true script directory
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
UTILS_FILE="${SCRIPT_DIR}/rport-utils.sh"
if [ ! -f "$UTILS_FILE" ]; then
    echo "Error: Missing rport-utils.sh. It should be in the same directory as the script." >&2
    exit 1
fi
source "$UTILS_FILE"

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
    local client_name_encoded=$(urlencode "${client_name}")
    local clients_json=$(rport_api "GET" "/clients?filter%5Bname%5D=${client_name_encoded}")

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
    local vault_items_json=$(rport_api "GET" "/vault?filter%5Bclient_id%5D=${client_id}")
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