#!/bin/bash
# Deprecated compatibility name: rport-sshfs is now procy-sshfs. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-sshfs is deprecated; use procy-sshfs (same arguments and output)." >&2
# Run procy-sshfs from this script's directory (symlinks resolved): procy-sshfs.sh in a checkout, procy-sshfs when the
# scripts were copied into a bin directory without their suffix; else whatever procy-sshfs is on PATH.
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
for target in "${dir}/procy-sshfs.sh" "${dir}/procy-sshfs"; do
    [ -x "${target}" ] && exec "${target}" "$@"
done
exec procy-sshfs "$@"
