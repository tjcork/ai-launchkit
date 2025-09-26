#!/bin/bash

# Script to guide user through service selection for n8n-installer

# Source utility functions, if any, assuming it's in the same directory
# and .env is in the parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# UTILS_SCRIPT="$SCRIPT_DIR/utils.sh" # Uncomment if utils.sh contains relevant functions

# if [ -f "$UTILS_SCRIPT" ]; then
#     source "$UTILS_SCRIPT"
# fi

# Function to check if whiptail is installed
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        log_error "'whiptail' is not installed."
        log_info "This tool is required for the interactive service selection."
        log_info "On Debian/Ubuntu, you can install it using: sudo apt-get install whiptail"
        log_info "Please install whiptail and try again."
        exit 1
    fi
}

# Call the check
check_whiptail

# Store original DEBIAN_FRONTEND and set to dialog for whiptail
ORIGINAL_DEBIAN_FRONTEND="$DEBIAN_FRONTEND"
export DEBIAN_FRONTEND=dialog

# --- Read current COMPOSE_PROFILES from .env ---
CURRENT_PROFILES_VALUE=""
if [ -f "$ENV_FILE" ]; then
    LINE_CONTENT=$(grep "^COMPOSE_PROFILES=" "$ENV_FILE" || echo "")
    if [ -n "$LINE_CONTENT" ]; then
        # Get value after '=', remove potential surrounding quotes
        CURRENT_PROFILES_VALUE=$(echo "$LINE_CONTENT" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
    fi
fi
# Prepare comma-separated current profiles for easy matching, adding leading/trailing commas
current_profiles_for_matching=",$CURRENT_PROFILES_VALUE,"

# --- Define available services and their descriptions ---
# Base service definitions (tag, description)
base_services_data=(
    "n8n" "n8n, n8n-worker, n8n-import (Workflow Automation)"
    "dify" "Dify (AI Application Development Platform with LLMOps)"
    "flowise" "Flowise (AI Agent Builder)"
    "bolt" "bolt.diy (AI Web Development)"
    "openui" "OpenUI (AI Frontend/UI Generator - EXPERIMENTAL, best with Claude/GPT-4)"
    "monitoring" "Monitoring Suite (Prometheus, Grafana, cAdvisor, Node-Exporter)"
    "portainer" "Portainer (Docker management UI)"
    "cloudflare-tunnel" "Cloudflare Tunnel (Zero-Trust Secure Access for Web Services)"
    "cloudflare-ssh-tunnel" "Cloudflare SSH Tunnel (Secure SSH via Cloudflare tunnel)"
    "postiz" "Postiz (Social publishing platform)"
    "odoo" "Odoo 18 (Open Source ERP/CRM with AI features)"
    "twenty-crm" "Twenty CRM (Modern Notion-like customer management)"
    "espocrm" "EspoCRM (Full-featured CRM with workflows & automation)"
    "mautic" "Mautic 6.0 - Marketing Automation Platform (Email, Leads, Campaigns)"
    "baserow" "Baserow (Airtable Alternative)"
    "nocodb" "NocoDB (Open-source Airtable alternative, smart spreadsheet UI)"
    "vikunja" "Vikunja (Modern Task Management - Todoist/TickTick alternative)"
    "leantime" "Leantime - Full project management suite (Asana/Monday alternative)"
    "calcom" "Cal.com (Open Source Scheduling Platform)"
    "kimai" "Kimai (Professional Time Tracking - DSGVO-compliant, 2FA, invoicing)"
    "invoiceninja" "Invoice Ninja - Professional invoicing platform"
    "formbricks" "Formbricks - Privacy-first surveys & forms (Typeform alternative)"
    "metabase" "Metabase - Business intelligence (No-code dashboards, groups, ETL-ready)"
    "jitsi" "Jitsi Meet (Video conferencing - REQUIRES UDP 10000!)"
    "vaultwarden" "Vaultwarden (Self-hosted Bitwarden-compatible password manager)"
    "kopia" "Kopia (Fast and secure backup with Cloud and WebDAV storage)"
    "mailserver" "Docker-Mailserver (Production email server for all services)"
    "snappymail" "SnappyMail (Modern webmail client for Docker-Mailserver)"
    "langfuse" "Langfuse Suite (AI Observability - includes Clickhouse, Minio)"
    "qdrant" "Qdrant (Vector Database)"
    "supabase" "Supabase (Backend as a Service)"
    "weaviate" "Weaviate (Vector Database with API Key Auth)"
    "lightrag" "LightRAG (Graph-based RAG with entity extraction)"
    "neo4j" "Neo4j (Graph Database)"
    "letta" "Letta (Agent Server & SDK)"
    "gotenberg" "Gotenberg (Document Conversion API)"
    "stirling-pdf" "Stirling-PDF (100+ PDF Tools: Merge, Split, OCR, Sign)"
    "crawl4ai" "Crawl4ai (Web Crawler for AI)"
    "ragapp" "RAGApp (Open-source RAG UI + API)"
    "open-webui" "Open WebUI (ChatGPT-like Interface)"
    "searxng" "SearXNG (Private Metasearch Engine)"
    "perplexica" "Perplexica (Open-source Deep Resarch/Perplexity AI alternative)"
    "python-runner" "Python Runner (Run your custom Python code from ./python-runner)"
    "ollama" "Ollama (Local LLM Runner - select hardware in next step)"
    "comfyui" "ComfyUI (Node-based Stable Diffusion UI)"
    "speech" "Speech Stack (Whisper ASR + OpenedAI TTS - CPU optimized)"
    "scriberr" "Scriberr (AI audio transcription with speaker diarization)"
    "ocr" "OCR Bundle (Tesseract + EasyOCR - Extract text from images/PDFs)"
    "libretranslate" "LibreTranslate (Self-hosted translation API - 50+ languages)"
)

services=() # This will be the final array for whiptail

# Populate the services array for whiptail based on current profiles or defaults
idx=0
while [ $idx -lt ${#base_services_data[@]} ]; do
    tag="${base_services_data[idx]}"
    description="${base_services_data[idx+1]}"
    status="OFF" # Default to OFF

    if [ -n "$CURRENT_PROFILES_VALUE" ] && [ "$CURRENT_PROFILES_VALUE" != '""' ]; then # Check if .env has profiles
        if [[ "$tag" == "ollama" ]]; then
            if [[ "$current_profiles_for_matching" == *",cpu,"* || \
                  "$current_profiles_for_matching" == *",gpu-nvidia,"* || \
                  "$current_profiles_for_matching" == *",gpu-amd,"* ]]; then
                status="ON"
            fi
        elif [[ "$current_profiles_for_matching" == *",$tag,"* ]]; then
            status="ON"
        fi
    else
        # .env has no COMPOSE_PROFILES or it's empty/just quotes, use hardcoded defaults
        case "$tag" in
            "n8n"|"flowise"|"monitoring") status="ON" ;;
            *) status="OFF" ;;
        esac
    fi
    services+=("$tag" "$description" "$status")
    idx=$((idx + 2))
done

# Calculate dynamic height based on number of services
num_services=$(( ${#services[@]} / 3 ))

# Calculate dynamic dimensions
list_height=$num_services
if [ $list_height -gt 20 ]; then
    list_height=20  # Max visible items with scrolling
fi
window_height=$(( list_height + 8 ))  # Add space for title and buttons

# Use whiptail to display the checklist
CHOICES=$(whiptail --title "Service Selection Wizard" --checklist \
  "Choose the services you want to deploy.\nUse ARROW KEYS to navigate, SPACEBAR to select/deselect, ENTER to confirm.\n↑↓ Scroll with arrow keys to see all services" $window_height 110 $list_height \
  "${services[@]}" \
  3>&1 1>&2 2>&3)

# Restore original DEBIAN_FRONTEND
if [ -n "$ORIGINAL_DEBIAN_FRONTEND" ]; then
  export DEBIAN_FRONTEND="$ORIGINAL_DEBIAN_FRONTEND"
else
  unset DEBIAN_FRONTEND
fi

# Exit if user pressed Cancel or Esc
exitstatus=$?
if [ $exitstatus -ne 0 ]; then
    log_info "Service selection cancelled by user. Exiting wizard."
    log_info "No changes made to service profiles. Default services will be used."
    # Set COMPOSE_PROFILES to empty to ensure only core services run
    if [ ! -f "$ENV_FILE" ]; then
        touch "$ENV_FILE"
    fi
    if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
        sed -i.bak "/^COMPOSE_PROFILES=/d" "$ENV_FILE"
    fi
    echo "COMPOSE_PROFILES=" >> "$ENV_FILE"
    exit 0
fi

# Process selected services
selected_profiles=()
ollama_selected=0
ollama_profile=""

if [ -n "$CHOICES" ]; then
    # Whiptail returns a string like "tag1" "tag2" "tag3"
    # We need to remove quotes and convert to an array
    temp_choices=()
    eval "temp_choices=($CHOICES)"

    for choice in "${temp_choices[@]}"; do
        if [ "$choice" == "ollama" ]; then
            ollama_selected=1
        else
            selected_profiles+=("$choice")
        fi
    done
fi

# If Ollama was selected, prompt for the hardware profile
if [ $ollama_selected -eq 1 ]; then
    # Determine default selected Ollama hardware profile from .env
    default_ollama_hardware="cpu" # Fallback default
    ollama_hw_on_cpu="OFF"
    ollama_hw_on_gpu_nvidia="OFF"
    ollama_hw_on_gpu_amd="OFF"

    # Check current_profiles_for_matching which includes commas, e.g., ",cpu,"
    if [[ "$current_profiles_for_matching" == *",cpu,"* ]]; then
        ollama_hw_on_cpu="ON"
        default_ollama_hardware="cpu"
    elif [[ "$current_profiles_for_matching" == *",gpu-nvidia,"* ]]; then
        ollama_hw_on_gpu_nvidia="ON"
        default_ollama_hardware="gpu-nvidia"
    elif [[ "$current_profiles_for_matching" == *",gpu-amd,"* ]]; then
        ollama_hw_on_gpu_amd="ON"
        default_ollama_hardware="gpu-amd"
    else
        # If ollama was selected in the main list, but no specific hardware profile was previously set,
        # default to CPU ON for the radiolist.
        ollama_hw_on_cpu="ON"
        default_ollama_hardware="cpu"
    fi

    ollama_hardware_options=(
        "cpu" "CPU (Recommended for most users)" "$ollama_hw_on_cpu"
        "gpu-nvidia" "NVIDIA GPU (Requires NVIDIA drivers & CUDA)" "$ollama_hw_on_gpu_nvidia"
        "gpu-amd" "AMD GPU (Requires ROCm drivers)" "$ollama_hw_on_gpu_amd"
    )
    CHOSEN_OLLAMA_PROFILE=$(whiptail --title "Ollama Hardware Profile" --default-item "$default_ollama_hardware" --radiolist \
      "Choose the hardware profile for Ollama. This will be added to your Docker Compose profiles." 15 78 3 \
      "${ollama_hardware_options[@]}" \
      3>&1 1>&2 2>&3)

    ollama_exitstatus=$?
    if [ $ollama_exitstatus -eq 0 ] && [ -n "$CHOSEN_OLLAMA_PROFILE" ]; then
        selected_profiles+=("$CHOSEN_OLLAMA_PROFILE")
        ollama_profile="$CHOSEN_OLLAMA_PROFILE" # Store for user message
        log_info "Ollama hardware profile selected: $CHOSEN_OLLAMA_PROFILE"
    else
        log_info "Ollama hardware profile selection cancelled or no choice made. Ollama will not be configured with a specific hardware profile."
        # ollama_selected remains 1, but no specific profile is added.
        # This means "ollama" won't be in COMPOSE_PROFILES unless a hardware profile is chosen.
        ollama_selected=0 # Mark as not fully selected if profile choice is cancelled
    fi
fi

# Auto-enable MySQL when Leantime is selected
if [[ " ${selected_profiles[@]} " =~ " leantime " ]]; then
    if [[ ! " ${selected_profiles[@]} " =~ " mysql " ]]; then
        selected_profiles+=("mysql")
        echo
        log_info "📦 MySQL 8.4 will be installed automatically for Leantime"
        log_info "   You can use this MySQL instance for other services too (WordPress, Ghost, etc.)"
        sleep 2
    fi
fi

if [ ${#selected_profiles[@]} -eq 0 ]; then
    log_info "No optional services selected."
    COMPOSE_PROFILES_VALUE=""
else
    log_info "You have selected the following service profiles to be deployed:"
    # Join the array into a comma-separated string
    COMPOSE_PROFILES_VALUE=$(IFS=,; echo "${selected_profiles[*]}")
    for profile in "${selected_profiles[@]}"; do
        # Check if the current profile is an Ollama hardware profile that was chosen
        if [[ "$profile" == "cpu" || "$profile" == "gpu-nvidia" || "$profile" == "gpu-amd" ]]; then
            if [ "$profile" == "$ollama_profile" ]; then # ollama_profile stores the CHOSEN_OLLAMA_PROFILE from this wizard run
                 echo "  - Ollama ($profile profile)"
            else # This handles a (highly unlikely) non-Ollama service named "cpu", "gpu-nvidia", or "gpu-amd"
                 echo "  - $profile"
            fi
        else
            echo "  - $profile"
        fi
    done
fi

# Update or add COMPOSE_PROFILES in .env file
# Ensure .env file exists (it should have been created by 03_generate_secrets.sh or exist from previous run)
if [ ! -f "$ENV_FILE" ]; then
    log_warning "'.env' file not found at $ENV_FILE. Creating it."
    touch "$ENV_FILE"
fi

# Configure Cloudflare Web Services Tunnel if selected
cloudflare_tunnel_selected=0
cloudflare_ssh_selected=0

for profile in "${selected_profiles[@]}"; do
    if [ "$profile" == "cloudflare-tunnel" ]; then
        cloudflare_tunnel_selected=1
    elif [ "$profile" == "cloudflare-ssh-tunnel" ]; then
        cloudflare_ssh_selected=1
    fi
done

# Handle Cloudflare Web Services Tunnel configuration
if [ $cloudflare_tunnel_selected -eq 1 ]; then
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "🌐 CLOUDFLARE WEB SERVICES TUNNEL CONFIGURATION"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Configuring secure access to your web services (n8n, flowise, etc.)"
    echo "through Cloudflare's zero-trust network."
    echo ""
    
    # Check for existing web tunnel token
    existing_web_token=""
    if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE"; then
        existing_web_token=$(grep "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^\"//' | sed 's/\"$//')
    fi

    if [ -n "$existing_web_token" ]; then
        log_info "✅ Web Services Tunnel token found in .env; reusing it."
    else
        echo ""
        echo "Please provide your Cloudflare Web Services Tunnel token."
        echo "Get this from: Cloudflare Zero Trust Dashboard > Network > Tunnels"
        echo ""
        read -p "Cloudflare Web Services Tunnel Token: " input_web_token
        
        # Update the .env with the web token
        if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE"; then
            sed -i.bak "/^CLOUDFLARE_TUNNEL_TOKEN=/d" "$ENV_FILE"
        fi
        echo "CLOUDFLARE_TUNNEL_TOKEN=\"$input_web_token\"" >> "$ENV_FILE"
        
        if [ -n "$input_web_token" ]; then
            log_success "Web Services Tunnel token saved to .env."
            echo ""
            echo "🔒 After confirming web services work through tunnel,"
            echo "   consider closing ports 80 and 443 in your firewall."
        else
            log_warning "Web Services Tunnel token was left empty. You can set it later in .env."
        fi
    fi
fi

# Handle Cloudflare SSH Tunnel configuration (independent service)
if [ $cloudflare_ssh_selected -eq 1 ]; then
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "🔐 CLOUDFLARE SSH TUNNEL CONFIGURATION"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "SSH tunnel provides secure access to your server without exposing port 22:"
    echo "• Secure SSH access without exposing port 22"
    echo "• Protection against SSH brute force attacks"
    echo "• Access SSH from anywhere through Cloudflare"
    echo "• Uses host networking for direct SSH access"
    echo ""
    echo "After setup, you can close port 22 in your firewall (with caution!)"
    echo ""
    
    # Ensure ssh-tunnel directory exists
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
    SSH_TUNNEL_DIR="$PROJECT_ROOT/ssh-tunnel"
    SSH_TUNNEL_ENV="$SSH_TUNNEL_DIR/.env"
    
    mkdir -p "$SSH_TUNNEL_DIR"
    
    # Set SSH enabled flag in main env
    if grep -q "^CLOUDFLARE_SSH_ENABLED=" "$ENV_FILE"; then
        sed -i.bak "/^CLOUDFLARE_SSH_ENABLED=/d" "$ENV_FILE"
    fi
    echo "CLOUDFLARE_SSH_ENABLED=true" >> "$ENV_FILE"
    
    # Configure SSH tunnel token in ssh-tunnel/.env
    existing_ssh_token=""
    if [ -f "$SSH_TUNNEL_ENV" ] && grep -q "^CLOUDFLARE_SSH_TUNNEL_TOKEN=" "$SSH_TUNNEL_ENV"; then
        existing_ssh_token=$(grep "^CLOUDFLARE_SSH_TUNNEL_TOKEN=" "$SSH_TUNNEL_ENV" | cut -d'=' -f2- | sed 's/^\"//' | sed 's/\"$//')
    fi
    
    if [ -n "$existing_ssh_token" ]; then
        log_info "✅ SSH Tunnel token found in ssh-tunnel/.env; reusing it."
    else
        # SSH tunnel always uses separate tunnel (architectural decision)
        echo ""
        log_info "🔐 SSH TUNNEL CONFIGURATION"
        echo "SSH tunnel requires a separate tunnel from web services for security isolation."
        echo "Create a dedicated tunnel in Cloudflare for SSH access."
        echo ""
        read -p "Enter your SSH Tunnel Token: " input_ssh_token
        
        # Write token to ssh-tunnel/.env (create or update)
        if [ -f "$SSH_TUNNEL_ENV" ] && grep -q "^CLOUDFLARE_SSH_TUNNEL_TOKEN=" "$SSH_TUNNEL_ENV"; then
            # Update existing token
            sed -i.bak "/^CLOUDFLARE_SSH_TUNNEL_TOKEN=/d" "$SSH_TUNNEL_ENV"
        fi
        
        # Create or append to ssh-tunnel/.env
        echo "CLOUDFLARE_SSH_TUNNEL_TOKEN=\"$input_ssh_token\"" >> "$SSH_TUNNEL_ENV"
        
        if [ -n "$input_ssh_token" ]; then
            log_success "✅ SSH Tunnel configured with separate tunnel for enhanced security!"
            log_info "Token saved to ssh-tunnel/.env"
        else
            log_warning "SSH Tunnel token was left empty. You can set it later in ssh-tunnel/.env."
        fi
    fi
    
    echo ""
    log_success "🔐 SSH Tunnel configured successfully!"
    echo ""
    echo "📋 NEXT STEPS FOR SSH TUNNEL:"
    echo "1. In Cloudflare Zero Trust Dashboard, add TCP service:"
    echo "   • Service Type: TCP"
    echo "   • Public hostname: ssh.yourdomain.com (configure your own)"
    echo "   • Service URL: tcp://localhost:22"
    echo ""
    echo "2. After testing SSH access, you can safely run:"
    echo "   sudo ufw delete allow 22/tcp"
    echo "   sudo ufw reload"
    echo ""
else
    # SSH tunnel not selected - ensure it's disabled
    if grep -q "^CLOUDFLARE_SSH_ENABLED=" "$ENV_FILE"; then
        sed -i.bak "/^CLOUDFLARE_SSH_ENABLED=/d" "$ENV_FILE"
    fi
    echo "CLOUDFLARE_SSH_ENABLED=false" >> "$ENV_FILE"
fi

# Final security message if any Cloudflare tunnel is configured
if [ $cloudflare_tunnel_selected -eq 1 ] || [ $cloudflare_ssh_selected -eq 1 ]; then
    echo ""
    echo "🔒 SECURITY RECOMMENDATIONS:"
    if [ $cloudflare_tunnel_selected -eq 1 ]; then
        echo "Web Services Tunnel - After confirming tunnel works, consider closing:"
        echo "• Port 80 (HTTP) - if all web services use tunnel"
        echo "• Port 443 (HTTPS) - if all web services use tunnel"
        echo "• Port 7687 (Neo4j) - if Neo4j uses tunnel"
    fi
    if [ $cloudflare_ssh_selected -eq 1 ]; then
        echo "SSH Tunnel - After confirming SSH tunnel works, consider closing:"
        echo "• Port 22 (SSH) - SSH tunnel uses host networking for direct access"
    fi
    if [ $cloudflare_tunnel_selected -eq 1 ] && [ $cloudflare_ssh_selected -eq 1 ]; then
        echo ""
        echo "🏗️  ARCHITECTURE NOTES:"
        echo "• Web tunnel: Uses Docker network for container access"
        echo "• SSH tunnel: Uses host networking for SSH port 22 access"
        echo "• Both tunnels can operate independently"
    fi
    echo ""
    echo "⚠️  Only close ports AFTER confirming tunnel connectivity!"
    echo ""
fi

# Remove existing COMPOSE_PROFILES line if it exists
if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
    # Using a different delimiter for sed because a profile name might contain '/' (unlikely here)
    sed -i.bak "\|^COMPOSE_PROFILES=|d" "$ENV_FILE"
fi

# Add the new COMPOSE_PROFILES line
echo "COMPOSE_PROFILES=${COMPOSE_PROFILES_VALUE}" >> "$ENV_FILE"
if [ -z "$COMPOSE_PROFILES_VALUE" ]; then
    log_info "Only core services (Caddy, Postgres, Redis) will be started."
else
    log_info "The following Docker Compose profiles will be active: ${COMPOSE_PROFILES_VALUE}"
fi

# Speech Stack Authentication Setup (if speech profile was selected)
if [[ ",$COMPOSE_PROFILES_VALUE," == *",speech,"* ]]; then
    log_info ""
    log_info "Speech Stack Authentication Setup"
    log_info "================================="
    log_info "The Speech services (Whisper STT and TTS) need authentication for security."
    log_info ""

    # Ask for username
    read -p "Enter username for Speech services [admin]: " speech_user
    speech_user=${speech_user:-admin}

    # Ask for password
    while true; do
        read -s -p "Enter password for Speech services: " speech_password
        echo
        if [ -z "$speech_password" ]; then
            log_warning "Password cannot be empty. Please try again."
        else
            break
        fi
    done

    # Generate password hashes
    log_info "Generating secure password hashes..."

    # Check if Docker is available
    if command -v docker &> /dev/null; then
        # Generate hash for Whisper
        whisper_hash=$(docker run --rm caddy:alpine caddy hash-password --plaintext "$speech_password" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$whisper_hash" ]; then
            # Use same hash for both services (simpler for users)
            tts_hash="$whisper_hash"

            # Update .env file with auth settings
            # Remove existing entries if present
            sed -i.bak "/^WHISPER_AUTH_USER=/d" "$ENV_FILE"
            sed -i.bak "/^WHISPER_AUTH_PASSWORD_HASH=/d" "$ENV_FILE"
            sed -i.bak "/^TTS_AUTH_USER=/d" "$ENV_FILE"
            sed -i.bak "/^TTS_AUTH_PASSWORD_HASH=/d" "$ENV_FILE"

            # Add new entries
            echo "WHISPER_AUTH_USER=$speech_user" >> "$ENV_FILE"
            echo "WHISPER_AUTH_PASSWORD_HASH=${whisper_hash//\$/\$\$}" >> "$ENV_FILE"
            echo "TTS_AUTH_USER=$speech_user" >> "$ENV_FILE"
            echo "TTS_AUTH_PASSWORD_HASH=${tts_hash//\$/\$\$}" >> "$ENV_FILE"

            log_success "Speech services authentication configured successfully."
            log_info "Username: $speech_user"
            log_info "Use this username and password to access:"
            log_info "  - Whisper: https://asr.yourdomain.com"
            log_info "  - TTS: https://tts.yourdomain.com"
            log_info ""
        else
            log_warning "Could not generate password hash. Docker might not be installed yet."
            log_warning "You'll need to manually set WHISPER_AUTH_PASSWORD_HASH and TTS_AUTH_PASSWORD_HASH in .env"
            log_info "Run after installation: docker run --rm caddy:alpine caddy hash-password --plaintext 'your-password'"
        fi
    else
        log_warning "Docker not available. Saving plaintext password for later hashing."
        log_warning "The installer will generate the hash during Docker setup."

        # Save as temporary placeholder
        sed -i.bak "/^WHISPER_AUTH_USER=/d" "$ENV_FILE"
        sed -i.bak "/^SPEECH_TEMP_PASSWORD=/d" "$ENV_FILE"

        echo "WHISPER_AUTH_USER=$speech_user" >> "$ENV_FILE"
        echo "TTS_AUTH_USER=$speech_user" >> "$ENV_FILE"
        echo "SPEECH_TEMP_PASSWORD=$speech_password" >> "$ENV_FILE"
        echo "# Note: Password hashes will be generated during installation" >> "$ENV_FILE"
    fi
fi

# Google Calendar Integration for Cal.com (if calcom profile was selected)
if [[ ",$COMPOSE_PROFILES_VALUE," == *",calcom,"* ]]; then
    log_info ""
    log_info "Google Calendar Integration for Cal.com (Optional)"
    log_info "=================================================="
    log_info "Enable Google Calendar sync in Cal.com (you can skip this)."
    log_info ""
    log_info "To get credentials:"
    log_info "1. Go to https://console.cloud.google.com"
    log_info "2. Enable Google Calendar API"
    log_info "3. Create OAuth 2.0 credentials"
    log_info "4. Add redirect URIs with your domain"
    log_info ""
    log_info "Press ENTER to skip if you don't have credentials yet."
    log_info ""

    # Check if already exists
    existing_client_id=""
    if grep -q "^GOOGLE_CLIENT_ID=" "$ENV_FILE"; then
        existing_client_id=$(grep "^GOOGLE_CLIENT_ID=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^\"//' | sed 's/\"$//')
    fi

    if [ -n "$existing_client_id" ]; then
        log_info "Google credentials found in .env; reusing them."
    else
        read -p "Google OAuth Client ID (optional): " google_client_id
        
        if [ -n "$google_client_id" ]; then
            read -p "Google OAuth Client Secret: " google_client_secret
            
            # Update .env
            sed -i.bak "/^GOOGLE_CLIENT_ID=/d" "$ENV_FILE"
            sed -i.bak "/^GOOGLE_CLIENT_SECRET=/d" "$ENV_FILE"
            
            echo "GOOGLE_CLIENT_ID=$google_client_id" >> "$ENV_FILE"
            echo "GOOGLE_CLIENT_SECRET=$google_client_secret" >> "$ENV_FILE"
            
            log_success "Google Calendar credentials saved."
            log_info "Will be configured automatically after Cal.com starts."
        else
            log_info "Skipping Google Calendar integration."
            log_info "You can add it later by editing .env and running:"
            log_info "  sudo bash scripts/setup_calcom_google.sh"
        fi
    fi
fi

# Docker-Mailserver account setup (if mailserver profile was selected)
if [[ ",$COMPOSE_PROFILES_VALUE," == *",mailserver,"* ]]; then
    log_info ""
    log_info "Configuring Docker-Mailserver..."
    
    # Get BASE_DOMAIN and MAIL_NOREPLY_PASSWORD from .env
    BASE_DOMAIN=$(grep "^BASE_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    MAIL_NOREPLY_PASSWORD=$(grep "^MAIL_NOREPLY_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    if [[ -n "$BASE_DOMAIN" && -n "$MAIL_NOREPLY_PASSWORD" ]]; then
        # Create directory for Docker-Mailserver config
        ACCOUNTS_DIR="$PROJECT_ROOT/docker-data/dms/config"
        mkdir -p "$ACCOUNTS_DIR"
        
        # Remove ALL old SMTP and EMAIL settings
        sed -i.bak "/^SMTP_HOST=/d" "$ENV_FILE"
        sed -i.bak "/^SMTP_PORT=/d" "$ENV_FILE"
        sed -i.bak "/^SMTP_USER=/d" "$ENV_FILE"
        sed -i.bak "/^SMTP_PASS=/d" "$ENV_FILE"
        sed -i.bak "/^SMTP_FROM=/d" "$ENV_FILE"
        sed -i.bak "/^SMTP_SECURE=/d" "$ENV_FILE"
        sed -i.bak "/^MAIL_MODE=/d" "$ENV_FILE"
        
        # WICHTIG: Auch EMAIL_* Variablen löschen und neu setzen!
        sed -i.bak "/^EMAIL_SMTP=/d" "$ENV_FILE"
        sed -i.bak "/^EMAIL_SMTP_HOST=/d" "$ENV_FILE"
        sed -i.bak "/^EMAIL_SMTP_PORT=/d" "$ENV_FILE"
        sed -i.bak "/^EMAIL_SMTP_USER=/d" "$ENV_FILE"
        sed -i.bak "/^EMAIL_SMTP_PASSWORD=/d" "$ENV_FILE"
        sed -i.bak "/^EMAIL_SMTP_USE_TLS=/d" "$ENV_FILE"
        sed -i.bak "/^EMAIL_FROM=/d" "$ENV_FILE"
        
        # Set all variables for mailserver
        echo "MAIL_MODE=mailserver" >> "$ENV_FILE"
        echo "SMTP_HOST=mailserver" >> "$ENV_FILE"
        echo "SMTP_PORT=587" >> "$ENV_FILE"
        echo "SMTP_USER=noreply@${BASE_DOMAIN}" >> "$ENV_FILE"
        echo "SMTP_PASS=${MAIL_NOREPLY_PASSWORD}" >> "$ENV_FILE"
        echo "SMTP_FROM=noreply@${BASE_DOMAIN}" >> "$ENV_FILE"
        echo "SMTP_SECURE=true" >> "$ENV_FILE"
        
        # WICHTIG: Mirror to EMAIL_* for Baserow, Cal.com etc.
        echo "EMAIL_SMTP=mailserver" >> "$ENV_FILE"
        echo "EMAIL_SMTP_HOST=mailserver" >> "$ENV_FILE"
        echo "EMAIL_SMTP_PORT=587" >> "$ENV_FILE"
        echo "EMAIL_SMTP_USER=noreply@${BASE_DOMAIN}" >> "$ENV_FILE"
        echo "EMAIL_SMTP_PASSWORD=${MAIL_NOREPLY_PASSWORD}" >> "$ENV_FILE"
        echo "EMAIL_SMTP_USE_TLS=true" >> "$ENV_FILE"
        echo "EMAIL_FROM=noreply@${BASE_DOMAIN}" >> "$ENV_FILE"
        
        log_success "Docker-Mailserver SMTP settings configured for all services"
        log_info "Remember to configure DNS records after installation!"
    else
        log_warning "Could not configure Docker-Mailserver - missing BASE_DOMAIN or password"
    fi
fi
# Special adaption for baserow (smtp-relay because of port-blocking)
if [[ ",$COMPOSE_PROFILES_VALUE," == *",baserow,"* ]] && [[ ",$COMPOSE_PROFILES_VALUE," == *",mailserver,"* ]]; then
    sed -i.bak "/^EMAIL_SMTP_HOST=/d" "$ENV_FILE"
    sed -i.bak "/^EMAIL_SMTP_PORT=/d" "$ENV_FILE"
    sed -i.bak "/^EMAIL_SMTP_USE_TLS=/d" "$ENV_FILE"
    echo "EMAIL_SMTP_HOST=smtp-relay" >> "$ENV_FILE"
    echo "EMAIL_SMTP_PORT=8025" >> "$ENV_FILE"
    echo "EMAIL_SMTP_USE_TLS=false" >> "$ENV_FILE"
    log_info "Baserow configured to use SMTP relay (workaround for port blocking)"
fi

# Make the script executable (though install.sh calls it with bash)
chmod +x "$SCRIPT_DIR/04_wizard.sh"

exit 0
