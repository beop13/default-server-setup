#!/bin/bash
set -e

# Configuration
USERNAME="${1:-admin}"
SSH_PORT="${2:-456}"
ENABLE_HTTP="${3:-false}"
ENABLE_HTTPS="${4:-false}"
SSH_KEY_FILE="${5:-}"
LOGFILE="/var/log/server-setup.log"

# Скрипты должны лежать в той же папке
BASE_DIR="$(dirname "$0")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

log "Starting server setup with parameters:"
log "Username: $USERNAME"
log "SSH Port: $SSH_PORT"
log "Enable HTTP: $ENABLE_HTTP"
log "Enable HTTPS: $ENABLE_HTTPS"
log "SSH Key File: ${SSH_KEY_FILE:-'Not provided'}"

echo "=================================="
echo "🚀 Server Security Setup Script"
echo "=================================="
echo "Username: $USERNAME"
echo "SSH Port: $SSH_PORT"
echo "HTTP: $ENABLE_HTTP | HTTPS: $ENABLE_HTTPS"
echo "SSH Key: ${SSH_KEY_FILE:-'Not provided'}"
echo "Log: $LOGFILE"
echo "=================================="
echo ""

# Validate parameters
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1024 ] || [ "$SSH_PORT" -gt 65535 ]; then
    log "ERROR: Invalid SSH port: $SSH_PORT (must be 1024-65535)"
    exit 1
fi

echo "=== Шаг 0: Обновление системы ==="
log "Updating system packages..."
apt update && apt upgrade -y
log "System updated successfully"

echo ""
echo "=== Шаг 1: Создание пользователя и группы ==="
log "Running user setup script..."
if bash "$BASE_DIR/01_user.sh" "$USERNAME" "$SSH_KEY_FILE"; then
    log "User setup completed successfully"
else
    log "ERROR: User setup failed"
    exit 1
fi

echo ""
echo "=== Шаг 2: Настройка SSH ==="
log "Running SSH configuration script..."
if bash "$BASE_DIR/02_ssh.sh" "$SSH_PORT" "admin"; then
    log "SSH configuration completed successfully"
else
    log "ERROR: SSH configuration failed"
    exit 1
fi

echo ""
echo "=== Шаг 3: Установка Fail2ban ==="
log "Running Fail2ban setup script..."
if bash "$BASE_DIR/03_fail2ban.sh" "$SSH_PORT"; then
    log "Fail2ban setup completed successfully"
else
    log "ERROR: Fail2ban setup failed"
    exit 1
fi

echo ""
echo "=== Шаг 4: Настройка iptables ==="
log "Running iptables configuration script..."
if bash "$BASE_DIR/04_iptables.sh" "$SSH_PORT" "$ENABLE_HTTP" "$ENABLE_HTTPS"; then
    log "iptables configuration completed successfully"
else
    log "ERROR: iptables configuration failed"
    exit 1
fi

echo ""
echo "=== Шаг 5: Финальная проверка ==="
log "Performing final system checks..."

# Check services
services=("ssh" "fail2ban")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null || systemctl is-active --quiet "${service}d" 2>/dev/null; then
        log "✓ Service $service is running"
        echo "✓ $service service: OK"
    else
        log "✗ Service $service is not running"
        echo "✗ $service service: FAILED"
    fi
done

# Check iptables rules
if iptables -L | grep -q "DROP"; then
    log "✓ iptables rules are active"
    echo "✓ Firewall: OK"
else
    log "✗ iptables rules may not be active"
    echo "✗ Firewall: WARNING"
fi

echo ""
echo "=================================="
echo "🎉 Server Setup Complete!"
echo "=================================="
echo ""
echo "📋 Configuration Summary:"
echo "• User: $USERNAME (with sudo access)"
echo "• SSH Port: $SSH_PORT (password auth disabled)"
echo "• Firewall: Active with fail2ban protection"
echo "• HTTP: $ENABLE_HTTP | HTTPS: $ENABLE_HTTPS"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
if [ -n "$SSH_KEY_FILE" ]; then
    echo "1. ✅ SSH key already configured from: $SSH_KEY_FILE"
    echo ""
    echo "2. Test SSH connection BEFORE closing this session:"
    echo "   ssh -p $SSH_PORT $USERNAME@YOUR_SERVER_IP"
    echo ""
    echo "3. If SSH works, you can safely close this session"
else
    echo "1. Copy your SSH public key to the server:"
    echo "   ssh-copy-id -p $SSH_PORT $USERNAME@YOUR_SERVER_IP"
    echo ""
    echo "2. Test SSH connection BEFORE closing this session:"
    echo "   ssh -p $SSH_PORT $USERNAME@YOUR_SERVER_IP"
    echo ""
    echo "3. If SSH works, you can safely close this session"
fi
echo ""
echo "📁 Logs saved to: $LOGFILE"
echo "🔧 Backup configs created with timestamps"
echo ""
echo "=================================="

log "Server setup completed successfully!"
log "Configuration: User=$USERNAME, SSH=$SSH_PORT, HTTP=$ENABLE_HTTP, HTTPS=$ENABLE_HTTPS"
