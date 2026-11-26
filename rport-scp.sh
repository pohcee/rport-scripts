#!/bin/bash
# Deprecated compatibility name: rport-scp is now procy-scp. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-scp is deprecated; use procy-scp (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-scp.sh" "$@"
