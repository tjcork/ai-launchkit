#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Load environment to get port
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

PORT="${MCPGATEWAY_PORT:-4444}"
MAX_RETRIES=30
RETRY_INTERVAL=2

echo "[mcp-gateway] Checking health at http://localhost:$PORT/health..."

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "http://localhost:$PORT/health" > /dev/null 2>&1; then
        echo "[mcp-gateway] Service is healthy!"
        exit 0
    fi
    echo "[mcp-gateway] Waiting for service... ($i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

echo "[mcp-gateway] Health check failed after $MAX_RETRIES attempts"
exit 1
