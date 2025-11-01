#!/usr/bin/env python3
"""
start_services.py

This script starts the Supabase stack first, waits for it to initialize, and then starts
the local AI stack. Both stacks share the same Docker Compose project name so they
appear together in Docker tooling.
"""

import os
import subprocess
import shutil
import time
import argparse
import platform
import sys
import yaml
import re
from pathlib import Path
from dotenv import dotenv_values

REPO_ROOT = Path(__file__).resolve().parent
DEFAULT_ENV_FILE = REPO_ROOT / ".env"
ENV_FILE = Path(os.environ.get("LAUNCHKIT_ENV_FILE", DEFAULT_ENV_FILE))

def _sanitize_project_name(name: str) -> str:
    """Replicate compose slug behaviour by lowercasing and replacing invalid chars."""
    sanitized = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return sanitized or "localai"

ENV_VALUES = dotenv_values(ENV_FILE) if ENV_FILE.exists() else {}
PROJECT_NAME = os.environ.get("LAUNCHKIT_PROJECT_NAME") or ENV_VALUES.get("PROJECT_NAME") or "localai"
PROJECT_SLUG = _sanitize_project_name(PROJECT_NAME)

def get_env_values():
    """Reload environment values from the selected env file."""
    return dotenv_values(ENV_FILE) if ENV_FILE.exists() else {}

def compose_project_flag():
    return ["-p", PROJECT_NAME]

def compose_container_name(service: str, index: int = 1) -> str:
    """Return docker compose container name for a given service."""
    return f"{PROJECT_SLUG}-{service}-{index}"

def is_supabase_enabled():
    """Check if 'supabase' is in COMPOSE_PROFILES in .env file."""
    env_values = get_env_values()
    compose_profiles = env_values.get("COMPOSE_PROFILES", "")
    return "supabase" in compose_profiles.split(',')

def is_dify_enabled():
    """Check if 'dify' is in COMPOSE_PROFILES in .env file."""
    env_values = get_env_values()
    compose_profiles = env_values.get("COMPOSE_PROFILES", "")
    return "dify" in compose_profiles.split(',')

def get_all_profiles(compose_file):
    """Get all profile names from a docker-compose file."""
    if not os.path.exists(compose_file):
        return []
    
    with open(compose_file, 'r') as f:
        compose_config = yaml.safe_load(f)

    profiles = set()
    if 'services' in compose_config:
        for service_name, service_config in compose_config.get('services', {}).items():
            if service_config and 'profiles' in service_config:
                for profile in service_config['profiles']:
                    profiles.add(profile)
    return list(profiles)

def run_command(cmd, cwd=None):
    """Run a shell command and print it."""
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)

def clone_supabase_repo():
    """Clone the Supabase repository using sparse checkout if not already present."""
    if not is_supabase_enabled():
        print("Supabase is not enabled, skipping clone.")
        return
    if not (REPO_ROOT / "supabase").exists():
        print("Cloning the Supabase repository...")
        run_command([
            "git", "clone", "--filter=blob:none", "--no-checkout",
            "https://github.com/supabase/supabase.git"
        ])
        os.chdir(REPO_ROOT / "supabase")
        run_command(["git", "sparse-checkout", "init", "--cone"])
        run_command(["git", "sparse-checkout", "set", "docker"])
        run_command(["git", "checkout", "master"])
        os.chdir("..")
    else:
        print("Supabase repository already exists, updating...")
        os.chdir(REPO_ROOT / "supabase")
        run_command(["git", "pull"])
        os.chdir("..")

def ensure_clean_supabase_db():
    """Ensure Supabase DB starts fresh if passwords don't match."""
    if not is_supabase_enabled():
        return
        
    supabase_data_dir = REPO_ROOT / "supabase" / "docker" / "volumes" / "db" / "data"
    
    # Check if data directory exists and has content
    if supabase_data_dir.exists() and any(supabase_data_dir.iterdir()):
        print("WARNING: Existing Supabase database data found.")
        print("If you have password authentication issues, consider removing:")
        print(f"  sudo rm -rf {supabase_data_dir}")
        print("Note: This will DELETE all existing Supabase data!")

