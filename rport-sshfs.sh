#!/bin/bash
# Deprecated compatibility name: rport-sshfs is now procy-sshfs. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-sshfs is deprecated; use procy-sshfs (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-sshfs.sh" "$@"
