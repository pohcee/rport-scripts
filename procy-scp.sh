#!/bin/bash

set -e

# procy-tunnel is called from this script's own directory (symlinks resolved), so it works whichever
# command names (procy-* or the legacy rport-*) are on PATH.
PROCY_TUNNEL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/procy-tunnel.sh"
 
# Function to print usage and exit
usage() {
  local exit_code="${1:-1}"
  echo "Usage: $0 <source> <destination>"
  echo "  Copy files between local and a remote Procy client."
  echo "  -h, --help  Show this help message."
  echo "  Remote path must be specified as <client_name>:<path>"
  echo "  Example: $0 local.txt client-1:/remote/path/local.txt"
  echo "  Example: $0 client-1:/remote/path/file.txt /local/path/"
  exit "$exit_code"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage 0
fi

if [ $# -ne 2 ]; then
  usage 1
fi

SRC=$1
DST=$2

# Identify which argument is remote
if [[ "$SRC" == *:* && "$DST" != *:* ]]; then
  # Remote to local copy
  CLIENT_NAME=${SRC%%:*}
  REMOTE_PATH=${SRC#*:}
  LOCAL_PATH=$DST
  REMOTE_TO_LOCAL=1
elif [[ "$DST" == *:* && "$SRC" != *:* ]]; then
  # Local to remote copy
  CLIENT_NAME=${DST%%:*}
  REMOTE_PATH=${DST#*:}
  LOCAL_PATH=$SRC
  REMOTE_TO_LOCAL=0
else
  # Error cases
  if [[ "$SRC" == *:* && "$DST" == *:* ]]; then
    echo "Error: Both source and destination cannot be remote." >&2
  else
    echo "Error: One of source or destination must be remote (e.g., client-name:/path/to/file)." >&2
  fi
  usage
fi

# Get SSH tunnel connection details. procy-tunnel <client_name> returns "user|host|port"
SSH_CONN=$("$PROCY_TUNNEL" "$CLIENT_NAME")
if [ -z "$SSH_CONN" ]; then
  echo "Error: Failed to create tunnel for client '$CLIENT_NAME'." >&2
  exit 1
fi

IFS='|' read -r SSH_USER SSH_HOST SSH_PORT _ <<<"$SSH_CONN"

SCP_OPTS=("-r" "-P" "$SSH_PORT" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no" "-o" "LogLevel=quiet")
REMOTE_SPEC="${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}"

if [ "$REMOTE_TO_LOCAL" -eq 1 ]; then
  echo "scp: copying from ${CLIENT_NAME}:${REMOTE_PATH} to ${LOCAL_PATH}" >&2
  scp "${SCP_OPTS[@]}" "${REMOTE_SPEC}" "${LOCAL_PATH}"
else
  echo "scp: copying from ${LOCAL_PATH} to ${CLIENT_NAME}:${REMOTE_PATH}" >&2
  scp "${SCP_OPTS[@]}" "${LOCAL_PATH}" "${REMOTE_SPEC}"
fi
