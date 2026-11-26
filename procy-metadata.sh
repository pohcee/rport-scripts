#!/bin/bash

# Shows metadata (vault key/value pairs) for a Procy client in JSON format.

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
    local exit_code="${1:-1}"
    echo "Usage: $0 <client_name>"
    echo "  Show metadata for the specified client as JSON."
    echo "  -h, --help  Show this help message."
    exit "$exit_code"
}

# --- Main Script ---
main() {
    case "${1:-}" in
        -h|--help)
            usage 0
            ;;
    esac

    [ $# -ne 1 ] && usage

    local client_name="$1"

    # Check for required environment variables (PROCY_*, falling back to legacy RPORT_*)
    procy_require_env

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."


    local client_id
    client_id=$(procy_get_client_id_by_name "${client_name}")

    local metadata_json
    metadata_json=$(procy_get_client_metadata_json "${client_id}")
    echo "${metadata_json}" | jq .
}

main "$@"