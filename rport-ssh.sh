#!/bin/bash
# Deprecated compatibility name: rport-ssh is now procy-ssh. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-ssh is deprecated; use procy-ssh (same arguments and output)." >&2
# Run procy-ssh from this script's directory (symlinks resolved): procy-ssh.sh in a checkout, procy-ssh when the
# scripts were copied into a bin directory without their suffix; else whatever procy-ssh is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-ssh.sh" "${dir}/procy-ssh"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-ssh "$@"