def prepare_supabase_env():
    """Create proper Supabase .env with correct password configuration."""
    if not is_supabase_enabled():
        print("Supabase is not enabled, skipping env preparation.")
        return
    
    supabase_docker_dir = REPO_ROOT / "supabase" / "docker"
    
    # First, copy the example file
    env_example_path = supabase_docker_dir / ".env.example"
    env_path = supabase_docker_dir / ".env"
    
    if env_example_path.exists():
        print(f"Creating {env_path} from {env_example_path}...")
        shutil.copyfile(env_example_path, env_path)
    
    # Load values from root .env
    root_env = get_env_values()
    
    # Get the postgres password from root env
    postgres_password = root_env.get("POSTGRES_PASSWORD", "")
    
    # Read the Supabase .env file
    with env_path.open('r') as f:
        lines = f.readlines()
    
    # Update with our values
    new_lines = []
    for line in lines:
        if line.startswith("POSTGRES_PASSWORD="):
            new_lines.append(f"POSTGRES_PASSWORD={postgres_password}\n")
        elif line.startswith("JWT_SECRET="):
            jwt_secret = root_env.get("JWT_SECRET", "")
            new_lines.append(f"JWT_SECRET={jwt_secret}\n")
        elif line.startswith("ANON_KEY="):
            anon_key = root_env.get("ANON_KEY", "")
            new_lines.append(f"ANON_KEY={anon_key}\n")
        elif line.startswith("SERVICE_ROLE_KEY="):
            service_key = root_env.get("SERVICE_ROLE_KEY", "")
            new_lines.append(f"SERVICE_ROLE_KEY={service_key}\n")
        elif line.startswith("DASHBOARD_USERNAME="):
            dashboard_user = root_env.get("DASHBOARD_USERNAME", "supabase")
            new_lines.append(f"DASHBOARD_USERNAME={dashboard_user}\n")
        elif line.startswith("DASHBOARD_PASSWORD="):
            dashboard_pass = root_env.get("DASHBOARD_PASSWORD", "")
            new_lines.append(f"DASHBOARD_PASSWORD={dashboard_pass}\n")
        else:
            new_lines.append(line)
    
    # Write back
    with env_path.open('w') as f:
        f.writelines(new_lines)
    
    print("Supabase .env prepared with correct passwords.")

def clone_dify_repo():
    """Clone the Dify repository using sparse checkout if not already present."""
    if not is_dify_enabled():
        print("Dify is not enabled, skipping clone.")
        return
    if not (REPO_ROOT / "dify").exists():
        print("Cloning the Dify repository...")
        run_command([
            "git", "clone", "--filter=blob:none", "--no-checkout",
            "https://github.com/langgenius/dify.git"
        ])
        os.chdir(REPO_ROOT / "dify")
        run_command(["git", "sparse-checkout", "init", "--cone"])
        run_command(["git", "sparse-checkout", "set", "docker"])
        # Dify's default branch is 'main'
        run_command(["git", "checkout", "main"])
        os.chdir("..")
    else:
        print("Dify repository already exists, updating...")
        os.chdir(REPO_ROOT / "dify")
        run_command(["git", "pull"])
        os.chdir("..")

