#!/bin/bash

# Fetches and displays the status of the rport server.

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

    readonly RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"

    local body
    body=$(rport_api "GET" "/status")
   
    # The API returns the status object inside a "data" key.
    # We extract and pretty-print it with jq, which matches the README example.
    echo "$body" | jq '.data'
}

main "$@"