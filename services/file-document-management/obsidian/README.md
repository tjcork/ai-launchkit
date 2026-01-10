# Obsidian LiveSync

Self-hosted synchronization server for [Obsidian](https://obsidian.md/) using CouchDB. This service enables you to sync your Obsidian notes across multiple devices without relying on Obsidian's paid sync service.

## Overview

This service deploys a CouchDB instance configured specifically for use with the [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync) Obsidian plugin. It provides:

- **Real-time sync** - Changes sync instantly across all connected devices
- **End-to-end encryption** - Optional E2E encryption for your notes
- **Self-hosted** - Full control over your data
- **Multi-vault support** - Create separate databases for each vault

## Quick Start

### 1. Enable and Start the Service

```bash
launchkit enable obsidian
launchkit up obsidian
```

### 2. Get Credentials

```bash
launchkit run obsidian report
```

Or check the generated `.env` file for:
- `OBSIDIAN_COUCHDB_USER` (default: `admin`)
- `OBSIDIAN_COUCHDB_PASSWORD` (auto-generated)

### 3. Configure Obsidian Plugin

1. Install the **Self-hosted LiveSync** plugin from Obsidian Community Plugins
2. Open the plugin settings
3. Configure the remote database:
   - **URI**: `https://obsidian.yourdomain.com` (or your configured hostname)
   - **Username**: Your CouchDB username
   - **Password**: Your CouchDB password
   - **Database name**: `obsidian` (or any name you prefer)
4. Click **Test** to verify the connection
5. Enable **Live Sync** for real-time synchronization

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OBSIDIAN_COUCHDB_USER` | CouchDB admin username | `admin` |
| `OBSIDIAN_COUCHDB_PASSWORD` | CouchDB admin password | Auto-generated |
| `OBSIDIAN_HOSTNAME` | Public hostname for the service | Set in `.env.global` |

### CouchDB Configuration

The CouchDB instance is pre-configured for Obsidian LiveSync with:

- CORS enabled for Obsidian desktop and mobile apps
- Single-node mode for simplicity
- Increased document size limits for large notes
- Authentication required for all operations

Custom configuration can be added to `config/local/couchdb.ini`.

## Security Considerations

### Enable E2E Encryption

For maximum security, enable end-to-end encryption in the LiveSync plugin:

1. Go to plugin settings > **Encryption**
2. Set a **passphrase** (store this securely - it cannot be recovered!)
3. Enable **End-to-End Encryption**

With E2E encryption, your notes are encrypted before leaving your device.

### Reverse Proxy Setup

Configure your reverse proxy (Caddy/Nginx) to handle HTTPS termination. Example Caddy configuration:

```
obsidian.yourdomain.com {
    reverse_proxy obsidian-couchdb:5984
}
```

## Data Persistence

All CouchDB data is stored in `./data/couchdb/`. This directory is automatically created by the `prepare.sh` script.

To backup your data:
```bash
# Stop the service first
launchkit down obsidian

# Backup the data directory
tar -czvf obsidian-backup.tar.gz ./data/couchdb/

# Restart the service
launchkit up obsidian
```

## Troubleshooting

### Connection Issues

1. Verify the service is running:
   ```bash
   launchkit ps | grep obsidian
   ```

2. Check the logs:
   ```bash
   launchkit logs obsidian
   ```

3. Test CouchDB directly:
   ```bash
   curl -u admin:password https://obsidian.yourdomain.com/_up
   ```

### Sync Not Working

1. In Obsidian, go to LiveSync settings
2. Click **Check database configuration**
3. If issues are found, click **Fix** to resolve them
4. Use **Rebuild everything** as a last resort

### Reset Database

To completely reset and start fresh:

```bash
launchkit down obsidian
rm -rf ./data/couchdb/*
launchkit up obsidian
```

Note: This will delete all synced data!

## Multiple Vaults

To sync multiple Obsidian vaults:

1. Use a **different database name** for each vault
2. In each vault's LiveSync settings, configure the same server but different database names:
   - Vault 1: `obsidian-personal`
   - Vault 2: `obsidian-work`
   - etc.

## Resources

- [Obsidian LiveSync Documentation](https://github.com/vrtmrz/obsidian-livesync/blob/main/README.md)
- [CouchDB Documentation](https://docs.couchdb.org/)
- [Obsidian Help](https://help.obsidian.md/)
