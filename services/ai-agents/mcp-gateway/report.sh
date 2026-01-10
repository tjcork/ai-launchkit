#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Load environment
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

PORT="${MCPGATEWAY_PORT:-4444}"
ADMIN_EMAIL="${PLATFORM_ADMIN_EMAIL:-admin@localhost}"

echo ""
echo "=========================================="
echo "  MCP Gateway (Context Forge)"
echo "=========================================="
echo ""
echo "  Gateway URL:  http://localhost:$PORT"
echo "  Admin UI:     http://localhost:$PORT/ui"
echo "  Health:       http://localhost:$PORT/health"
echo ""
echo "  Admin Login:"
echo "    Email:    $ADMIN_EMAIL"
echo "    Password: (see .env file)"
echo ""
echo "  API Endpoints:"
echo "    /tools    - List available tools"
echo "    /servers  - List MCP servers"
echo "    /version  - Gateway version"
echo ""
echo "=========================================="
