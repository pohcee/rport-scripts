#!/bin/bash

# Uninstaller for rport-scripts.
# Removes symlinks, shell completion, and cache files.

set -euo pipefail

# --- Configuration ---
# Default installation directory for the scripts.
readonly BIN_DIR="${HOME}/.local/bin"
# ---

# --- Helper Functions ---
info() {
    printf "✅ %s\n" "$1"
}

warn() {
    printf "⚠️ %s\n" "$1"
}
# ---

main() {
    local SRC_DIR
    SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    info "Starting rport-scripts uninstallation..."
    echo

    # 1. Remove symbolic links from BIN_DIR
    info "Removing script symlinks from '${BIN_DIR}'..."
    for script_path in "${SRC_DIR}"/rport-*.sh; do
        if [ -f "${script_path}" ]; then
            local command_name
            command_name=$(basename "${script_path}" .sh)
            # Don't try to uninstall utility scripts that were never installed as commands
            if [[ "${command_name}" == "rport-utils" ]]; then
                continue
            fi
            local symlink_path="${BIN_DIR}/${command_name}"
            if [ -L "${symlink_path}" ]; then
                rm -f "${symlink_path}"
                info "  - Removed '${command_name}'"
            fi
        fi
    done
    echo

    # 2. Remove shell completion from profile
    info "Removing shell completion..."
    local shell_profile=""
    local current_shell
    current_shell="$(basename "${SHELL}")"

    if [[ "${current_shell}" == "bash" ]]; then
        shell_profile="${HOME}/.bashrc"
    elif [[ "${current_shell}" == "zsh" ]]; then
        shell_profile="${HOME}/.zshrc"
    fi

    if [ -n "${shell_profile}" ] && [ -f "${shell_profile}" ]; then
        # Use sed to remove the lines. -i.bak creates a backup, which is safer.
        local completion_line_pattern="source .*completion.sh"
        local completion_header_pattern="# rport-scripts shell completion"
        if grep -q -e "${completion_header_pattern}" -e "${completion_line_pattern}" "${shell_profile}"; then
            sed -i.bak -e "/${completion_header_pattern}/d" -e "/${completion_line_pattern}/d" "${shell_profile}"
            info "Completion script removed from '${shell_profile}'."
            info "A backup of your original profile was created at '${shell_profile}.bak'."
        fi
    fi
    echo

    # 3. Remove cache file
    info "Removing client cache file..."
    local cache_file="/tmp/rport-clients.cache"
    if [ -f "$cache_file" ]; then
        rm -f "$cache_file"
        info "  - Removed '${cache_file}'"
    fi
    echo

    # 4. Final instructions
    info "Uninstallation complete!"
    echo
    warn "Please perform the following manual steps:"
    echo "  - Remove the RPORT environment variables (RPORT_HOST, RPORT_CREDENTIALS) from your shell profile."
    echo "  - For all changes to take effect, start a new shell or run: source ${shell_profile:-~/.bashrc}"
    echo
}

main "$@"