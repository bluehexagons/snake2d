#!/bin/bash

set -euo pipefail

# Automated build script for Snake 2D Game
# Exports the game using predefined export presets

# Set the project directory to the current script's directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Building project in: $PROJECT_DIR"

source "$PROJECT_DIR/scripts/godot-common.sh"
GODOT_BIN="$(resolve_godot_bin)"
echo "Using Godot executable: $GODOT_BIN"

export_build() {
    local preset_name="$1"
    local output_path="$2"

    echo "Exporting ${preset_name} version..."
    mkdir -p "$(dirname "$output_path")"
    rm -f -- "$output_path"
    run_and_check_logs "" "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "$preset_name" "$output_path"

    if [[ ! -s "$output_path" ]]; then
        echo "Error: Expected export output was not created: $output_path"
        exit 1
    fi
}

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
        export_build "Web" "$PROJECT_DIR/out/html/index.html"
        ;;
    windows|Windows\ Desktop)
        export_build "Windows Desktop" "$PROJECT_DIR/out/win64/snake.exe"
        ;;
    linux|Linux)
        export_build "Linux" "$PROJECT_DIR/out/linux64/snake.x86_64"
        ;;
    all)
        echo "Exporting all platforms..."
        export_build "Web" "$PROJECT_DIR/out/html/index.html"
        export_build "Windows Desktop" "$PROJECT_DIR/out/win64/snake.exe"
        export_build "Linux" "$PROJECT_DIR/out/linux64/snake.x86_64"
        ;;
    *)
        echo "Error: Unknown platform '$PLATFORM'"
        show_usage
        exit 1
        ;;
esac

echo "Build process completed!"
