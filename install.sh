#!/bin/bash

set -e

fail() {
    printf >&2 "Error: $1\n"
    exit 1
}

req_cmd_exists() {
    command -v $1 >/dev/null 2>&1 || { fail "Command '$1' is required, but not installed."; }
}

BIN_DIR=~/bin # TODO: Choose where to install

# Required for completion script
req_cmd_exists jq

# Install the python packages
pip install -r requirements.txt >/dev/null 2>&1 || { fail "Failed to install pip via requirements.txt."; }

# Install symlinks to the scripts
SRC_DIR=$(
    cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)

# Create symbolic links
find ${SRC_DIR} -type f -name "rport-*" | xargs -I % ln -sf % ${BIN_DIR}

# TODO: Assign the following env vars in your ~/.bashrc
#export RPORT_HOST=rport.changeme.com
#export RPORT_CREDENTIALS=admin:changeme

echo -n "Rport server version: "
rport-status | jq -r '.version'
