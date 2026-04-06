#!/bin/bash

# Shows metadata (vault key/value pairs) for an rport client in JSON format.

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

usage() {
    echo "Usage: $0 <client_name>"
    echo "  Show metadata for the specified client as JSON."
    exit 1
}

# --- Main Script ---
main() {
    [ $# -ne 1 ] && usage

    local client_name="$1"

    # Check for required environment variables
    [ -z "${RPORT_HOST:-}" ] && fail "RPORT_HOST environment variable not set."
    [ -z "${RPORT_CREDENTIALS:-}" ] && fail "RPORT_CREDENTIALS environment variable not set."

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."

    readonly RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"

    local client_id
    client_id=$(rport_get_client_id_by_name "${client_name}")

    local metadata_json
    metadata_json=$(rport_get_client_metadata_json "${client_id}")
    echo "${metadata_json}" | jq .
}

main "$@"