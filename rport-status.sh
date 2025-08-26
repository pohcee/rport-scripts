#!/bin/bash

# Fetches and displays the status of the rport server.

set -euo pipefail

# --- Helper Functions ---
# A function to print error messages to stderr and exit.
fail() {
    printf >&2 "Error: %s\n" "$1"
    exit 1
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

    local RPORT_URL_ROOT="https://${RPORT_HOST}/api/v1"
    local endpoint="/status"
    
    # -w "\n%{http_code}" appends the status code to the output
    local response
    response=$(curl -s -X GET -w "\n%{http_code}" -u "${RPORT_CREDENTIALS}" "${RPORT_URL_ROOT}${endpoint}")
    
    local http_code
    http_code=$(tail -n1 <<< "$response")
    local body
    body=$(sed '$ d' <<< "$response")

    if [[ "$http_code" -ne 200 ]]; then
        # Try to get a meaningful error from the JSON response, otherwise show the body
        local err_msg
        err_msg=$(echo "$body" | jq -r '.error.text // .')
        fail "API request failed for ${endpoint}: HTTP ${http_code} - ${err_msg}"
    fi

    # The API returns the status object inside a "data" key.
    # We extract and pretty-print it with jq, which matches the README example.
    echo "$body" | jq '.data'
}

main "$@"