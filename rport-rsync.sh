#!/bin/bash
# Deprecated compatibility name: rport-rsync is now procy-rsync. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-rsync is deprecated; use procy-rsync (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-rsync.sh" "$@"
