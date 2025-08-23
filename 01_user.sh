#!/bin/bash
set -e

# Configuration
USERNAME="${1:-admin}"
SSH_KEY_FILE="${2:-}"
LOGFILE="/var/log/user-setup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting user setup for: $USERNAME"

# Validate username
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    log "ERROR: Invalid username format: $USERNAME"
    exit 1
fi

# Создать группу admin, если нет
if ! getent group admin >/dev/null; then
    log "Creating admin group..."
    groupadd admin
    log "Admin group created successfully"
else
    log "Admin group already exists"
fi

# Создать пользователя, если нет
if ! id -u "$USERNAME" >/dev/null 2>&1; then
    log "Creating user: $USERNAME"
    
    # Prompt for password
    echo "Creating user: $USERNAME"
    echo "Please set a password for the new user:"
    
    # Create user with password prompt (use --ingroup to avoid group creation conflicts)
    adduser --gecos "" --ingroup admin "$USERNAME"
    log "User $USERNAME created and added to admin group"
else
    log "User $USERNAME already exists"
    # Ensure user is in admin group
    if ! groups "$USERNAME" | grep -q admin; then
        usermod -aG admin "$USERNAME"
        log "Added existing user $USERNAME to admin group"
    fi
fi

# Добавить в sudoers (без visudo)
SUDOERS_FILE="/etc/sudoers.d/admin"
if [ ! -f "$SUDOERS_FILE" ]; then
    log "Adding admin group to sudoers..."
    echo "admin ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    
    # Validate sudoers file
    if visudo -c -f "$SUDOERS_FILE"; then
        log "Sudoers file created and validated successfully"
    else
        log "ERROR: Invalid sudoers file created"
        rm -f "$SUDOERS_FILE"
        exit 1
    fi
else
    log "Sudoers file already exists"
fi

# Setup SSH key if provided
if [ -n "$SSH_KEY_FILE" ]; then
    log "Setting up SSH key from: $SSH_KEY_FILE"
    
    # Validate SSH key file exists and is readable
    if [ ! -f "$SSH_KEY_FILE" ]; then
        log "ERROR: SSH key file not found: $SSH_KEY_FILE"
        exit 1
    fi
    
    if [ ! -r "$SSH_KEY_FILE" ]; then
        log "ERROR: SSH key file not readable: $SSH_KEY_FILE"
        exit 1
    fi
    
    # Validate SSH key format
    if ! ssh-keygen -l -f "$SSH_KEY_FILE" >/dev/null 2>&1; then
        log "ERROR: Invalid SSH key format in file: $SSH_KEY_FILE"
        exit 1
    fi
    
    # Get user's home directory
    USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
    SSH_DIR="$USER_HOME/.ssh"
    AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
    
    # Create .ssh directory if it doesn't exist
    if [ ! -d "$SSH_DIR" ]; then
        log "Creating SSH directory: $SSH_DIR"
        mkdir -p "$SSH_DIR"
        chown "$USERNAME:$USERNAME" "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi
    
    # Read the SSH key content
    SSH_KEY_CONTENT=$(cat "$SSH_KEY_FILE")
    
    # Check if key already exists in authorized_keys
    if [ -f "$AUTHORIZED_KEYS" ] && grep -Fq "$SSH_KEY_CONTENT" "$AUTHORIZED_KEYS"; then
        log "SSH key already exists in authorized_keys"
    else
        log "Adding SSH key to authorized_keys"
        echo "$SSH_KEY_CONTENT" >> "$AUTHORIZED_KEYS"
        chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        log "SSH key added successfully"
    fi
    
    # Display key fingerprint for verification
    KEY_FINGERPRINT=$(ssh-keygen -l -f "$SSH_KEY_FILE" 2>/dev/null | awk '{print $2}')
    log "SSH key fingerprint: $KEY_FINGERPRINT"
    echo "✓ SSH key added - Fingerprint: $KEY_FINGERPRINT"
else
    log "No SSH key file provided - skipping SSH key setup"
    echo "⚠️  No SSH key provided. Remember to add your SSH key manually:"
    echo "   ssh-copy-id -p [SSH_PORT] $USERNAME@[SERVER_IP]"
fi

log "[OK] User setup completed successfully for: $USERNAME"
echo "[OK] User $USERNAME created and configured with sudo privileges"
