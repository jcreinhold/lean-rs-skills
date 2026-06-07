#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$REPO_ROOT/plugins/lean-rs-skills"

rm -rf "$DEST"
mkdir -p "$DEST"

rsync -a "$REPO_ROOT/.codex-plugin/" "$DEST/.codex-plugin/"
rsync -a "$REPO_ROOT/skills/" "$DEST/skills/"
cp "$REPO_ROOT/README.md" "$DEST/README.md"
cp "$REPO_ROOT/LICENSE" "$DEST/LICENSE"

echo "Synced Codex adapter package at plugins/lean-rs-skills"
