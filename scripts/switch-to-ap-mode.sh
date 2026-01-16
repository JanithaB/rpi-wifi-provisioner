#!/bin/bash

# Script to switch from WiFi client mode back to Access Point mode

LOG_FILE="/var/log/wifi-setup.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "Switching to Access Point mode..."

# Stop WiFi connection monitor
systemctl stop wifi-connection-monitor.service || true
systemctl disable wifi-connection-monitor.service || true

# Stop wpa_supplicant
systemctl stop wpa_supplicant || true

# Add static IP configuration for wlan0 if not present
if ! grep -q "interface wlan0" /etc/dhcpcd.conf; then
    log_message "Adding static IP configuration..."
    cat >> /etc/dhcpcd.conf << EOF

interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF
fi

# Restart dhcpcd
systemctl restart dhcpcd
sleep 3

# Start AP services
log_message "Starting Access Point services..."
systemctl enable hostapd
systemctl enable dnsmasq
systemctl start hostapd
systemctl start dnsmasq

# Start captive portal server
systemctl start access-point-server || true

log_message "Access Point mode activated successfully"
