#!/bin/bash

# Fetches and displays the status of the Procy server.

set -euo pipefail

# Source the utility functions
# readlink -f resolves symlinks to find the true script directory
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
UTILS_FILE="${SCRIPT_DIR}/procy-utils.sh"
if [ ! -f "$UTILS_FILE" ]; then
    echo "Error: Missing procy-utils.sh. It should be in the same directory as the script." >&2
    exit 1
fi
# shellcheck source=procy-utils.sh
source "$UTILS_FILE"

usage() {
    local exit_code="${1:-0}"
    cat <<EOF
Usage: $0 [-h|--help]
  Fetch and display Procy server status as JSON.
  -h, --help  Show this help message.
EOF
    exit "$exit_code"
}

# --- Main Script ---
main() {
    case "${1:-}" in
        -h|--help)
            usage 0
            ;;
        "")
            ;;
        *)
            usage 1
            ;;
    esac

    # Check for required environment variables (PROCY_*, falling back to legacy RPORT_*)
    procy_require_env

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."


    local body
    body=$(procy_api "GET" "/status")
   
    # The API returns the status object inside a "data" key.
    # We extract and pretty-print it with jq, which matches the README example.
    echo "$body" | jq '.data'
}

main "$@"