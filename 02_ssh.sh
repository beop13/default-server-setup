#!/bin/bash
set -e

# Configuration
SSH_PORT="${1:-2219}"
ALLOWED_GROUP="${2:-admin}"
SSHD_CONFIG="/etc/ssh/sshd_config"
LOGFILE="/var/log/ssh-setup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting SSH configuration..."

# Validate port number
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1024 ] || [ "$SSH_PORT" -gt 65535 ]; then
    log "ERROR: Invalid SSH port: $SSH_PORT (must be 1024-65535)"
    exit 1
fi

# Check if SSH service exists
if ! systemctl is-enabled ssh >/dev/null 2>&1 && ! systemctl is-enabled sshd >/dev/null 2>&1; then
    log "ERROR: SSH service not found. Installing openssh-server..."
    apt update && apt install -y openssh-server
fi

# Создать бэкап с timestamp
BACKUP_FILE="${SSHD_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
if [ ! -f "${SSHD_CONFIG}.bak" ]; then
    log "Creating backup: $BACKUP_FILE"
    cp "$SSHD_CONFIG" "$BACKUP_FILE"
    ln -sf "$BACKUP_FILE" "${SSHD_CONFIG}.bak"
else
    log "Backup already exists: ${SSHD_CONFIG}.bak"
fi

# Функция для безопасного изменения конфига
update_ssh_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    
    if grep -q "^#*${key}" "$config_file"; then
        sed -i "s/^#*${key}.*/${key} ${value}/" "$config_file"
        log "Updated: $key $value"
    else
        echo "${key} ${value}" >> "$config_file"
        log "Added: $key $value"
    fi
}

log "Configuring SSH settings..."

# Настроить SSH
update_ssh_config "Port" "$SSH_PORT" "$SSHD_CONFIG"
update_ssh_config "PermitRootLogin" "no" "$SSHD_CONFIG"
update_ssh_config "PasswordAuthentication" "no" "$SSHD_CONFIG"
update_ssh_config "PubkeyAuthentication" "yes" "$SSHD_CONFIG"
update_ssh_config "PermitEmptyPasswords" "no" "$SSHD_CONFIG"
update_ssh_config "ChallengeResponseAuthentication" "no" "$SSHD_CONFIG"
update_ssh_config "UsePAM" "yes" "$SSHD_CONFIG"
update_ssh_config "X11Forwarding" "no" "$SSHD_CONFIG"
update_ssh_config "MaxAuthTries" "3" "$SSHD_CONFIG"
update_ssh_config "ClientAliveInterval" "300" "$SSHD_CONFIG"
update_ssh_config "ClientAliveCountMax" "2" "$SSHD_CONFIG"

# Добавить AllowGroups (более безопасно чем AllowUsers)
if ! grep -q "^AllowGroups" "$SSHD_CONFIG"; then
    echo "AllowGroups $ALLOWED_GROUP" >> "$SSHD_CONFIG"
    log "Added: AllowGroups $ALLOWED_GROUP"
else
    log "AllowGroups already configured"
fi

# Проверить конфигурацию SSH
log "Validating SSH configuration..."
if sshd -t; then
    log "SSH configuration is valid"
else
    log "ERROR: Invalid SSH configuration detected"
    log "Restoring backup..."
    cp "${SSHD_CONFIG}.bak" "$SSHD_CONFIG"
    exit 1
fi

# Перезапустить SSH
log "Restarting SSH service..."
if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
    log "SSH service restarted successfully"
else
    log "ERROR: Failed to restart SSH service"
    exit 1
fi

log "[OK] SSH configured successfully (port $SSH_PORT, root disabled, key-only auth, group: $ALLOWED_GROUP)"
echo "[OK] SSH настроен (порт $SSH_PORT, root off, только ключи, группа: $ALLOWED_GROUP)"
