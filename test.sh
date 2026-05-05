#!/bin/bash

set -euo pipefail

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

resolve_godot_bin() {
    local requested_bin="${GODOT_BIN:-}"
    local candidate

    if [[ -n "$requested_bin" ]]; then
        if command -v "$requested_bin" &> /dev/null; then
            printf '%s\n' "$requested_bin"
            return 0
        fi

        echo "Error: $requested_bin command not found. Please ensure Godot is installed and in your PATH."
        return 1
    fi

    for candidate in "${GODOT:-}" "${GODOT4:-}" godot godot4; do
        if [[ -n "$candidate" ]] && command -v "$candidate" &> /dev/null; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    echo "Error: Could not find a Godot executable. Tried GODOT_BIN, GODOT, GODOT4, godot, and godot4."
    return 1
}

if ! GODOT_BIN="$(resolve_godot_bin)"; then
    exit 1
fi

run_and_check_logs() {
    local log_file
    log_file="$(mktemp)"

    if ! "$@" >"$log_file" 2>&1; then
        cat "$log_file"
        rm -f "$log_file"
        return 1
    fi

    cat "$log_file"
    if grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|ERROR: Failed to load script' "$log_file"; then
        rm -f "$log_file"
        echo "Error: Godot reported a script load or compile failure."
        return 1
    fi

    rm -f "$log_file"
}

run_source_smoke() {
    "$GODOT_BIN" --headless --path "$PROJECT_DIR" --import --quit
    run_and_check_logs "$GODOT_BIN" --headless --path "$PROJECT_DIR" --scene "res://tests/smoke_test.tscn" --quit-after 300
}

run_linux_export_smoke() {
    if [[ ! -x "$PROJECT_DIR/out/linux64/snake.x86_64" ]]; then
        echo "Error: Linux export not found at out/linux64/snake.x86_64. Run ./build.sh linux first."
        return 1
    fi

    run_and_check_logs "$PROJECT_DIR/out/linux64/snake.x86_64" --headless --quit-after 1
}

show_usage() {
    echo "Usage: $0 [source|linux-export|all]"
    echo "source        Run the Godot headless smoke test against the project source"
    echo "linux-export  Run the Godot headless smoke test against the built Linux export"
    echo "all           Run the source smoke test, build the Linux export, then smoke-test it"
}

MODE="${1:-all}"

echo "Using Godot executable: $GODOT_BIN"

case "$MODE" in
    source)
        run_source_smoke
        ;;
    linux-export)
        run_linux_export_smoke
        ;;
    all)
        run_source_smoke
        "$PROJECT_DIR/build.sh" linux
        run_linux_export_smoke
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
