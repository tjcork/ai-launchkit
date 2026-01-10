#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../../lib/utils/logging.sh"

# Load environment
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

log_info "Checking Obsidian CouchDB health..."

# Check if the container is running
if ! docker ps --format '{{.Names}}' | grep -q "^obsidian-couchdb$"; then
    log_error "obsidian-couchdb container is not running"
    exit 1
fi

# Check CouchDB health via the container
MAX_RETRIES=30
RETRY_INTERVAL=2

for i in $(seq 1 $MAX_RETRIES); do
    if docker exec obsidian-couchdb curl -sf http://localhost:5984/_up > /dev/null 2>&1; then
        log_success "CouchDB is healthy and responding"
        exit 0
    fi
    log_info "Waiting for CouchDB to be ready... (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

log_error "CouchDB failed to become healthy after $MAX_RETRIES attempts"
exit 1
