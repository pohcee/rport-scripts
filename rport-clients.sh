#!/bin/bash
# Deprecated compatibility name: rport-clients is now procy-clients. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-clients is deprecated; use procy-clients (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-clients.sh" "$@"
