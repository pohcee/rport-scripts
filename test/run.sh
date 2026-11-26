#!/bin/bash
# Test harness for procy-cli. Plain bash, no server needed: curl, ssh, scp, rsync and sshfs are stubbed (test/stubs).
# Usage: bash test/run.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STUBS="${ROOT}/test/stubs"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '     %s\n' "$2"; }

# assert_eq NAME EXPECTED ACTUAL
assert_eq() {
    if [ "$2" == "$3" ]; then ok "$1"; else not_ok "$1" "expected [$2] got [$3]"; fi
}
# assert_contains NAME HAYSTACK NEEDLE
assert_contains() {
    if [[ "$2" == *"$3"* ]]; then ok "$1"; else not_ok "$1" "[$3] not in [$2]"; fi
}
assert_not_contains() {
    if [[ "$2" != *"$3"* ]]; then ok "$1"; else not_ok "$1" "[$3] unexpectedly in [$2]"; fi
}

# Run a command in a clean environment: only the stubs and the system tools on PATH, no PROCY_*/RPORT_* unless
# given as VAR=value arguments before the command. stdout -> $OUT, stderr -> $ERR, exit code -> $RC.
# Fresh stub log per run.
run() {
    : >"${WORK}/curl.log"
    : >"${WORK}/ssh.log"
    local envs=()
    while [[ "${1:-}" == *=* ]]; do envs+=("$1"); shift; done
    env -i PATH="${STUBS}:/usr/local/bin:/usr/bin:/bin" HOME="${WORK}/home" STUB_LOG_DIR="${WORK}" \
        "${envs[@]}" "$@" >"${WORK}/out" 2>"${WORK}/err"
    RC=$?
    OUT="$(cat "${WORK}/out")"
    ERR="$(cat "${WORK}/err")"
    CURL_LOG="$(cat "${WORK}/curl.log")"
    SSH_LOG="$(cat "${WORK}/ssh.log")"
}

NEW=(PROCY_HOST=new.example PROCY_CREDENTIALS=newuser:newpass)
OLD=(RPORT_HOST=old.example RPORT_CREDENTIALS=olduser:oldpass)
mkdir -p "${WORK}/home"

echo "# clients --json"
run "${NEW[@]}" "${ROOT}/procy-clients.sh" --json
assert_eq "procy-clients --json exits 0 with PROCY_*" 0 "$RC"
assert_eq "procy-clients --json prints the API body" "$(cat "${ROOT}/test/fixtures/clients.json")" "$OUT"
assert_contains "procy-clients uses PROCY_CREDENTIALS" "$CURL_LOG" "-u newuser:newpass"
assert_contains "procy-clients uses PROCY_HOST" "$CURL_LOG" "https://new.example/api/v1/clients"
NEW_JSON_OUT="$(cat "${WORK}/out")"

run "${OLD[@]}" "${ROOT}/rport-clients.sh" --json
assert_eq "rport-clients --json exits 0 with RPORT_* only" 0 "$RC"
assert_contains "rport-clients falls back to RPORT_CREDENTIALS" "$CURL_LOG" "-u olduser:oldpass"
assert_contains "rport-clients falls back to RPORT_HOST" "$CURL_LOG" "https://old.example/api/v1/clients"
assert_eq "rport-clients --json stdout is byte-identical to procy-clients --json" "$NEW_JSON_OUT" "$(cat "${WORK}/out")"
assert_eq "rport-clients prints nothing on stderr when stderr is not a terminal" "" "$ERR"

run "${OLD[@]}" "${ROOT}/procy-clients.sh" --json
assert_eq "procy-clients works with RPORT_* only" 0 "$RC"
assert_contains "procy-clients falls back to RPORT_HOST" "$CURL_LOG" "https://old.example/api/v1/clients"

run "${NEW[@]}" "${OLD[@]}" "${ROOT}/rport-clients.sh" --json
assert_contains "PROCY_HOST wins over RPORT_HOST" "$CURL_LOG" "https://new.example/api/v1/clients"
assert_contains "PROCY_CREDENTIALS wins over RPORT_CREDENTIALS" "$CURL_LOG" "-u newuser:newpass"

run PROCY_HOST= RPORT_HOST=old.example PROCY_CREDENTIALS=c:c "${ROOT}/procy-clients.sh" --json
assert_contains "an empty PROCY_HOST falls back to RPORT_HOST" "$CURL_LOG" "https://old.example/api/v1/clients"

