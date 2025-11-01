#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

source "$SCRIPT_DIR/utils.sh"
resolve_env_context "$PROJECT_ROOT"
ENV_FILE="$LAUNCHKIT_ENV_FILE"

# Check if Google credentials are in env file
GOOGLE_CLIENT_ID=$(grep "^GOOGLE_CLIENT_ID=" "$ENV_FILE" | cut -d '=' -f2 | tr -d '"')
GOOGLE_CLIENT_SECRET=$(grep "^GOOGLE_CLIENT_SECRET=" "$ENV_FILE" | cut -d '=' -f2 | tr -d '"')
DOMAIN=$(grep "^USER_DOMAIN_NAME=" "$ENV_FILE" | cut -d '=' -f2 | tr -d '"')

if [[ -n "$GOOGLE_CLIENT_ID" && -n "$GOOGLE_CLIENT_SECRET" ]]; then
    echo "Setting up Google Calendar integration in Cal.com database..."
    
    # Wait for Cal.com to be ready
    sleep 10
    
    # Insert Google Calendar app into database
    docker exec postgres psql -U postgres -d calcom -c "
    INSERT INTO \"App\" (slug, keys, enabled, \"dirName\", \"createdAt\", \"updatedAt\")
    VALUES (
        'google-calendar',
        '{\"client_id\":\"${GOOGLE_CLIENT_ID}\",\"client_secret\":\"${GOOGLE_CLIENT_SECRET}\",\"redirect_uris\":[\"https://cal.${DOMAIN}/api/integrations/googlecalendar/callback\",\"https://cal.${DOMAIN}/api/auth/callback/google\"]}',
        true,
        'googlecalendar',
        NOW(),
        NOW()
    )
    ON CONFLICT (slug) DO UPDATE 
    SET keys = EXCLUDED.keys, 
        enabled = true,
        \"updatedAt\" = NOW();"
    
    echo "Google Calendar integration configured!"
else
    echo "No Google credentials found in .env - skipping"
fi
