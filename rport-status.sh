#!/bin/bash
# Deprecated compatibility name: rport-status is now procy-status. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-status is deprecated; use procy-status (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-status.sh" "$@"