run "${ROOT}/procy-clients.sh" --json
assert_eq "missing settings exit 1" 1 "$RC"
assert_contains "missing settings name PROCY_HOST and the legacy name" "$ERR" "PROCY_HOST environment variable not set (legacy name: RPORT_HOST)"
run PROCY_HOST=h "${ROOT}/procy-clients.sh" --json
assert_contains "missing credentials name PROCY_CREDENTIALS" "$ERR" "PROCY_CREDENTIALS environment variable not set"

run "${NEW[@]}" "${ROOT}/procy-clients.sh" --status=online --json
assert_eq "procy-clients --status=online --json filters" '["dev1"]' "$(jq -c '[.data[].name]' <<<"$OUT")"
run "${OLD[@]}" "${ROOT}/rport-clients.sh" --status=online --json
assert_eq "rport-clients --status=online --json filters" '["dev1"]' "$(jq -c '[.data[].name]' <<<"$OUT")"

run "${NEW[@]}" STUB_HTTP_CODE=401 "${ROOT}/procy-clients.sh" --json
assert_contains "HTTP 401 names PROCY_CREDENTIALS" "$ERR" "Check PROCY_CREDENTIALS"

echo "# tunnel"
# Existing tunnel on a cluster node: connect to its tunnel_host.
run "${NEW[@]}" STUB_TUNNEL_HOST=node2.example "${ROOT}/procy-tunnel.sh" dev1
assert_eq "procy-tunnel exits 0" 0 "$RC"
assert_eq "procy-tunnel uses the existing tunnel's tunnel_host" "admin|node2.example|20001" "$OUT"
NEW_TUNNEL_OUT="$(cat "${WORK}/out")"
run "${OLD[@]}" STUB_TUNNEL_HOST=node2.example "${ROOT}/rport-tunnel.sh" dev1
assert_eq "rport-tunnel stdout is byte-identical to procy-tunnel" "$NEW_TUNNEL_OUT" "$(cat "${WORK}/out")"
assert_eq "rport-tunnel prints nothing on stderr when stderr is not a terminal" "" "$ERR"

# Standalone server: no tunnel_host, use the API host.
run "${NEW[@]}" "${ROOT}/procy-tunnel.sh" dev1
assert_eq "procy-tunnel without tunnel_host uses PROCY_HOST" "admin|new.example|20001" "$OUT"
run "${OLD[@]}" "${ROOT}/rport-tunnel.sh" dev1
assert_eq "rport-tunnel without tunnel_host uses RPORT_HOST fallback" "admin|old.example|20001" "$OUT"
run "${NEW[@]}" STUB_TUNNEL_HOST=null "${ROOT}/procy-tunnel.sh" dev1
assert_eq "procy-tunnel with tunnel_host null uses PROCY_HOST" "admin|new.example|20001" "$OUT"

# New tunnel (PUT) on a cluster: tunnel_host from the PUT response.
run "${NEW[@]}" STUB_NO_TUNNELS=1 STUB_TUNNEL_HOST=node3.example "${ROOT}/procy-tunnel.sh" dev1 2222
assert_eq "procy-tunnel creates a tunnel and uses its tunnel_host" "admin|node3.example|20002" "$OUT"
assert_contains "procy-tunnel PUTs with the caller's IP as ACL" "$CURL_LOG" "PUT https://new.example/api/v1/clients/c1/tunnels?remote=2222&scheme=ssh&acl=203.0.113.9"
run "${NEW[@]}" STUB_NO_TUNNELS=1 "${ROOT}/procy-tunnel.sh" dev1 2222
assert_eq "procy-tunnel created tunnel without tunnel_host uses PROCY_HOST" "admin|new.example|20002" "$OUT"

# Remote-host mode: host|port.
run "${NEW[@]}" STUB_NO_TUNNELS=1 STUB_TUNNEL_HOST=node3.example "${ROOT}/procy-tunnel.sh" dev1 104 192.168.1.50
assert_eq "procy-tunnel remote_host prints host|port" "node3.example|20002" "$OUT"
NEW_REMOTE_OUT="$(cat "${WORK}/out")"
run "${OLD[@]}" STUB_NO_TUNNELS=1 STUB_TUNNEL_HOST=node3.example "${ROOT}/rport-tunnel.sh" dev1 104 192.168.1.50
assert_eq "rport-tunnel remote_host stdout is byte-identical" "$NEW_REMOTE_OUT" "$(cat "${WORK}/out")"

