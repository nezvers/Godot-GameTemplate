#!/bin/sh
# Starts a headless dedicated co-op server from the project folder.
#   tools/run_server.sh [--port N] [--max-players 2..8] [--save-dir PATH] [--name NAME] [--status SECONDS]
# GODOT points at the Godot binary (defaults to "godot" on the PATH).
cd "$(dirname "$0")/.." || exit 1
exec "${GODOT:-godot}" --headless --path . -- --server "$@"
