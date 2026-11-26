#!/bin/bash
# Deprecated compatibility name: rport-metadata is now procy-metadata. This wrapper keeps existing callers working.
# The notice goes to stderr and only when stderr is a terminal, so captured output stays byte-identical.
[ -t 2 ] && echo "rport-metadata is deprecated; use procy-metadata (same arguments and output)." >&2
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-metadata.sh" "$@"
