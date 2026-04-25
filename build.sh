#!/bin/bash

# Automated build script for Snake 2D Game
# Exports the game using predefined export presets

# Set the project directory to the current script's directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Building project in: $PROJECT_DIR"

# Check if godot command is available
if ! command -v godot &> /dev/null; then
    echo "Error: godot command not found. Please ensure Godot is installed and in your PATH."
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
        godot --path "$PROJECT_DIR" --export-preset "Web"
        ;;
    windows|Windows\ Desktop)
        echo "Exporting Windows Desktop version..."
        godot --path "$PROJECT_DIR" --export-preset "Windows Desktop"
        ;;
    linux|Linux)
        echo "Exporting Linux version..."
        godot --path "$PROJECT_DIR" --export-preset "Linux"
        ;;
    all)
        echo "Exporting all platforms..."
        godot --path "$PROJECT_DIR" --export-preset "Web"
        godot --path "$PROJECT_DIR" --export-preset "Windows Desktop"
        godot --path "$PROJECT_DIR" --export-preset "Linux"
        ;;
    *)
        echo "Error: Unknown platform '$PLATFORM'"
        show_usage
        exit 1
        ;;
esac

echo "Build process completed!"