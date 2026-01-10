#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../../lib/utils/logging.sh"

# Load environment
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

log_info "Running Obsidian CouchDB startup tasks..."

# Wait for CouchDB to be ready
MAX_RETRIES=30
RETRY_INTERVAL=2

log_info "Waiting for CouchDB to be ready..."
for i in $(seq 1 $MAX_RETRIES); do
    if docker exec obsidian-couchdb curl -sf http://localhost:5984/_up > /dev/null 2>&1; then
        log_success "CouchDB is ready"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        log_error "CouchDB failed to start"
        exit 1
    fi
    sleep $RETRY_INTERVAL
done

# Create the _users and _replicator system databases if they don't exist
log_info "Ensuring system databases exist..."

COUCHDB_URL="http://${OBSIDIAN_COUCHDB_USER}:${OBSIDIAN_COUCHDB_PASSWORD}@localhost:5984"

for db in _users _replicator _global_changes; do
    docker exec obsidian-couchdb curl -sf -X PUT "${COUCHDB_URL}/${db}" > /dev/null 2>&1 || true
done

log_success "Obsidian CouchDB startup complete!"
