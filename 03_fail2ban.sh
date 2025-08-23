#!/bin/bash
set -e

# Configuration
SSH_PORT="${1:-456}"
BAN_TIME="${2:-3600}"
FIND_TIME="${3:-600}"
MAX_RETRY="${4:-3}"
LOGFILE="/var/log/fail2ban-setup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting Fail2ban setup..."

# Validate parameters
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    log "ERROR: Invalid SSH port: $SSH_PORT"
    exit 1
fi

if ! [[ "$BAN_TIME" =~ ^[0-9]+$ ]] || [ "$BAN_TIME" -lt 60 ]; then
    log "ERROR: Invalid ban time: $BAN_TIME (minimum 60 seconds)"
    exit 1
fi

# Update package list and install fail2ban
log "Updating package list..."
apt update

log "Installing fail2ban..."
apt install -y fail2ban

# Create backup of original config
if [ -f /etc/fail2ban/jail.conf ] && [ ! -f /etc/fail2ban/jail.conf.bak ]; then
    log "Creating backup of original jail.conf..."
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak
fi

# Create jail.local if it doesn't exist
if [ ! -f /etc/fail2ban/jail.local ]; then
    log "Creating jail.local..."
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
else
    log "jail.local already exists"
fi

# Create custom SSH jail configuration
log "Configuring SSH jail..."
cat > /etc/fail2ban/jail.d/sshd.conf <<EOF
# Custom SSH jail configuration
[sshd]
enabled = true
port    = $SSH_PORT
logpath = %(sshd_log)s
backend = systemd
bantime = $BAN_TIME
findtime = $FIND_TIME
maxretry = $MAX_RETRY

# Additional protection
[sshd-ddos]
enabled = true
port    = $SSH_PORT
logpath = %(sshd_log)s
backend = systemd
bantime = $BAN_TIME
findtime = $FIND_TIME
maxretry = 2
EOF

# Create additional jails for common attacks
log "Creating additional protection jails..."
cat > /etc/fail2ban/jail.d/additional.conf <<EOF
# Additional protection
[apache-auth]
enabled = false
port    = http,https
logpath = %(apache_error_log)s

[apache-badbots]
enabled = false
port    = http,https
logpath = %(apache_access_log)s
bantime = 86400
maxretry = 1

[apache-noscript]
enabled = false
port    = http,https
logpath = %(apache_access_log)s
maxretry = 6

[apache-overflows]
enabled = false
port    = http,https
logpath = %(apache_error_log)s
maxretry = 2

[nginx-http-auth]
enabled = false
port    = http,https
logpath = %(nginx_error_log)s

[nginx-limit-req]
enabled = false
port    = http,https
logpath = %(nginx_error_log)s
maxretry = 10

[postfix]
enabled = false
port    = smtp,465,submission
logpath = %(postfix_log)s
backend = systemd
EOF

# Test configuration
log "Testing fail2ban configuration..."
if fail2ban-client -t; then
    log "Fail2ban configuration is valid"
else
    log "ERROR: Invalid fail2ban configuration"
    exit 1
fi

# Enable and start fail2ban
log "Enabling and starting fail2ban service..."
systemctl enable fail2ban
systemctl restart fail2ban

# Wait a moment for service to start
sleep 2

# Check if service is running
if systemctl is-active --quiet fail2ban; then
    log "Fail2ban service is running"
    
    # Show jail status
    log "Active jails:"
    fail2ban-client status | tee -a "$LOGFILE"
else
    log "ERROR: Fail2ban service failed to start"
    exit 1
fi

log "[OK] Fail2ban installed and configured successfully"
echo "[OK] Fail2ban установлен и настроен для SSH (порт $SSH_PORT, ban: ${BAN_TIME}s, retry: $MAX_RETRY)"
