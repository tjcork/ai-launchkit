#!/bin/bash

# Logging function that frames a message with a border and adds a timestamp
log_message() {
    local message="$1"
    local combined_message="${message}"
    local length=${#combined_message}
    local border_length=$((length + 4))
    
    # Create the top border
    local border=""
    for ((i=0; i<border_length; i++)); do
        border="${border}─"
    done
    
    # Display the framed message with timestamp
    echo "╭${border}╮"
    echo "│ ${combined_message}   │"
    echo "╰${border}╯"
}

# Example usage:
# log_message "This is a test message"

log_success() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[SUCCESS] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

log_error() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[ERROR] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

log_warning() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[WARNING] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

log_info() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[INFO] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

resolve_env_context() {
    local project_root="$1"
    if [ -z "$project_root" ]; then
        log_error "resolve_env_context requires project root path"
        exit 1
    fi

    local default_env_file="$project_root/.env"

    if [ -z "$LAUNCHKIT_ENV_FILE" ]; then
        LAUNCHKIT_ENV_FILE="$default_env_file"
    fi

    if [ -z "$LAUNCHKIT_PROJECT_NAME" ] && [ -f "$LAUNCHKIT_ENV_FILE" ]; then
        LAUNCHKIT_PROJECT_NAME=$(grep -E '^PROJECT_NAME=' "$LAUNCHKIT_ENV_FILE" | tail -n1 | cut -d'=' -f2- | tr -d '"' | xargs)
    fi

    if [ -z "$LAUNCHKIT_PROJECT_NAME" ]; then
        LAUNCHKIT_PROJECT_NAME="localai"
    fi

    export LAUNCHKIT_ENV_FILE
    export LAUNCHKIT_PROJECT_NAME
}
