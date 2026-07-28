#!/bin/bash
set -euo pipefail

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_FILE="$PROJECT_DIR/project.godot"
REMOTE="origin"
RELEASE_BRANCH="main"

cd "$PROJECT_DIR"

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$RELEASE_BRANCH" ]]; then
    echo "Error: releases must be created from $RELEASE_BRANCH (currently on $current_branch)."
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: the working tree must be clean before creating a release."
    exit 1
fi

git fetch "$REMOTE" "$RELEASE_BRANCH" --tags
local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse "$REMOTE/$RELEASE_BRANCH")"
if [[ "$local_head" != "$remote_head" ]]; then
    echo "Error: local $RELEASE_BRANCH must exactly match $REMOTE/$RELEASE_BRANCH."
    exit 1
fi

current_version="$(sed -n 's/^config\\/version=\"\\(.*\\)\"/\\1/p' "$PROJECT_FILE")"

if [[ -z "$current_version" ]]; then
    echo "Error: could not find version in $PROJECT_FILE"
    exit 1
fi

if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version '$current_version' is not in major.minor.patch format"
    exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"
new_version="$major.$minor.$((patch + 1))"
new_tag="v$new_version"

if git rev-parse --verify --quiet "refs/tags/$new_tag" > /dev/null; then
    echo "Error: tag $new_tag already exists locally."
    exit 1
fi
if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$new_tag" > /dev/null 2>&1; then
    echo "Error: tag $new_tag already exists on $REMOTE."
    exit 1
fi

./test.sh source

echo "Bumping: $current_version -> $new_version"

sed -i "s/config\/version=\"$current_version\"/config\/version=\"$new_version\"/" "$PROJECT_FILE"

actual="$(sed -n 's/^config\\/version=\"\\(.*\\)\"/\\1/p' "$PROJECT_FILE")"
if [[ "$actual" != "$new_version" ]]; then
    echo "Error: version update failed (got '$actual')"
    exit 1
fi

git add "$PROJECT_FILE"
git commit -m "Bump patch version to $new_version"
git tag "$new_tag"
git push --atomic "$REMOTE" "$RELEASE_BRANCH" "$new_tag"

echo "Released v$new_version"
