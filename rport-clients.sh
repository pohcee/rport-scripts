#!/bin/bash
# Deprecated compatibility name: rport-clients is now procy-clients. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-clients is deprecated; use procy-clients (same arguments and output)." >&2
# Run procy-clients from this script's directory (symlinks resolved): procy-clients.sh in a checkout, procy-clients when the
# scripts were copied into a bin directory without their suffix; else whatever procy-clients is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-clients.sh" "${dir}/procy-clients"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-clients "$@"
