#!/bin/bash

# A robust installer for rport-scripts.
# It checks prerequisites, installs scripts to a local bin directory,
# and helps configure the shell environment.

set -euo pipefail

# --- Configuration ---
# Default installation directory for the scripts.
# Using ~/.local/bin is a modern standard for user-installed executables.
readonly BIN_DIR="${HOME}/.local/bin"
# ---

fail() {
    printf >&2 "❌ Error: %s\n" "$1"
    exit 1
}

info() {
    printf "✅ %s\n" "$1"
}

warn() {
    printf "⚠️ %s\n" "$1"
}

main() {
    local SRC_DIR
    SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    info "Starting rport-scripts installation..."
    echo

    # 1. Check for required commands
    info "Checking prerequisites (jq, curl, ssh, scp, sshfs)..."
    command -v jq >/dev/null || fail "'jq' is required but not installed. Please install it."
    command -v curl >/dev/null || fail "'curl' is required but not installed. Please install it."
    command -v ssh >/dev/null || fail "'ssh' is required but not installed. Please install it."
    command -v scp >/dev/null || fail "'scp' is required but not installed. Please install it."
    command -v sshfs >/dev/null || fail "'sshfs' is required but not installed. Please install it."

    # 2. Ensure installation directory exists
    info "Scripts will be installed to '${BIN_DIR}'."
    mkdir -p "${BIN_DIR}"
    echo

    # 3. Install the scripts by creating symbolic links
    info "Installing scripts..."
    for script_path in "${SRC_DIR}"/rport-*.sh; do
        if [ -f "${script_path}" ]; then
            local script_filename
            script_filename=$(basename "${script_path}")
            local command_name="${script_filename%.sh}"
            chmod +x "${script_path}"
            ln -sf "${script_path}" "${BIN_DIR}/${command_name}"
            info "  - Installed '${command_name}'"
        fi
    done
    echo

    # 4. Install shell completion
    info "Setting up shell completion..."
    local shell_profile=""
    local current_shell
    current_shell="$(basename "${SHELL}")"

    if [[ "${current_shell}" == "bash" ]]; then
        shell_profile="${HOME}/.bashrc"
    elif [[ "${current_shell}" == "zsh" ]]; then
        shell_profile="${HOME}/.zshrc"
    fi

    if [ -n "${shell_profile}" ] && [ -f "${shell_profile}" ]; then
        local completion_line="source '${SRC_DIR}/completion.sh'"
        if ! grep -qF -- "${completion_line}" "${shell_profile}"; then
            printf "\n# rport-scripts shell completion\n%s\n" "${completion_line}" >> "${shell_profile}"
            info "Completion script added to '${shell_profile}'."
        fi
    fi
    echo

    # 5. Final instructions
    info "Installation complete!"
    echo
    warn "Please review the following and take action if necessary:"
    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        echo "  - Your PATH does not include '${BIN_DIR}'. Add this to your shell profile:"
        echo "    export PATH=\"${BIN_DIR}:\$PATH\""
    fi
    if [ -z "${RPORT_HOST:-}" ] || [ -z "${RPORT_CREDENTIALS:-}" ]; then
        echo "  - Set RPORT environment variables in your shell profile:"
        echo "    export RPORT_HOST=rport.yourcompany.com"
        echo "    export RPORT_CREDENTIALS=youruser:yourpassword"
    fi
    echo "  - For all changes to take effect, start a new shell or run: source ${shell_profile:-~/.bashrc}"
    echo
}

main "$@"
