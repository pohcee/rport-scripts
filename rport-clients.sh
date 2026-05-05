#!/bin/bash

# Lists rport clients.
# By default, it prints a human-readable table including online/offline status.
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

usage() {
    local exit_code="${1:-0}"
    printf '%s\n' \
        "Usage: $0 [--json|--nostatus] [--status=online|offline] [-h|--help]" \
        "  List rport clients." \
        "  By default, output is a human-readable table with online/offline status." \
        "" \
        "Options:" \
        "  --json, --nostatus   Output raw JSON from /clients for scripting." \
        "  --status=VALUE       Filter clients by status. VALUE must be online or offline." \
        "  -o, --online         Alias for --status=online." \
        "  -h, --help           Show this help message."
    exit "$exit_code"
}

filter_clients_by_status() {
    local clients_json="$1"
        local wanted_status="$2"

        echo "$clients_json" | jq --arg wanted_status "$wanted_status" '
        .data |= [
            .[] | select(
                (
                    (
                        .connection_state
                        // .state
                        // .status
                        // (if has("connected") then (if .connected then "connected" else "disconnected" end) else empty end)
                        // (if has("online") then (if .online then "online" else "offline" end) else empty end)
                        // (if has("disconnected_at") then (if .disconnected_at == null then "connected" else "disconnected" end) else empty end)
                        // "connected"
                    )
                    | ascii_downcase
                    | if test("^(connected|online|up|active)$") then "online" else "offline" end
                )
                == $wanted_status
            )
        ]
        | .meta.count = (.data | length)
    '
}

fetch_clients_for_table() {
    # Try a UI-style fielded request first (status-friendly, smaller payload).
    # Fallback to plain /clients if the server rejects requested fields.
    local endpoint="/clients?sort=name&fields%5Bclients%5D=id,name,hostname,disconnected_at,tunnels&page%5Blimit%5D=500&page%5Boffset%5D=0"
    local response_raw http_code body
    response_raw=$(rport_api_raw "GET" "$endpoint")
    http_code=$(tail -n1 <<<"$response_raw")
    body=$(sed '$ d' <<<"$response_raw")

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$body"
        return 0
    fi

    rport_api "GET" "/clients"
}

enrich_clients_for_table() {
        local clients_json="$1"

    # If list payload already has status and tunnel fields, avoid extra API calls.
    if echo "$clients_json" | jq -e '[.data[]? | ((has("disconnected_at") or has("connection_state") or has("state") or has("status") or has("connected") or has("online")) and has("tunnels"))] | all' >/dev/null 2>&1; then
                echo "$clients_json"
                return 0
        fi

        local tmp_rows
        tmp_rows=$(mktemp)
        local row id detail_json merged_row
        while IFS= read -r row; do
                id=$(echo "$row" | jq -r '.id')
                detail_json=$(rport_api "GET" "/clients/${id}")
                merged_row=$(jq -nc --argjson base "$row" --argjson detail "$(echo "$detail_json" | jq '.data')" '$base + $detail')
            echo "$merged_row" >> "$tmp_rows"
        done < <(echo "$clients_json" | jq -c '.data[]?')

        jq -n \
            --slurpfile data "$tmp_rows" \
            --argjson meta "$(echo "$clients_json" | jq '.meta // {}')" \
            '{data: $data, meta: $meta}'
        rm -f "$tmp_rows"
}

# --- Main Script ---
main() {
    local output_format="table"
    local status_filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage 0
                ;;
            --json|--nostatus)
                output_format="json"
                ;;
            --status=*)
                status_filter="${1#--status=}"
                ;;
            --status)
                shift
                status_filter="${1:-}"
                ;;
            -o|--online)
                status_filter="online"
                ;;
            *)
                usage 1
                ;;
        esac
        shift
    done

    if [[ -n "$status_filter" && "$status_filter" != "online" && "$status_filter" != "offline" ]]; then
        fail "Invalid --status value '$status_filter'. Expected 'online' or 'offline'."
    fi

    # Check for required environment variables
    [ -z "${RPORT_HOST:-}" ] && fail "RPORT_HOST environment variable not set."
    [ -z "${RPORT_CREDENTIALS:-}" ] && fail "RPORT_CREDENTIALS environment variable not set."

    # Check for required commands
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."
    command -v column >/dev/null || fail "'column' is required but not installed. Please install it (e.g., 'bsdmainutils' on Debian/Ubuntu)."

    readonly RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"

    local clients_json
    if [[ "$output_format" == "json" && -z "$status_filter" ]]; then
        clients_json=$(rport_api "GET" "/clients")
        echo "$clients_json"
        exit 0
    fi

    # Request status-friendly fields first, with fallback for older/stricter servers.
    clients_json=$(fetch_clients_for_table)

    # Some rport servers still return a slim /clients payload.
    # If status/tunnel fields are missing, enrich rows via /clients/<id> as fallback.
    clients_json=$(enrich_clients_for_table "$clients_json")

    if [[ -n "$status_filter" ]]; then
        clients_json=$(filter_clients_by_status "$clients_json" "$status_filter")
    fi

    if [[ "$output_format" == "json" ]]; then
        echo "$clients_json"
        exit 0
    fi

    # Table format generation. This is much more efficient than the old script
    # as it uses a single API call.
    local table_header="CLIENT_NAME\tCLIENT_ID\tSTATUS\tHOSTNAME\tTUNNELS"
    local table_body
    table_body=$(echo "$clients_json" | jq -r '
        .data[]? | [
            .name,
            .id,
            (
                (
                    .connection_state
                    // .state
                    // .status
                    // (if has("connected") then (if .connected then "connected" else "disconnected" end) else empty end)
                    // (if has("online") then (if .online then "online" else "offline" end) else empty end)
                    // (if has("disconnected_at") then (if .disconnected_at == null then "connected" else "disconnected" end) else empty end)
                    // "connected"
                )
                | ascii_downcase
                | if test("^(connected|online|up|active)$") then "online" else "offline" end
            ),
            (.hostname // ""),
            ((.tunnels // []) | length)
        ] | @tsv
    ')

    # Print header and body, then format with column for a clean table view.
    (echo -e "$table_header"; echo "$table_body") | column -t -s $'\t'
}

main "$@"