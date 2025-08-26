#!/bin/bash

# Lists rport clients.
# By default, it prints a human-readable table matching the README.
# With --json or --nostatus, it prints the raw JSON from the API for scripting.

set -euo pipefail

# --- Helper Functions ---
fail() {
    printf >&2 "Error: %s\n" "$1"
    exit 1
}

rport_api() {
    local method="$1"
    local endpoint="$2"
    local response

    response=$(curl -s -X "$method" -w "\n%{http_code}" -u "${RPORT_CREDENTIALS}" "${RPORT_URL_ROOT}${endpoint}")

    local http_code
    http_code=$(tail -n1 <<<"$response")
    local body
    body=$(sed '$ d' <<<"$response")

    if [[ "$http_code" -ne 200 ]]; then
        local err_msg
        err_msg=$(echo "$body" | jq -r '.error.text // .')
        fail "API request failed for ${endpoint}: HTTP ${http_code} - ${err_msg}"
    fi
    echo "$body"
}
# --- End Helper Functions ---

# --- Main Script ---
main() {
    # Check for required environment variables
    [ -z "${RPORT_HOST:-}" ] && fail "RPORT_HOST environment variable not set."
    [ -z "${RPORT_CREDENTIALS:-}" ] && fail "RPORT_CREDENTIALS environment variable not set."

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."
    command -v column >/dev/null || fail "'column' is required but not installed. Please install it (e.g., 'bsdmainutils' on Debian/Ubuntu)."

    local output_format="table"
    if [[ "${1:-}" == "--nostatus" || "${1:-}" == "--json" ]]; then
        output_format="json"
    fi

    readonly RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"

    local clients_json
    clients_json=$(rport_api "GET" "/clients")

    if [[ "$output_format" == "json" ]]; then
        echo "$clients_json"
        exit 0
    fi

    # Table format generation. This is much more efficient than the old script
    # as it uses a single API call.
    local table_header="CLIENT_NAME\tCLIENT_ID\tHOSTNAME\tHOST_USER\tTUNNELS"
    local table_body
    table_body=$(echo "$clients_json" | jq -r '
        .data[]? | [
            .name, .id, .hostname, .username, (.tunnels | length)
        ] | @tsv
    ')

    # Print header and body, then format with column for a clean table view.
    (echo -e "$table_header"; echo "$table_body") | column -t -s $'\t'
}

main "$@"