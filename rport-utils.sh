#!/bin/bash

# This script is not meant to be executed directly.
# It provides common utility functions for other rport scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed." >&2
    exit 1
fi

# --- Helper Functions ---

# A function to print error messages to stderr and exit.
fail() {
    printf >&2 "❌ Error: %s\n" "$1"
    exit 1
}

# A function to URL-encode a string for use in query parameters.
urlencode() {
    echo -n "$1" | jq -sRr @uri
}

# A function to make authenticated API calls to rport.
# Returns the response body. On HTTP errors, prints error details and fails.
rport_api() {
    local method="$1"
    local endpoint="$2"
    local response
    response=$(curl -s -X "$method" -w "\n%{http_code}" -u "${RPORT_CREDENTIALS}" "${RPORT_URL_ROOT}${endpoint}")
    local http_code
    http_code=$(tail -n1 <<<"$response")
    local body
    body=$(sed '$ d' <<<"$response")
    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        local err_msg
        err_msg=$(echo "$body" | jq -r '.error.text // .')
        fail "API request failed for ${endpoint}: HTTP ${http_code} - ${err_msg}"
    fi
    echo "$body"
}

# A function to make authenticated API calls to rport without failing on errors.
# Returns both the HTTP status code and response body separated by newline.
# First line: HTTP status code
# Remaining lines: response body
rport_api_raw() {
    local method="$1"
    local endpoint="$2"
    local response
    response=$(curl -s -X "$method" -w "\n%{http_code}" -u "${RPORT_CREDENTIALS}" "${RPORT_URL_ROOT}${endpoint}")
    echo "$response"
}

# Resolve an exact client name to client id.
rport_get_client_id_by_name() {
    local client_name="$1"
    local client_name_encoded
    client_name_encoded=$(urlencode "${client_name}")

    local clients_json
    clients_json=$(rport_api "GET" "/clients?filter%5Bname%5D=${client_name_encoded}")

    [ "$(echo "${clients_json}" | jq -r '.data | length')" -ne 1 ] && fail "Unable to find exact match for client: ${client_name}"

    echo "${clients_json}" | jq -r '.data[0].id'
}

# Get all vault items metadata for a client.
rport_get_client_vault_items() {
    local client_id="$1"
    rport_api "GET" "/vault?filter%5Bclient_id%5D=${client_id}"
}

# Get a vault item id for a specific key and client.
rport_get_vault_item_id_by_key() {
    local client_id="$1"
    local key="$2"

    local vault_items_json
    vault_items_json=$(rport_get_client_vault_items "${client_id}")

    echo "${vault_items_json}" | jq -r --arg key "${key}" '.data[]? | select(.key == $key) | .id' | head -n1
}

# Get vault value for a specific vault item id.
rport_get_vault_value_by_item_id() {
    local item_id="$1"
    local value_json
    value_json=$(rport_api "GET" "/vault/${item_id}")
    echo "${value_json}" | jq -r '.data.value // ""'
}

# Get vault value for a specific client and key.
rport_get_client_vault_value_by_key() {
    local client_id="$1"
    local key="$2"

    local item_id
    item_id=$(rport_get_vault_item_id_by_key "${client_id}" "${key}")
    [ -z "${item_id}" ] && fail "Client ${client_id}: Failed to look up '${key}' in vault."

    local value
    value=$(rport_get_vault_value_by_item_id "${item_id}")
    [ -z "${value}" ] && fail "Client ${client_id}: Vault key '${key}' has no value."

    echo "${value}"
}

# Build a JSON object of all vault key/value pairs for a client.
rport_get_client_metadata_json() {
    local client_id="$1"
    local vault_items_json
    vault_items_json=$(rport_get_client_vault_items "${client_id}")

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
        item_value=$(rport_get_vault_value_by_item_id "${item_id}")

        metadata_json=$(jq -nc \
            --argjson obj "${metadata_json}" \
            --arg key "${item_key}" \
            --arg value "${item_value}" \
            '$obj + {($key): $value}')
    done < <(echo "${vault_items_json}" | jq -c '.data[]')

    echo "${metadata_json}"
}

# --- End Helper Functions ---