#!/bin/bash

# Lists rport clients.
# By default, it prints a human-readable table matching the README.
# With --json or --nostatus, it prints the raw JSON from the API for scripting.

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