echo "# ssh / scp"
run "${NEW[@]}" STUB_TUNNEL_HOST=node2.example "${ROOT}/procy-ssh.sh" dev1 uptime
assert_eq "procy-ssh exits 0" 0 "$RC"
assert_contains "procy-ssh connects to the tunnel_host" "$SSH_LOG" "ssh://admin@node2.example:20001 uptime"
assert_contains "procy-ssh prints its connect line on stderr" "$ERR" "ssh: connecting to dev1 via ssh://admin@node2.example:20001"
run "${OLD[@]}" "${ROOT}/rport-ssh.sh" dev1 uptime
assert_contains "rport-ssh works with RPORT_* only" "$SSH_LOG" "ssh://admin@old.example:20001 uptime"
assert_eq "rport-ssh stderr is just the connect line" "ssh: connecting to dev1 via ssh://admin@old.example:20001" "$ERR"
run "${NEW[@]}" STUB_CLIENT_STATE=disconnected "${ROOT}/procy-ssh.sh" dev1 uptime
assert_eq "procy-ssh fails when the tunnel fails" 1 "$RC"
assert_contains "procy-ssh failure keeps its message" "$OUT" "Error: Failed to establish tunnel for client 'dev1'"
assert_contains "procy-ssh failure shows the root cause" "$OUT" "Client dev1 is not connected."

run "${OLD[@]}" STUB_TUNNEL_HOST=node2.example "${ROOT}/rport-scp.sh" dev1:/etc/hosts "${WORK}/x"
assert_contains "rport-scp copies via the tunnel_host" "$SSH_LOG" "scp -r -P 20001"
assert_contains "rport-scp remote spec" "$SSH_LOG" "admin@node2.example:/etc/hosts"

echo "# status / metadata"
run "${NEW[@]}" "${ROOT}/procy-status.sh"
assert_eq "procy-status prints .data" '{"version":"0.16.1"}' "$(jq -c . <<<"$OUT")"
run "${OLD[@]}" "${ROOT}/rport-metadata.sh" dev1
assert_eq "rport-metadata prints vault key/values" '{"ssh-user":"admin"}' "$(jq -c . <<<"$OUT")"

echo "# deprecation notice on a terminal"
# script(1) gives the command a pty, so stderr is a terminal.
if command -v script >/dev/null 2>&1; then
    tty_out="$(env -i PATH="${STUBS}:/usr/bin:/bin" STUB_LOG_DIR="${WORK}" "${OLD[@]}" \
        script -qec "${ROOT}/rport-tunnel.sh dev1" /dev/null 2>&1 | tr -d '\r')"
    assert_contains "rport-tunnel prints a deprecation notice when stderr is a terminal" "$tty_out" "rport-tunnel is deprecated; use procy-tunnel"
    assert_contains "rport-tunnel still prints its output on a terminal" "$tty_out" "admin|old.example|20001"
    tty_out="$(env -i PATH="${STUBS}:/usr/bin:/bin" STUB_LOG_DIR="${WORK}" "${NEW[@]}" \
        script -qec "${ROOT}/procy-tunnel.sh dev1" /dev/null 2>&1 | tr -d '\r')"
    assert_not_contains "procy-tunnel prints no deprecation notice" "$tty_out" "deprecated"
else
    echo "skip deprecation-notice tty tests (no script(1))"
fi

echo "# completion"
comp_out="$(PATH="${STUBS}:/usr/bin:/bin" bash -c '
    source "$1"
    _procy_get_clients() { printf "dev1\ndev2\nother\n"; }
    for c in procy-ssh rport-ssh procy-tunnel rport-tunnel procy-scp rport-scp procy-metadata rport-metadata procy-rsync rport-rsync procy-sshfs rport-sshfs; do
        complete -p "$c" >/dev/null 2>&1 || echo "missing:$c"
    done
    for c in procy-ssh rport-ssh; do
        COMP_WORDS=("$c" "de"); COMP_CWORD=1; _procy_completion; echo "$c:${COMPREPLY[*]}"
    done
    for c in procy-scp rport-scp; do
        COMP_WORDS=("$c" "dev1:/tmp/x" "de"); COMP_CWORD=2; _procy_completion; echo "$c:${COMPREPLY[*]:-none}"
    done
    for c in procy-sshfs rport-sshfs; do
        COMP_WORDS=("$c" "dev1:/x" "de"); COMP_CWORD=2; _procy_completion; echo "$c:${COMPREPLY[*]:-none}"
    done
