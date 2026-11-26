#!/bin/bash
# Deprecated compatibility name: rport-scp is now procy-scp. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-scp is deprecated; use procy-scp (same arguments and output)." >&2
# Run procy-scp from this script's directory (symlinks resolved): procy-scp.sh in a checkout, procy-scp when the
# scripts were copied into a bin directory without their suffix; else whatever procy-scp is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-scp.sh" "${dir}/procy-scp"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-scp "$@"
