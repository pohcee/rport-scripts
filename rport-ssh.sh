#!/bin/bash

set -e

VERBOSE=0

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -lt 1 ]; then
  echo "Usage: $0 [-v|--verbose] clientName [command]"
  exit 1
fi

clientName=$1
shift

[ $VERBOSE -eq 1 ] && echo "[verbose] Getting tunnel for client: $clientName"

if SSH_CONN=$(rport-tunnel "$clientName" 2>&1); then
  :
else
  TUNNEL_EXIT_CODE=$?
  echo "Error: Failed to establish tunnel for client '$clientName'"
  if [ $VERBOSE -eq 1 ]; then
    echo "[verbose] rport-tunnel exit code: $TUNNEL_EXIT_CODE"
    echo "[verbose] rport-tunnel output: $SSH_CONN"
  else
    ROOT_CAUSE=$(printf '%s\n' "$SSH_CONN" | grep '❌ Error:' | tail -n1)
    if [ -z "$ROOT_CAUSE" ]; then
      ROOT_CAUSE=$(printf '%s\n' "$SSH_CONN" | sed '/^[[:space:]]*$/d' | tail -n1)
    fi
    [ -n "$ROOT_CAUSE" ] && echo "$ROOT_CAUSE"
  fi
  exit 1
fi

[ $VERBOSE -eq 1 ] && echo "[verbose] Tunnel established: $SSH_CONN"

SSH_DETAILS=(${SSH_CONN//|/ })
SSH_PATH=ssh://${SSH_DETAILS[0]}@${SSH_DETAILS[1]}:${SSH_DETAILS[2]}

[ $VERBOSE -eq 1 ] && echo "[verbose] SSH path: $SSH_PATH"
[ $VERBOSE -eq 1 ] && echo "[verbose] User: ${SSH_DETAILS[0]}, Host: ${SSH_DETAILS[1]}, Port: ${SSH_DETAILS[2]}"

echo ssh: connecting to "$SSH_PATH"
# Since the host/port is reused for the tunnel, we skip host checks
if [ $VERBOSE -eq 1 ]; then
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=verbose "$SSH_PATH" "$@"
else
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet "$SSH_PATH" "$@"
fi