' _ "${ROOT}/completion.sh")"
assert_not_contains "completion is registered for both names" "$comp_out" "missing:"
assert_contains "procy-ssh completes client names" "$comp_out" "procy-ssh:dev1 dev2"
assert_contains "rport-ssh completes client names" "$comp_out" "rport-ssh:dev1 dev2"
assert_contains "procy-scp stops after a remote arg" "$comp_out" "procy-scp:none"
assert_contains "rport-scp stops after a remote arg" "$comp_out" "rport-scp:none"
assert_contains "procy-sshfs completes only the first arg" "$comp_out" "procy-sshfs:none"
assert_contains "rport-sshfs completes only the first arg" "$comp_out" "rport-sshfs:none"

echo "# install / uninstall into a temp HOME"
IHOME="${WORK}/ihome"
mkdir -p "${IHOME}"
: >"${IHOME}/.bashrc"
inst_env=(env -i PATH="${STUBS}:/usr/bin:/bin" HOME="${IHOME}" SHELL=/bin/bash)
"${inst_env[@]}" bash "${ROOT}/install.sh" >"${WORK}/install.out" 2>&1
assert_eq "install.sh exits 0" 0 "$?"
missing=""
for x in clients ssh scp rsync sshfs tunnel status metadata; do
    for p in procy rport; do
        [ -x "${IHOME}/.local/bin/${p}-${x}" ] || missing+=" ${p}-${x}"
    done
done
assert_eq "install.sh installs procy-* and rport-* commands" "" "${missing}"
utils_installed=no
if [ -e "${IHOME}/.local/bin/procy-utils" ] || [ -e "${IHOME}/.local/bin/rport-utils" ]; then utils_installed=yes; fi
assert_eq "install.sh does not install the utils library as a command" no "${utils_installed}"
assert_contains "install.sh adds completion to .bashrc" "$(cat "${IHOME}/.bashrc")" "source '${ROOT}/completion.sh'"
"${inst_env[@]}" bash "${ROOT}/install.sh" >/dev/null 2>&1
assert_eq "install.sh is idempotent for the completion line" 1 "$(grep -c "completion.sh" "${IHOME}/.bashrc")"
run "${OLD[@]}" PATH="${IHOME}/.local/bin:${STUBS}:/usr/bin:/bin" rport-tunnel dev1
assert_eq "installed rport-tunnel resolves and runs" "admin|old.example|20001" "$OUT"
run "${NEW[@]}" PATH="${IHOME}/.local/bin:${STUBS}:/usr/bin:/bin" procy-tunnel dev1
assert_eq "installed procy-tunnel resolves and runs" "admin|new.example|20001" "$OUT"
run "${NEW[@]}" PATH="${IHOME}/.local/bin:${STUBS}:/usr/bin:/bin" rport-ssh dev1 true
assert_contains "installed rport-ssh resolves and runs" "$SSH_LOG" "ssh://admin@new.example:20001 true"
"${inst_env[@]}" bash "${ROOT}/uninstall.sh" >"${WORK}/uninstall.out" 2>&1
assert_eq "uninstall.sh exits 0" 0 "$?"
left="$(find "${IHOME}/.local/bin" -mindepth 1 2>/dev/null)"
assert_eq "uninstall.sh removes both command sets" "" "$left"
assert_not_contains "uninstall.sh removes the completion line" "$(cat "${IHOME}/.bashrc")" "completion.sh"

# A profile written by an old rport-scripts install is cleaned up too.
printf '\n# rport-scripts shell completion\nsource %s\n' "'${ROOT}/completion.sh'" >"${IHOME}/.bashrc"
"${inst_env[@]}" bash "${ROOT}/uninstall.sh" >/dev/null 2>&1
assert_not_contains "uninstall.sh removes a legacy rport-scripts completion header" "$(cat "${IHOME}/.bashrc")" "rport-scripts"

echo
echo "passed: ${PASS}  failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
