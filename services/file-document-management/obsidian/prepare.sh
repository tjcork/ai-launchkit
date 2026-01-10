#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Preparing Obsidian LiveSync (CouchDB) service..."

# Ensure data directories exist
mkdir -p "$SCRIPT_DIR/data/couchdb"
mkdir -p "$SCRIPT_DIR/config/local"

# Create CouchDB configuration for Obsidian LiveSync
# This configuration enables CORS and sets up the database for LiveSync compatibility
cat > "$SCRIPT_DIR/config/local/couchdb.ini" << 'EOF'
[couchdb]
single_node=true
max_document_size = 50000000

[chttpd]
require_valid_user = true
max_http_request_size = 4294967296
enable_cors = true

[chttpd_auth]
require_valid_user = true
authentication_redirect = /_utils/session.html

[httpd]
WWW-Authenticate = Basic realm="couchdb"
bind_address = 0.0.0.0
enable_cors = true

[cors]
origins = app://obsidian.md, capacitor://localhost, http://localhost
credentials = true
headers = accept, authorization, content-type, origin, referer
methods = GET, PUT, POST, HEAD, DELETE
max_age = 3600
EOF

echo "CouchDB configuration generated at config/local/couchdb.ini"
echo "Obsidian LiveSync preparation complete!"
