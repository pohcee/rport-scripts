#!/bin/bash

_funct() 
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts=$(rport-clients --nostatus | jq -cr '.[].name')

    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _funct rport-ssh rport-scp rport-sshfs rport-tunnel
