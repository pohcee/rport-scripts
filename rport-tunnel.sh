#!/bin/bash
# Deprecated compatibility name: rport-tunnel is now procy-tunnel. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-tunnel is deprecated; use procy-tunnel (same arguments and output)." >&2
# Run procy-tunnel from this script's directory (symlinks resolved): procy-tunnel.sh in a checkout, procy-tunnel when the
# scripts were copied into a bin directory without their suffix; else whatever procy-tunnel is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-tunnel.sh" "${dir}/procy-tunnel"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-tunnel "$@"
