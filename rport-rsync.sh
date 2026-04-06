#!/bin/bash

set -e

# Function to print usage and exit
usage() {
  echo "Usage: $0 [-d] <source> <destination>"
  echo "  Sync files between local and a remote rport client using rsync over SSH."
  echo "  -d  Delete files in destination that do not exist in source."
  echo "  Remote path must be specified as <client_name>:<path>"
  echo "  Example: $0 ./local-dir/ client-1:/remote/dir/"
  echo "  Example: $0 -d client-1:/remote/dir/ ./local-dir/"
  exit 1
}

DELETE_DEST=0
while getopts ":d" opt; do
  case "$opt" in
    d) DELETE_DEST=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -ne 2 ]; then
  usage
fi

SRC=$1
DST=$2

# Identify which argument is remote
if [[ "$SRC" == *:* && "$DST" != *:* ]]; then
  # Remote to local sync
  CLIENT_NAME=${SRC%%:*}
  REMOTE_PATH=${SRC#*:}
  LOCAL_PATH=$DST
  REMOTE_TO_LOCAL=1
elif [[ "$DST" == *:* && "$SRC" != *:* ]]; then
  # Local to remote sync
  CLIENT_NAME=${DST%%:*}
  REMOTE_PATH=${DST#*:}
  LOCAL_PATH=$SRC
  REMOTE_TO_LOCAL=0
else
  # Error cases
  if [[ "$SRC" == *:* && "$DST" == *:* ]]; then
    echo "Error: Both source and destination cannot be remote." >&2
  else
    echo "Error: One of source or destination must be remote (e.g., client-name:/path/to/dir)." >&2
  fi
  usage
fi

# Get SSH tunnel connection details. Assuming rport-tunnel <client_name> returns "user|host|port"
SSH_CONN=$(rport-tunnel "$CLIENT_NAME")
if [ -z "$SSH_CONN" ]; then
  echo "Error: Failed to create tunnel for client '$CLIENT_NAME'." >&2
  exit 1
fi

IFS='|' read -r SSH_USER SSH_HOST SSH_PORT _ <<<"$SSH_CONN"

RSYNC_OPTS=("-a" "--info=progress2")
if [ "$DELETE_DEST" -eq 1 ]; then
  RSYNC_OPTS+=("--delete")
fi
RSYNC_SSH_CMD="ssh -p ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet"
REMOTE_SPEC="${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}"

if [ "$REMOTE_TO_LOCAL" -eq 1 ]; then
  echo "rsync: syncing from ${CLIENT_NAME}:${REMOTE_PATH} to ${LOCAL_PATH}"
  rsync "${RSYNC_OPTS[@]}" -e "${RSYNC_SSH_CMD}" "${REMOTE_SPEC}" "${LOCAL_PATH}"
else
  echo "rsync: syncing from ${LOCAL_PATH} to ${CLIENT_NAME}:${REMOTE_PATH}"
  rsync "${RSYNC_OPTS[@]}" -e "${RSYNC_SSH_CMD}" "${LOCAL_PATH}" "${REMOTE_SPEC}"
fi