#!/bin/bash
set -euo pipefail

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_FILE="$PROJECT_DIR/project.godot"

current_version=$(grep '^config/version=' "$PROJECT_FILE" | sed 's/config\/version="\(.*\)"/\1/')

if [[ -z "$current_version" ]]; then
    echo "Error: could not find version in $PROJECT_FILE"
    exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"
if [[ -z "${major:-}" || -z "${minor:-}" || -z "${patch:-}" ]]; then
    echo "Error: version '$current_version' is not in major.minor.patch format"
    exit 1
fi

new_version="$major.$minor.$((patch + 1))"
echo "Bumping: $current_version -> $new_version"

sed -i "s/config\/version=\"$current_version\"/config\/version=\"$new_version\"/" "$PROJECT_FILE"

actual=$(grep '^config/version=' "$PROJECT_FILE" | sed 's/config\/version="\(.*\)"/\1/')
if [[ "$actual" != "$new_version" ]]; then
    echo "Error: version update failed (got '$actual')"
    exit 1
fi

git -C "$PROJECT_DIR" add "$PROJECT_FILE"
git -C "$PROJECT_DIR" commit -m "Bump patch version to $new_version"
git -C "$PROJECT_DIR" tag "v$new_version"
git -C "$PROJECT_DIR" push
git -C "$PROJECT_DIR" push --tags

echo "Released v$new_version"
