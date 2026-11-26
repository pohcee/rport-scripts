#!/bin/bash
# Deprecated compatibility name: rport-status is now procy-status. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-status is deprecated; use procy-status (same arguments and output)." >&2
# Run procy-status from this script's directory (symlinks resolved): procy-status.sh in a checkout, procy-status when the
# scripts were copied into a bin directory without their suffix; else whatever procy-status is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-status.sh" "${dir}/procy-status"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-status "$@"
