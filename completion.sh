#!/bin/bash

# Bash completion for procy-cli: the procy-* commands and their deprecated rport-* names.

# Caches client names to avoid slow API calls on every tab press.
# Cache is stored in /tmp and expires after 5 minutes (300 seconds).
_procy_get_clients() {
    local cache_file="/tmp/procy-clients.cache"
    local cache_ttl=300 # 5 minutes in seconds

    if [ -f "$cache_file" ] && [ "$(($(date +%s) - $(date +%s -r "$cache_file")))" -lt "$cache_ttl" ]; then
        cat "$cache_file"
    else
        # The --nostatus flag is assumed to be a faster, completion-friendly version.
        # Redirect stderr to /dev/null to prevent API error messages from breaking completion.
        # Prefer procy-clients; fall back to the legacy name if only that is on PATH.
        local clients_cmd=procy-clients
        command -v procy-clients >/dev/null 2>&1 || clients_cmd=rport-clients
        local clients
        clients=$("$clients_cmd" --nostatus 2>/dev/null | jq -cr '.data[]?.name | select(. != null)')
        if [ -n "$clients" ]; then
            echo "$clients" >"$cache_file"
            echo "$clients"
        fi
    fi
}

_procy_completion() {
    local cur command
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    # The subcommand without its procy-/rport- prefix (and any path), so both names behave the same.
    command="${COMP_WORDS[0]##*/}"
    command="${command#procy-}"
    command="${command#rport-}"

    # For scp/rsync, if one argument already contains a colon, we're done with clients.
    if [[ "$command" == "scp" || "$command" == "rsync" ]]; then
        local word
        for word in "${COMP_WORDS[@]}"; do
            if [[ "$word" == *:* && "$word" != "$cur" ]]; then
                return 0 # Fallback to default (file) completion
            fi
        done
    fi

    # For sshfs, client completion is only for the first argument.
    if [[ "$command" == "sshfs" && ${COMP_CWORD} -gt 1 ]]; then
        return 0
    fi

    local opts
    opts=$(_procy_get_clients)
    # shellcheck disable=SC2207 # client names contain no whitespace
    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    return 0
}
complete -F _procy_completion \
    procy-ssh procy-scp procy-rsync procy-sshfs procy-tunnel procy-metadata \
    rport-ssh rport-scp rport-rsync rport-sshfs rport-tunnel rport-metadata
