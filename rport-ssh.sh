#!/bin/bash

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 clientName [command]"
  exit 1
fi

clientName=$1
shift

SSH_CONN=$(rport-tunnel "$clientName")
SSH_DETAILS=(${SSH_CONN//|/ })
SSH_PATH=ssh://${SSH_DETAILS[0]}@${SSH_DETAILS[1]}:${SSH_DETAILS[2]}

if [ $? -eq 0 ]; then
  echo ssh: connecting to "$SSH_PATH"
  # Since the host/port is reused for the tunnel, we skip host checks
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet "$SSH_PATH" "$@"
fi
