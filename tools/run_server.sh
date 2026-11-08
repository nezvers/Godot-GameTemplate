#!/bin/sh
# Starts a headless dedicated co-op server from the project folder.
#   tools/run_server.sh [--port N] [--max-players 2..8] [--save-dir PATH] [--name NAME] [--status SECONDS]
# Godot binary: $GODOT, else `godot` on the PATH, else a Godot_v*_linux.x86_64
# next to the project folder. Stop the server with Ctrl+C.
cd "$(dirname "$0")/.." || exit 1
if [ -z "$GODOT" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT=godot
	else
		GODOT=$(ls ../Godot_v*_linux.x86_64 2>/dev/null | tail -n 1)
	fi
fi
if [ -z "$GODOT" ]; then
	echo "run_server.sh: no Godot binary found; set GODOT=/path/to/Godot" >&2
	exit 1
fi
# a fresh checkout has no import cache yet
if [ ! -d .godot/imported ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
fi
exec "$GODOT" --headless --path . -- --server "$@"
