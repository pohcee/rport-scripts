#!/bin/bash

set -euo pipefail

# Function to print usage and exit
usage() {
  echo "Usage: $0 <remote> <local_mount_point>"
  echo "  Mount a remote rport client directory locally via SSHFS."
  echo "  Remote must be specified as <client_name>:/remote/path"
  echo "  Example: $0 client-1:/home/user /mnt/remote"
  exit 1
}

main() {
    if [ $# -ne 2 ]; then
        usage
    fi

    local remote_spec="$1"
    local local_mount_point="$2"

    if ! [[ "$remote_spec" == *:* ]]; then
        echo "Error: Remote must be in the format <client_name>:/remote/path" >&2
        usage
    fi

    local client_name="${remote_spec%%:*}"
    local remote_path="${remote_spec#*:}"

    if [ ! -d "$local_mount_point" ]; then
        echo "Error: Local mount point '$local_mount_point' is not a directory or does not exist." >&2
        exit 1
    fi

    local ssh_conn
    ssh_conn=$(rport-tunnel "$client_name")
    if [ -z "$ssh_conn" ]; then
      echo "Error: Failed to create tunnel for client '$client_name'." >&2
      exit 1
    fi

    local ssh_user ssh_host ssh_port
    IFS='|' read -r ssh_user ssh_host ssh_port _ <<<"$ssh_conn"

    local remote_fs_spec="${ssh_user}@${ssh_host}:${remote_path}"
    local sshfs_opts=("-p" "$ssh_port" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no" "-o" "LogLevel=quiet" "-o" "reconnect" "-o" "ServerAliveInterval=15")

    echo "sshfs: mounting ${client_name}:${remote_path} to ${local_mount_point}"
    sshfs "${sshfs_opts[@]}" "${remote_fs_spec}" "${local_mount_point}"
}

main "$@"
