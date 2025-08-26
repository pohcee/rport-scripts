#!/bin/bash

# Bash completion for rport-scripts

# Caches client names to avoid slow API calls on every tab press.
# Cache is stored in /tmp and expires after 5 minutes (300 seconds).
_rport_get_clients() {
    local cache_file="/tmp/rport-clients.cache"
    local cache_ttl=300 # 5 minutes in seconds

    if [ -f "$cache_file" ] && [ "$(($(date +%s) - $(date +%s -r "$cache_file")))" -lt "$cache_ttl" ]; then
        cat "$cache_file"
    else
        # The --nostatus flag is assumed to be a faster, completion-friendly version.
        # Redirect stderr to /dev/null to prevent API error messages from breaking completion.
        local clients
        clients=$(rport-clients --nostatus 2>/dev/null | jq -cr '.data[]?.name | select(. != null)')
        if [ -n "$clients" ]; then
            echo "$clients" >"$cache_file"
            echo "$clients"
        fi
    fi
}

_rport_completion() {
    local cur prev command opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    command="${COMP_WORDS[0]}"

    # For rport-scp, if one argument already contains a colon, we're done with clients.
    if [[ "$command" == "rport-scp" ]]; then
        for word in "${COMP_WORDS[@]}"; do
            if [[ "$word" == *:* && "$word" != "$cur" ]]; then
                return 0 # Fallback to default (file) completion
            fi
        done
    fi

    # For rport-sshfs, client completion is only for the first argument.
    if [[ "$command" == "rport-sshfs" && ${COMP_CWORD} -gt 1 ]]; then
        return 0
    fi

    opts=$(_rport_get_clients)
    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    return 0
}
complete -F _rport_completion rport-ssh rport-scp rport-sshfs rport-tunnel
