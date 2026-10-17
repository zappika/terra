#!/usr/bin/env bash
# Generates TERRA.xcodeproj from project.yml. Build number = commit count.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "error: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet
BUILD=$(git rev-list --count HEAD)
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" TERRA.xcodeproj/project.pbxproj
echo "generated TERRA.xcodeproj (build $BUILD)"
