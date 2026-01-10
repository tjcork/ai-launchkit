#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Create data directory for SQLite database persistence
mkdir -p "$SCRIPT_DIR/data"

# Set appropriate permissions (container runs as non-root typically)
chmod 755 "$SCRIPT_DIR/data"

echo "[mcp-gateway] Data directory prepared."
