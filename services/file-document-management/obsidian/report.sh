#!/bin/bash
# Report for obsidian

echo
echo "================================= Obsidian LiveSync ========================"
echo
echo "CouchDB Sync Server for Obsidian"
echo
echo "Access:"
echo "  CouchDB URL: https://${OBSIDIAN_HOSTNAME:-<hostname_not_set>}"
echo "  CouchDB Admin UI: https://${OBSIDIAN_HOSTNAME:-<hostname_not_set>}/_utils"
echo
echo "Credentials:"
echo "  Username: ${OBSIDIAN_COUCHDB_USER:-admin}"
echo "  Password: ${OBSIDIAN_COUCHDB_PASSWORD:-<not_set>}"
echo
echo "Obsidian LiveSync Plugin Setup:"
echo "  1. Install 'Self-hosted LiveSync' plugin in Obsidian"
echo "  2. Open plugin settings"
echo "  3. Configure Remote Database:"
echo "     - URI: https://${OBSIDIAN_HOSTNAME:-<hostname_not_set>}"
echo "     - Username: ${OBSIDIAN_COUCHDB_USER:-admin}"
echo "     - Password: ${OBSIDIAN_COUCHDB_PASSWORD:-<password>}"
echo "     - Database name: obsidian (or your preferred name)"
echo "  4. Click 'Test' to verify connection"
echo "  5. Enable 'Live Sync' for real-time synchronization"
echo
echo "Tips:"
echo "  - Create a dedicated database for each vault"
echo "  - Enable E2E encryption in plugin settings for security"
echo "  - Use 'Rebuild everything' if sync issues occur"
echo
echo "Documentation: https://github.com/vrtmrz/obsidian-livesync"
echo
