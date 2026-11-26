#!/bin/bash
# Deprecated compatibility name: rport-ssh is now procy-ssh. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-ssh is deprecated; use procy-ssh (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-ssh.sh" "$@"
