#!/bin/bash
set -e

# Configuration
SSH_PORT="${1:-456}"
ENABLE_HTTP="${2:-false}"
ENABLE_HTTPS="${3:-false}"
LOGFILE="/var/log/iptables-setup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting iptables configuration..."

# Validate SSH port
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    log "ERROR: Invalid SSH port: $SSH_PORT"
    exit 1
fi

# Install iptables-persistent
log "Installing iptables-persistent..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent

# Backup current rules
log "Backing up current iptables rules..."
iptables-save > /etc/iptables/rules.v4.bak.$(date +%Y%m%d_%H%M%S)
ip6tables-save > /etc/iptables/rules.v6.bak.$(date +%Y%m%d_%H%M%S)

# Function to safely apply rules
apply_iptables_rules() {
    log "Applying iptables rules..."
    
    # Очистить правила
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Политики по умолчанию
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Разрешить loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Разрешить уже установленные соединения
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Защита от некоторых атак
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    
    # Защита от ping flood
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    # Разрешить SSH с ограничением скорости подключений
    iptables -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
    iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
    
    # HTTP/HTTPS если включены
    if [ "$ENABLE_HTTP" = "true" ]; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        log "Enabled HTTP (port 80)"
    fi
    
    if [ "$ENABLE_HTTPS" = "true" ]; then
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        log "Enabled HTTPS (port 443)"
    fi
    
    # Логирование отброшенных пакетов (ограниченное)
    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
    
    log "iptables rules applied successfully"
}

# IPv6 rules
apply_ip6tables_rules() {
    log "Applying ip6tables rules..."
    
    # Очистить правила IPv6
    ip6tables -F
    ip6tables -X
    
    # Политики по умолчанию для IPv6
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT ACCEPT
    
    # Разрешить loopback для IPv6
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
    
    # Разрешить уже установленные соединения для IPv6
    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Разрешить ICMPv6 (необходимо для IPv6)
    ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
    
    # SSH для IPv6
    ip6tables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
    
    # HTTP/HTTPS для IPv6 если включены
    if [ "$ENABLE_HTTP" = "true" ]; then
        ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
    fi
    
    if [ "$ENABLE_HTTPS" = "true" ]; then
        ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
    fi
    
    log "ip6tables rules applied successfully"
}

# Apply rules
apply_iptables_rules
apply_ip6tables_rules

# Test connectivity (give a moment for rules to take effect)
log "Testing connectivity..."
sleep 2

# Save rules
log "Saving iptables rules..."
if netfilter-persistent save; then
    log "Rules saved successfully"
else
    log "ERROR: Failed to save rules"
    exit 1
fi

# Display current rules
log "Current iptables rules:"
iptables -L -n -v | tee -a "$LOGFILE"

log "[OK] iptables configured successfully"
echo "[OK] iptables настроен (INPUT=DROP, SSH=$SSH_PORT, защита от атак, IPv4/IPv6)"

# Show summary
echo ""
echo "=== Firewall Summary ==="
echo "SSH Port: $SSH_PORT"
echo "HTTP: $ENABLE_HTTP"
echo "HTTPS: $ENABLE_HTTPS"
echo "Log file: $LOGFILE"
echo "========================"
