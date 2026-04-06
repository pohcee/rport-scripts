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
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: $0 <client_name> [remote_port]" >&2
        exit 1
    fi
    local client_name="$1"
    local remote_port="${2:-22}"

    [[ "${remote_port}" =~ ^[0-9]+$ ]] || fail "Invalid remote_port '${remote_port}': must be an integer between 1 and 65535."
    [ "${remote_port}" -ge 1 ] && [ "${remote_port}" -le 65535 ] || fail "Invalid remote_port '${remote_port}': must be between 1 and 65535."

    # Check for required environment variables
    [ -z "${RPORT_HOST:-}" ] && fail "RPORT_HOST environment variable not set."
    [ -z "${RPORT_CREDENTIALS:-}" ] && fail "RPORT_CREDENTIALS environment variable not set."

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."

    readonly RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"

    # 1. Get the client id from the name
    local client_id
    client_id=$(rport_get_client_id_by_name "${client_name}")

    # 2. Get client info and check connection state
    local client_info_json
    client_info_json=$(rport_api "GET" "/clients/${client_id}")
    [ "$(echo "${client_info_json}" | jq -r '.data.connection_state')" != "connected" ] && fail "Client ${client_name} is not connected."

    # 3. Get the ssh-user from the vault
    local ssh_user
    ssh_user=$(rport_get_client_vault_value_by_key "${client_id}" "ssh-user")

    # 4. Check for an existing tunnel on the requested remote port or create a new one
    local tunnel_info_json
    tunnel_info_json=$(echo "${client_info_json}" | jq -c --argjson remote_port "${remote_port}" 'first(.data.tunnels[]? | select((.rport | tonumber?) == $remote_port)) // empty')
    if [ -z "${tunnel_info_json}" ]; then
        local my_ip
        my_ip=$(curl -s https://checkip.amazonaws.com)
        [ -z "${my_ip}" ] && fail "Could not determine public IP address."

        local tunnel_response_raw
        tunnel_response_raw=$(rport_api_raw "PUT" "/clients/${client_id}/tunnels?remote=${remote_port}&scheme=ssh&acl=${my_ip}&idle-timeout-minutes=5&protocol=tcp")
        local http_code
        http_code=$(tail -n1 <<<"$tunnel_response_raw")
        local tunnel_response
        tunnel_response=$(sed '$ d' <<<"$tunnel_response_raw")
        
        # If tunnel already exists, fetch it instead of treating it as an error
        if [ "$http_code" -eq 400 ] && echo "${tunnel_response}" | jq -e '.errors[] | select(.code == "ERR_CODE_TUNNEL_TO_PORT_EXIST")' >/dev/null 2>&1; then
            # Tunnel already exists, fetch fresh client info and get the tunnel
            client_info_json=$(rport_api "GET" "/clients/${client_id}")
            tunnel_info_json=$(echo "${client_info_json}" | jq -c --argjson remote_port "${remote_port}" 'first(.data.tunnels[]? | select((.rport | tonumber?) == $remote_port)) // empty')
            [ -z "${tunnel_info_json}" ] && fail "Tunnel to port ${remote_port} exists but could not retrieve its details."
        elif [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
            local err_msg
            err_msg=$(echo "${tunnel_response}" | jq -r '.error.text // .')
            fail "Failed to create tunnel for ${client_name}: HTTP ${http_code} - ${err_msg}"
        else
            tunnel_info_json=$(echo "${tunnel_response}" | jq '.data')
        fi
    fi
    local lport
    lport=$(echo "${tunnel_info_json}" | jq -r '.lport')

    # 5. Print the connection details for other scripts to use
    echo "${ssh_user}|${RPORT_HOST}|${lport}"
}

main "$@"