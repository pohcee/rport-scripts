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

# --- End Helper Functions ---