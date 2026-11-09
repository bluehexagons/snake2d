#!/bin/bash
# Shared native Bash runner; no Basaltwater runtime dependency.
resolve_godot_bin() {
    local candidate
    if [[ -n "${GODOT_BIN:-}" ]]; then
        command -v "$GODOT_BIN" || {
            echo "Error: Explicit GODOT_BIN command not found: $GODOT_BIN" >&2
            return 1
        }
        return
    fi
    for candidate in "${GODOT:-}" "${GODOT4:-}" "${BASALTWATER_GODOT_EXE:-}" godot godot4; do
        if [[ -n "$candidate" ]] && command -v "$candidate" >/dev/null; then
            command -v "$candidate"
            return
        fi
    done
    echo "Error: Godot not found. Set GODOT_BIN to the documented engine." >&2
    return 1
}

# A subshell scopes cleanup to this invocation, including early exits/signals.
run_and_check_logs() (
    local expected_marker="$1"
    shift
    local seconds="${GODOT_TIMEOUT_SECONDS:-120}" log_file status=0
    if [[ ! "$seconds" =~ ^[1-9][0-9]{0,3}$ ]] || (( seconds > 3600 )); then
        echo "Error: GODOT_TIMEOUT_SECONDS must be an integer from 1 to 3600." >&2
        return 1
    fi
    if ! command -v timeout >/dev/null; then
        echo "Error: GNU timeout (coreutils) is required by the Bash runner." >&2
        return 1
    fi
    log_file="$(mktemp)" || return 1
    trap 'rm -f -- "$log_file"' EXIT
    timeout --kill-after=5s "${seconds}s" "$@" >"$log_file" 2>&1 || status=$?
    cat "$log_file"
    if (( status != 0 )); then
        echo "Error: Godot command failed (exit $status; deadline $seconds seconds)." >&2
        return "$status"
    fi
    if grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|(^|[[:space:]])ERROR:' "$log_file"; then
        echo "Error: Godot reported an error." >&2
        return 1
    fi
    if [[ -n "$expected_marker" ]] && ! grep -Fxq "$expected_marker" "$log_file"; then
        echo "Error: Godot exited before reporting: $expected_marker" >&2
        return 1
    fi
)