def prepare_dify_env():
    """Create dify/docker/.env from env.example and inject selected values from root .env.

    Mapping (strip DIFY_ prefix from root .env):
      - DIFY_SECRET_KEY -> SECRET_KEY
      - DIFY_EXPOSE_NGINX_PORT -> EXPOSE_NGINX_PORT
      - DIFY_EXPOSE_NGINX_SSL_PORT -> EXPOSE_NGINX_SSL_PORT
    """
    if not is_dify_enabled():
        print("Dify is not enabled, skipping env preparation.")
        return

    dify_docker_dir = REPO_ROOT / "dify" / "docker"
    if not dify_docker_dir.is_dir():
        print(f"Warning: Dify docker directory not found at {dify_docker_dir}. Have you cloned the repo?")
        return

    # Determine env example file name: prefer 'env.example', fallback to '.env.example'
    env_example_candidates = [
        dify_docker_dir / "env.example",
        dify_docker_dir / ".env.example",
    ]
    env_example_path = next((p for p in env_example_candidates if p.exists()), None)

    if env_example_path is None:
        print(f"Warning: Could not find env.example in {dify_docker_dir}")
        return

    env_path = dify_docker_dir / ".env"

    print(f"Creating {env_path} from {env_example_path}...")
    with env_example_path.open('r') as f:
        env_content = f.read()

    # Load values from root .env
    root_env = get_env_values()
    mapping = {
        "SECRET_KEY": root_env.get("DIFY_SECRET_KEY", ""),
        "EXPOSE_NGINX_PORT": root_env.get("DIFY_EXPOSE_NGINX_PORT", ""),
        "EXPOSE_NGINX_SSL_PORT": root_env.get("DIFY_EXPOSE_NGINX_SSL_PORT", ""),
    }

    # Replace or append variables in env_content
    lines = env_content.splitlines()
    replaced_keys = set()
    for i, line in enumerate(lines):
        for dest_key, value in mapping.items():
            if line.startswith(f"{dest_key}=") and value:
                lines[i] = f"{dest_key}={value}"
                replaced_keys.add(dest_key)

    # Append any missing keys with values
    for dest_key, value in mapping.items():
        if value and dest_key not in replaced_keys:
            lines.append(f"{dest_key}={value}")

    with env_path.open('w') as f:
        f.write("\n".join(lines) + "\n")

def stop_existing_containers():
    """Stop and remove existing containers for the configured compose project."""
    print(f"Stopping and removing existing containers for the unified project '{PROJECT_NAME}'...")
    
    # Base command
    cmd = ["docker", "compose"] + compose_project_flag()

    # Get all profiles from the main docker-compose.yml to ensure all services can be brought down
    all_profiles = get_all_profiles("docker-compose.yml")
    for profile in all_profiles:
        cmd.extend(["--profile", profile])
    
    cmd.extend(["-f", str(REPO_ROOT / "docker-compose.yml")])

    # Check if the Supabase Docker Compose file exists. If so, include it in the 'down' command.
    supabase_compose_path = REPO_ROOT / "supabase" / "docker" / "docker-compose.yml"
    if supabase_compose_path.exists():
        cmd.extend(["-f", str(supabase_compose_path)])
    
    # Check if the Dify Docker Compose file exists. If so, include it in the 'down' command.
    dify_compose_path = REPO_ROOT / "dify" / "docker" / "docker-compose.yaml"
    if dify_compose_path.exists():
        cmd.extend(["-f", str(dify_compose_path)])

    cmd.append("down")
    run_command(cmd)

def start_supabase():
    """Start the Supabase services (using its compose file)."""
    if not is_supabase_enabled():
        print("Supabase is not enabled, skipping start.")
        return
    print("Starting Supabase services...")
    # Explicitly start the db service first
    run_command([
        "docker", "compose", *compose_project_flag(), "-f", str(REPO_ROOT / "supabase" / "docker" / "docker-compose.yml"), "up", "-d", "db"
    ])
    # Wait for db to be ready
    time.sleep(5)
    # Then start all other services
    run_command([
        "docker", "compose", *compose_project_flag(), "-f", str(REPO_ROOT / "supabase" / "docker" / "docker-compose.yml"), "up", "-d"
    ])

def start_dify():
    """Start the Dify services (using its compose file)."""
    if not is_dify_enabled():
        print("Dify is not enabled, skipping start.")
        return
    
    print("Starting Dify services...")
    
    # WICHTIG: Starte zuerst die DB
    print("Starting Dify database first...")
    run_command([
        "docker", "compose", *compose_project_flag(), "-f", str(REPO_ROOT / "dify" / "docker" / "docker-compose.yaml"),
        "up", "-d", "db"
    ])
    
    # Warte bis DB bereit ist
    print("Waiting for Dify database to be ready...")
    time.sleep(5)
    
    # Erstelle die dify_plugin Datenbank falls sie nicht existiert
    print("Ensuring dify_plugin database exists...")
    try:
        container_name = compose_container_name("db")
        subprocess.run([
            "docker", "exec", container_name, "psql", "-U", "postgres",
            "-c", "CREATE DATABASE dify_plugin;"
        ], capture_output=True, check=False)
        print("dify_plugin database created or already exists.")
    except Exception as e:
        # Ignoriere Fehler falls DB schon existiert oder Container-Name anders ist
        print(f"Note: Could not create dify_plugin database (may already exist): {e}")
    
    # DANN starte alle anderen Services
    print("Starting remaining Dify services...")
    run_command([
        "docker", "compose", *compose_project_flag(), "-f", str(REPO_ROOT / "dify" / "docker" / "docker-compose.yaml"),
        "up", "-d"
    ])

