#!/bin/bash
# Deprecated compatibility name: rport-metadata is now procy-metadata. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-metadata is deprecated; use procy-metadata (same arguments and output)." >&2
# Run procy-metadata from this script's directory (symlinks resolved): procy-metadata.sh in a checkout, procy-metadata when the
# scripts were copied into a bin directory without their suffix; else whatever procy-metadata is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-metadata.sh" "${dir}/procy-metadata"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-metadata "$@"
