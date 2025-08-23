# Default Server Setup

A comprehensive, secure server hardening script collection for Ubuntu/Debian systems. This toolkit automates the essential security configurations needed for a production server.

## 🔧 Features

- **User Management**: Creates secure admin user with password prompting
- **SSH Hardening**: Custom port, key-only auth, root login disabled
- **Firewall Protection**: iptables with attack mitigation + IPv6 support
- **Intrusion Prevention**: fail2ban with customizable rules
- **Comprehensive Logging**: All operations logged with timestamps
- **Backup Safety**: Automatic config backups before changes
- **Parameter Validation**: Input validation and error handling
- **Service Verification**: Post-setup health checks

## 📋 Quick Start

### Basic Setup (Default Configuration)
```bash
sudo ./setup.sh
```

### Custom Configuration
```bash
sudo ./setup.sh [USERNAME] [SSH_PORT] [ENABLE_HTTP] [ENABLE_HTTPS] [SSH_KEY_FILE]
```

**Examples:**
```bash
# Custom user and SSH port
sudo ./setup.sh myuser 2222

# Enable web server ports
sudo ./setup.sh admin 2222 true true

# With SSH key file
sudo ./setup.sh admin 2222 false false ~/.ssh/id_rsa.pub

# Full custom setup
sudo ./setup.sh webadmin 2222 true true /path/to/public_key.pub
```

## 📁 Script Details

### `01_user.sh` - User Management
- Creates user with **password prompting** (your requested feature!)
- **SSH key installation** from file (new feature!)
- Configurable username (default: admin)
- Adds user to admin group with sudo privileges
- Validates sudoers configuration
- Input validation for username format
- SSH key validation and fingerprint verification

**Usage:**
```bash
sudo ./01_user.sh [username] [ssh_key_file]
```

### `02_ssh.sh` - SSH Hardening
- Configurable SSH port (default: 2222)
- Disables root login and password authentication
- Enables key-only authentication
- Additional security settings (MaxAuthTries, ClientAlive, etc.)
- Configuration validation before applying
- Automatic backup with timestamps

**Usage:**
```bash
sudo ./02_ssh.sh [port] [allowed_group]
```

### `03_fail2ban.sh` - Intrusion Prevention
- Configurable ban times and retry limits
- SSH protection with aggressive blocking for repeat offenders
- Ready-to-enable rules for web servers
- Configuration testing before activation
- Service status verification

**Usage:**
```bash
sudo ./03_fail2ban.sh [ssh_port] [ban_time] [find_time] [max_retry]
```

### `04_iptables.sh` - Firewall Configuration
- IPv4 and IPv6 support
- Attack mitigation (invalid packets, TCP flags, etc.)
- Rate limiting for SSH connections
- Ping flood protection
- Optional HTTP/HTTPS ports
- Comprehensive logging of dropped packets

**Usage:**
```bash
sudo ./04_iptables.sh [ssh_port] [enable_http] [enable_https]
```

## 🔒 Security Features

### Attack Mitigation
- **TCP Flag attacks**: Blocks malformed packets
- **Connection flooding**: Rate limits SSH connections
- **Ping flooding**: Limits ICMP responses
- **Invalid connections**: Drops malformed traffic
- **Brute force**: fail2ban with progressive banning

### Logging & Monitoring
- Centralized logging in `/var/log/`
- Timestamped entries for all operations
- Service status verification
- Configuration validation
- Backup creation with timestamps

## ⚠️ Important Notes

### Before Running
1. **Run as root**: All scripts require root privileges
2. **Have SSH key ready**: Password auth will be disabled
3. **Note the SSH port**: Default is 2222 (not 22)
4. **Keep session open**: Test SSH before closing current session

### After Setup
1. **Copy SSH key**:
   ```bash
   ssh-copy-id -p [SSH_PORT] [USERNAME]@[SERVER_IP]
   ```

2. **Test connection**:
   ```bash
   ssh -p [SSH_PORT] [USERNAME]@[SERVER_IP]
   ```

3. **Verify services**:
   ```bash
   sudo systemctl status ssh fail2ban
   sudo iptables -L -n
   ```

## 🔧 Configuration Files

### Backup Locations
- SSH: `/etc/ssh/sshd_config.bak.TIMESTAMP`
- fail2ban: `/etc/fail2ban/jail.conf.bak`
- iptables: `/etc/iptables/rules.v4.bak.TIMESTAMP`

### Log Files
- Main setup: `/var/log/server-setup.log`
- User setup: `/var/log/user-setup.log`
- SSH config: `/var/log/ssh-setup.log`
- fail2ban: `/var/log/fail2ban-setup.log`
- iptables: `/var/log/iptables-setup.log`

## 🚨 Troubleshooting

### SSH Connection Issues
1. Check if SSH service is running: `sudo systemctl status ssh`
2. Verify port in config: `sudo grep Port /etc/ssh/sshd_config`
3. Check firewall rules: `sudo iptables -L | grep [PORT]`
4. Review SSH logs: `sudo journalctl -u ssh`

### Service Problems
1. Check service status: `sudo systemctl status [service]`
2. View logs: `sudo journalctl -u [service]`
3. Restore from backup if needed
4. Check configuration files for syntax errors

### Firewall Issues
1. List current rules: `sudo iptables -L -n -v`
2. Check saved rules: `sudo cat /etc/iptables/rules.v4`
3. Restore from backup: `sudo iptables-restore < /etc/iptables/rules.v4.bak.TIMESTAMP`

## 📈 Improvements Made

### Security Enhancements
- ✅ Password prompting for user creation (your request!)
- ✅ Input validation and parameter checking
- ✅ Configuration file validation before applying
- ✅ Comprehensive attack mitigation in iptables
- ✅ IPv6 firewall support
- ✅ SSH connection rate limiting
- ✅ Enhanced fail2ban rules

### Reliability Improvements
- ✅ Automatic backups with timestamps
- ✅ Error handling and rollback capabilities
- ✅ Service verification and health checks
- ✅ Comprehensive logging system
- ✅ Parameter validation and sanitization

### Usability Enhancements
- ✅ Configurable parameters for all scripts
- ✅ Clear progress indicators and summaries
- ✅ Detailed setup instructions and next steps
- ✅ Troubleshooting documentation
- ✅ Consistent logging format across all scripts

## 📝 License

This project is open source. Use at your own risk and always test in a non-production environment first.

---

**⚡ Ready to secure your server? Run `sudo ./setup.sh` and follow the prompts!**