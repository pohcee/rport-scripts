#!/bin/bash
# Deprecated compatibility name: rport-rsync is now procy-rsync. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-rsync is deprecated; use procy-rsync (same arguments and output)." >&2
# Run procy-rsync from this script's directory (symlinks resolved): procy-rsync.sh in a checkout, procy-rsync when the
# scripts were copied into a bin directory without their suffix; else whatever procy-rsync is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-rsync.sh" "${dir}/procy-rsync"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-rsync "$@"
