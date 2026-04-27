#!/bin/bash

# Automated build script for Snake 2D Game
# Exports the game using predefined export presets

# Set the project directory to the current script's directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Building project in: $PROJECT_DIR"

# Resolve the Godot executable from explicit configuration first, then common CI defaults.
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

echo "Using Godot executable: $GODOT_BIN"

# Function to show usage
show_usage() {
    echo "Usage: $0 [platform]"
    echo "Platforms: all, web, windows, linux"
    echo "If no platform is specified, builds all platforms"
}

# Determine which platforms to build
PLATFORM=${1:-all}

case "$PLATFORM" in
    web|Web)
        echo "Exporting Web version..."
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$PROJECT_DIR/out/html/index.html"
        ;;
    windows|Windows\ Desktop)
        echo "Exporting Windows Desktop version..."
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Windows Desktop" "$PROJECT_DIR/out/win64/snake.exe"
        ;;
    linux|Linux)
        echo "Exporting Linux version..."
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Linux" "$PROJECT_DIR/out/linux64/snake.x86_64"
        ;;
    all)
        echo "Exporting all platforms..."
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$PROJECT_DIR/out/html/index.html"
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Windows Desktop" "$PROJECT_DIR/out/win64/snake.exe"
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Linux" "$PROJECT_DIR/out/linux64/snake.x86_64"
        ;;
    *)
        echo "Error: Unknown platform '$PLATFORM'"
        show_usage
        exit 1
        ;;
esac

echo "Build process completed!"
