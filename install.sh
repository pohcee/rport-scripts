#!/bin/bash

set -e

BIN_DIR=~/bin # TODO: Choose where to install

# Required for completion script
apt -y install jq

# Install the python packages
pip install -r requirements.txt

# Install symlinks to the scripts
SRC_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; pwd -P)

# Create symbolic links
find ${SRC_DIR} -type f -name "rport-*" | xargs -I % ln -sf % ${BIN_DIR}

# TODO: Assign the following env vars in your ~/.bashrc 
#export RPORT_HOST=rport.changeme.com
#export RPORT_CREDENTIALS=admin:changeme