def start_local_ai():
    """Start the local AI services (using its compose file)."""
    print("Starting local AI services...")

    # Explicitly build services and pull newer base images first.
    print("Checking for newer base images and building services...")
    build_cmd = ["docker", "compose", *compose_project_flag(), "-f", str(REPO_ROOT / "docker-compose.yml"), "build", "--pull"]
    run_command(build_cmd)

    # Now, start the services using the newly built images. No --build needed as we just built.
    print("Starting containers...")
    up_cmd = ["docker", "compose", *compose_project_flag(), "-f", str(REPO_ROOT / "docker-compose.yml"), "up", "-d"]
    run_command(up_cmd)

def generate_searxng_secret_key():
    """Generate a secret key for SearXNG based on the current platform."""
    print("Checking SearXNG settings...")

    # Define paths for SearXNG settings files
    settings_path = REPO_ROOT / "searxng" / "settings.yml"
    settings_base_path = REPO_ROOT / "searxng" / "settings-base.yml"

    # Check if settings-base.yml exists
    if not settings_base_path.exists():
        print(f"Warning: SearXNG base settings file not found at {settings_base_path}")
        return

    # Check if settings.yml exists, if not create it from settings-base.yml
    if not settings_path.exists():
        print(f"SearXNG settings.yml not found. Creating from {settings_base_path}...")
        try:
            shutil.copyfile(settings_base_path, settings_path)
            print(f"Created {settings_path} from {settings_base_path}")
        except Exception as e:
            print(f"Error creating settings.yml: {e}")
            return
    else:
        print(f"SearXNG settings.yml already exists at {settings_path}")

    print("Generating SearXNG secret key...")

    # Detect the platform and run the appropriate command
    system = platform.system()

    try:
        if system == "Windows":
            print("Detected Windows platform, using PowerShell to generate secret key...")
            # PowerShell command to generate a random key and replace in the settings file
            ps_command = [
                "powershell", "-Command",
                "$randomBytes = New-Object byte[] 32; " +
                "(New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes); " +
                "$secretKey = -join ($randomBytes | ForEach-Object { \"{0:x2}\" -f $_ }); " +
                "(Get-Content searxng/settings.yml) -replace 'ultrasecretkey', $secretKey | Set-Content searxng/settings.yml"
            ]
            subprocess.run(ps_command, check=True)

        elif system == "Darwin":  # macOS
            print("Detected macOS platform, using sed command with empty string parameter...")
            # macOS sed command requires an empty string for the -i parameter
            openssl_cmd = ["openssl", "rand", "-hex", "32"]
            random_key = subprocess.check_output(openssl_cmd).decode('utf-8').strip()
            sed_cmd = ["sed", "-i", "", f"s|ultrasecretkey|{random_key}|g", settings_path]
            subprocess.run(sed_cmd, check=True)

        else:  # Linux and other Unix-like systems
            print("Detected Linux/Unix platform, using standard sed command...")
            # Standard sed command for Linux
            openssl_cmd = ["openssl", "rand", "-hex", "32"]
            random_key = subprocess.check_output(openssl_cmd).decode('utf-8').strip()
            sed_cmd = ["sed", "-i", f"s|ultrasecretkey|{random_key}|g", settings_path]
            subprocess.run(sed_cmd, check=True)

        print("SearXNG secret key generated successfully.")

    except Exception as e:
        print(f"Error generating SearXNG secret key: {e}")
        print("You may need to manually generate the secret key using the commands:")
        print("  - Linux: sed -i \"s|ultrasecretkey|$(openssl rand -hex 32)|g\" searxng/settings.yml")
        print("  - macOS: sed -i '' \"s|ultrasecretkey|$(openssl rand -hex 32)|g\" searxng/settings.yml")
        print("  - Windows (PowerShell):")
        print("    $randomBytes = New-Object byte[] 32")
        print("    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes)")
        print("    $secretKey = -join ($randomBytes | ForEach-Object { \"{0:x2}\" -f $_ })")
        print("    (Get-Content searxng/settings.yml) -replace 'ultrasecretkey', $secretKey | Set-Content searxng/settings.yml")

