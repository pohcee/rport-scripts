#!/bin/bash

set -e
 
# Function to print usage and exit
usage() {
  echo "Usage: $0 <source> <destination>"
  echo "  Copy files between local and a remote rport client."
  echo "  Remote path must be specified as <client_name>:<path>"
  echo "  Example: $0 local.txt client-1:/remote/path/local.txt"
  echo "  Example: $0 client-1:/remote/path/file.txt /local/path/"
  exit 1
}

if [ $# -ne 2 ]; then
  usage
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

# Get SSH tunnel connection details. Assuming rport-tunnel <client_name> returns "user|host|port"
SSH_CONN=$(rport-tunnel "$CLIENT_NAME")
if [ -z "$SSH_CONN" ]; then
  echo "Error: Failed to create tunnel for client '$CLIENT_NAME'." >&2
  exit 1
fi

IFS='|' read -r SSH_USER SSH_HOST SSH_PORT _ <<<"$SSH_CONN"

SCP_OPTS=("-r" "-P" "$SSH_PORT" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no" "-o" "LogLevel=quiet")
REMOTE_SPEC="${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}"

if [ "$REMOTE_TO_LOCAL" -eq 1 ]; then
  echo "scp: copying from ${CLIENT_NAME}:${REMOTE_PATH} to ${LOCAL_PATH}"
  scp "${SCP_OPTS[@]}" "${REMOTE_SPEC}" "${LOCAL_PATH}"
else
  echo "scp: copying from ${LOCAL_PATH} to ${CLIENT_NAME}:${REMOTE_PATH}"
  scp "${SCP_OPTS[@]}" "${LOCAL_PATH}" "${REMOTE_SPEC}"
fi
