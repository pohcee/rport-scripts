#!/bin/bash

# This script is not meant to be executed directly.
# It provides common utility functions for the other procy-* scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0
  Shared helper library for the procy-* scripts.
  This file is meant to be sourced by other scripts, not executed directly.
EOF
        exit 0
    fi
    echo "This script should be sourced, not executed. Use -h or --help for details." >&2
    exit 1
fi

# Make `set -e` apply inside command substitutions too, so a `fail` in a helper
# called as $(func) stops the script instead of continuing with empty output.
shopt -s inherit_errexit 2>/dev/null || true

# --- Configuration ---

# Every PROCY_* setting falls back to its legacy RPORT_* name when unset or empty, so shells, CI runners and
# release tooling that still export RPORT_HOST / RPORT_CREDENTIALS keep working. PROCY_* wins when both are set.
# Add new settings to PROCY_ENV_NAMES (the suffix after PROCY_ / RPORT_).
PROCY_ENV_NAMES=(HOST CREDENTIALS)
procy_env_fallback() {
    local name new old
    for name in "${PROCY_ENV_NAMES[@]}"; do
        new="PROCY_${name}"
        old="RPORT_${name}"
        if [ -z "${!new:-}" ] && [ -n "${!old:-}" ]; then
            printf -v "${new}" '%s' "${!old}"
        fi
    done
}
procy_env_fallback

# --- Helper Functions ---

# A function to print error messages to stderr and exit.
fail() {
    printf >&2 "❌ Error: %s\n" "$1"
    exit 1
}

# Check the required settings and set PROCY_URL_ROOT, the API base URL.
procy_require_env() {
    [ -z "${PROCY_HOST:-}" ] && fail "PROCY_HOST environment variable not set (legacy name: RPORT_HOST)."
    [ -z "${PROCY_CREDENTIALS:-}" ] && fail "PROCY_CREDENTIALS environment variable not set (legacy name: RPORT_CREDENTIALS)."
    readonly PROCY_URL_ROOT="https://${PROCY_HOST}/api/v1"
}

# A function to URL-encode a string for use in query parameters.
urlencode() {
    echo -n "$1" | jq -sRr @uri
}

# Fail immediately on HTTP codes where retrying or falling back can't help.
# Each failed attempt counts toward the server's brute-force ban, so callers
# must not issue further requests after a 401 or 429.
procy_check_fatal_status() {
    local http_code="$1"
    case "$http_code" in
        401) fail "Authentication failed (HTTP 401). Check PROCY_CREDENTIALS." ;;
        429) fail "Rate limited / temporarily banned (HTTP 429). Wait before retrying." ;;
    esac
}

# A function to make authenticated API calls to the Procy server.
# Returns the response body. On HTTP errors, prints error details and fails.
procy_api() {
    local method="$1"
    local endpoint="$2"
    local response
    response=$(curl -s -X "$method" -w "\n%{http_code}" -u "${PROCY_CREDENTIALS}" "${PROCY_URL_ROOT}${endpoint}")
    local http_code
    http_code=$(tail -n1 <<<"$response")
    local body
    body=$(sed '$ d' <<<"$response")
    procy_check_fatal_status "$http_code"
    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        local err_msg
        err_msg=$(echo "$body" | jq -r '.error.text // .')
        fail "API request failed for ${endpoint}: HTTP ${http_code} - ${err_msg}"
    fi
    echo "$body"
}

# A function to make authenticated API calls to the Procy server without failing on errors
# (except 401/429, see procy_check_fatal_status).
# Returns both the HTTP status code and response body separated by newline.
# First line: HTTP status code
# Remaining lines: response body
procy_api_raw() {
    local method="$1"
    local endpoint="$2"
    local response
    response=$(curl -s -X "$method" -w "\n%{http_code}" -u "${PROCY_CREDENTIALS}" "${PROCY_URL_ROOT}${endpoint}")
    procy_check_fatal_status "$(tail -n1 <<<"$response")"
    echo "$response"
}

# Resolve an exact client name to client id.
procy_get_client_id_by_name() {
    local client_name="$1"
    local client_name_encoded
    client_name_encoded=$(urlencode "${client_name}")

    local clients_json
    clients_json=$(procy_api "GET" "/clients?filter%5Bname%5D=${client_name_encoded}")

    [ "$(echo "${clients_json}" | jq -r '.data | length')" -ne 1 ] && fail "Unable to find exact match for client: ${client_name}"

    echo "${clients_json}" | jq -r '.data[0].id'
}

# Get all vault items metadata for a client.
procy_get_client_vault_items() {
    local client_id="$1"
    procy_api "GET" "/vault?filter%5Bclient_id%5D=${client_id}"
}

# Get a vault item id for a specific key and client.
procy_get_vault_item_id_by_key() {
    local client_id="$1"
    local key="$2"

    local vault_items_json
    vault_items_json=$(procy_get_client_vault_items "${client_id}")

    echo "${vault_items_json}" | jq -r --arg key "${key}" '.data[]? | select(.key == $key) | .id' | head -n1
}

# Get vault value for a specific vault item id.
procy_get_vault_value_by_item_id() {
    local item_id="$1"
    local value_json
    value_json=$(procy_api "GET" "/vault/${item_id}")
    echo "${value_json}" | jq -r '.data.value // ""'
}

# Get vault value for a specific client and key.
procy_get_client_vault_value_by_key() {
    local client_id="$1"
    local key="$2"

    local item_id
    item_id=$(procy_get_vault_item_id_by_key "${client_id}" "${key}")
    [ -z "${item_id}" ] && fail "Client ${client_id}: Failed to look up '${key}' in vault."

    local value
    value=$(procy_get_vault_value_by_item_id "${item_id}")
    [ -z "${value}" ] && fail "Client ${client_id}: Vault key '${key}' has no value."

    echo "${value}"
}

# Build a JSON object of all vault key/value pairs for a client.
procy_get_client_metadata_json() {
    local client_id="$1"
    local vault_items_json
    vault_items_json=$(procy_get_client_vault_items "${client_id}")

    local item_count
    item_count=$(echo "${vault_items_json}" | jq -r '.data | length')
    if [ "${item_count}" -eq 0 ]; then
        echo "{}"
        return 0
    fi

    local metadata_json='{}'
    local item_line
    while IFS= read -r item_line; do
        local item_id
        item_id=$(echo "${item_line}" | jq -r '.id')
        local item_key
        item_key=$(echo "${item_line}" | jq -r '.key')
        local item_value
        item_value=$(procy_get_vault_value_by_item_id "${item_id}")

        metadata_json=$(jq -nc \
            --argjson obj "${metadata_json}" \
            --arg key "${item_key}" \
            --arg value "${item_value}" \
            '$obj + {($key): $value}')
    done < <(echo "${vault_items_json}" | jq -c '.data[]')

    echo "${metadata_json}"
}

# --- End Helper Functions ---