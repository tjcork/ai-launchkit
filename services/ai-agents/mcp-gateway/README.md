# MCP Gateway (MCP Context Forge)

MCP Context Forge is a Model Context Protocol (MCP) Gateway & Registry that unifies REST APIs, MCP servers, and A2A (Agent-to-Agent) integrations into a single endpoint.

## Features

- **Protocol Translation**: Converts REST/gRPC services to MCP-compliant tools
- **Multi-Transport Support**: HTTP, JSON-RPC, WebSocket, SSE, stdio, streamable-HTTP
- **Virtual Servers**: Bundle tools and resources with custom authentication
- **OpenTelemetry Integration**: Distributed tracing with Phoenix, Jaeger, Zipkin support
- **Admin UI**: HTMX + Alpine.js dashboard for management and log viewing

## Quick Start

```bash
# Enable and start the service
launchkit enable mcp-gateway
launchkit up mcp-gateway

# View logs
launchkit logs mcp-gateway

# Access the UI
open http://localhost:4444/ui
```

## Configuration

Environment variables in `.env`:

| Variable | Description | Default |
|----------|-------------|---------|
| `MCPGATEWAY_PORT` | Gateway port | `4444` |
| `BASIC_AUTH_PASSWORD` | Basic auth password | Auto-generated |
| `JWT_SECRET_KEY` | JWT signing key | Auto-generated |
| `MCPGATEWAY_UI_ENABLED` | Enable admin UI | `true` |
| `MCPGATEWAY_ADMIN_API_ENABLED` | Enable admin API | `true` |
| `PLATFORM_ADMIN_EMAIL` | Admin email | `admin@localhost` |
| `PLATFORM_ADMIN_PASSWORD` | Admin password | Auto-generated |
| `OTEL_ENABLE_OBSERVABILITY` | Enable tracing | `false` |
| `DATABASE_URL` | Database connection | SQLite (default) |

## API Endpoints

- `/health` - Health check
- `/version` - Version information
- `/tools` - List available tools
- `/servers` - List MCP servers
- `/ui` - Admin dashboard (when enabled)
- `/servers/{UUID}/mcp` - MCP endpoints for registered servers

## Using with PostgreSQL

To use PostgreSQL instead of SQLite:

1. Ensure PostgreSQL service is running
2. Add dependency in `service.json`:
   ```json
   "depends_on": ["postgres"]
   ```
3. Configure in `.env`:
   ```
   DATABASE_URL='postgresql://user:pass@postgres:5432/mcpgateway'
   ```

## Resources

- [GitHub Repository](https://github.com/IBM/mcp-context-forge)
- [MCP Specification](https://modelcontextprotocol.io)