def check_and_fix_docker_compose_for_searxng():
    """Check and modify docker-compose.yml for SearXNG first run."""
    docker_compose_path = REPO_ROOT / "docker-compose.yml"
    if not docker_compose_path.exists():
        print(f"Warning: Docker Compose file not found at {docker_compose_path}")
        return

    try:
        # Read the docker-compose.yml file
        with docker_compose_path.open('r') as file:
            content = file.read()

        # Default to first run
        is_first_run = True

        # Check if Docker is running and if the SearXNG container exists
        try:
            # Check if the SearXNG container is running
            container_check = subprocess.run(
                ["docker", "ps", "--filter", "name=searxng", "--format", "{{.Names}}"],
                capture_output=True, text=True, check=True
            )
            searxng_containers = container_check.stdout.strip().split('\n')

            # If SearXNG container is running, check inside for uwsgi.ini
            if any(container for container in searxng_containers if container):
                container_name = next(container for container in searxng_containers if container)
                print(f"Found running SearXNG container: {container_name}")

                # Check if uwsgi.ini exists inside the container
                container_check = subprocess.run(
                    ["docker", "exec", container_name, "sh", "-c", "[ -f /etc/searxng/uwsgi.ini ] && echo 'found' || echo 'not_found'"],
                    capture_output=True, text=True, check=False
                )

                if "found" in container_check.stdout:
                    print("Found uwsgi.ini inside the SearXNG container - not first run")
                    is_first_run = False
                else:
                    print("uwsgi.ini not found inside the SearXNG container - first run")
                    is_first_run = True
            else:
                print("No running SearXNG container found - assuming first run")
        except Exception as e:
            print(f"Error checking Docker container: {e} - assuming first run")

        if is_first_run and "cap_drop: - ALL" in content:
            print("First run detected for SearXNG. Temporarily removing 'cap_drop: - ALL' directive...")
            # Temporarily comment out the cap_drop line
            modified_content = content.replace("cap_drop: - ALL", "# cap_drop: - ALL  # Temporarily commented out for first run")

            # Write the modified content back
            with docker_compose_path.open('w') as file:
                file.write(modified_content)

            print("Note: After the first run completes successfully, you should re-add 'cap_drop: - ALL' to docker-compose.yml for security reasons.")
        elif not is_first_run and "# cap_drop: - ALL  # Temporarily commented out for first run" in content:
            print("SearXNG has been initialized. Re-enabling 'cap_drop: - ALL' directive for security...")
            # Uncomment the cap_drop line and ensure correct multi-line YAML format
            correct_cap_drop_block = "cap_drop:\n      - ALL" # Note the newline and indentation for the list item
            modified_content = content.replace("# cap_drop: - ALL  # Temporarily commented out for first run", correct_cap_drop_block)
            
            # Write the modified content back
            with docker_compose_path.open('w') as file:
                file.write(modified_content)

    except Exception as e:
        print(f"Error checking/modifying docker-compose.yml for SearXNG: {e}")

def main():
    os.chdir(REPO_ROOT)
    # Clone and prepare repositories
    if is_supabase_enabled():
        clone_supabase_repo()
        prepare_supabase_env()
        ensure_clean_supabase_db()
    
    if is_dify_enabled():
        clone_dify_repo()
        prepare_dify_env()
    
    # Generate SearXNG secret key and check docker-compose.yml
    generate_searxng_secret_key()
    check_and_fix_docker_compose_for_searxng()
    
    stop_existing_containers()
    
    # Start Supabase first
    if is_supabase_enabled():
        start_supabase()
        # Give Supabase some time to initialize
        print("Waiting for Supabase to initialize...")
        time.sleep(10)
    
    # Start Dify services
    if is_dify_enabled():
        start_dify()
        # Give Dify some time to initialize
        print("Waiting for Dify to initialize...")
        time.sleep(10)
    
    # Then start the local AI services
    start_local_ai()

if __name__ == "__main__":
    main()
