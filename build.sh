#!/bin/bash

# Automated build script for Snake 2D Game
# Exports the game using predefined export presets

# Set the project directory to the current script's directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Building project in: $PROJECT_DIR"

# Check if godot command is available
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" &> /dev/null; then
    echo "Error: $GODOT_BIN command not found. Please ensure Godot is installed and in your PATH."
    exit 1
fi

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
