#!/bin/bash

# Script to monitor WiFi connection and fallback to AP mode if connection fails
# This script checks if the device is connected to WiFi and has internet access
# If not connected after a timeout period, it switches back to AP mode

CONNECTION_TIMEOUT=300  # 5 minutes in seconds
CHECK_INTERVAL=30       # Check every 30 seconds
LOG_FILE="/var/log/wifi-connection-monitor.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_internet_connectivity() {
    # Check if we can ping a reliable server
    if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
        return 0  # Connected
    else
        return 1  # Not connected
    fi
}

check_wifi_connected() {
    # Check if wlan0 has an IP address and is connected
    if ip addr show wlan0 | grep -q "inet " && iwgetid wlan0 > /dev/null 2>&1; then
        return 0  # Connected
    else
        return 1  # Not connected
    fi
}

switch_to_ap_mode() {
    log_message "Switching back to Access Point mode..."
    
    # Stop WiFi connection monitor to prevent loops
    systemctl stop wifi-connection-monitor.service || true
    
    # Stop wpa_supplicant
    systemctl stop wpa_supplicant || true
    
    # Restore static IP configuration
    if ! grep -q "interface wlan0" /etc/dhcpcd.conf; then
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
    systemctl enable hostapd
    systemctl enable dnsmasq
    systemctl start hostapd
    systemctl start dnsmasq
    
    # Start captive portal server
    systemctl start access-point-server || true
    
    log_message "Access Point mode activated. SSID: Splines Raspi AP"
}

# Main monitoring loop
log_message "WiFi connection monitor started"
log_message "Connection timeout: ${CONNECTION_TIMEOUT} seconds"

START_TIME=$(date +%s)
LAST_CONNECTED_TIME=$(date +%s)

while true; do
    if check_wifi_connected && check_internet_connectivity; then
        # Connected and has internet
        LAST_CONNECTED_TIME=$(date +%s)
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        
        if [ $ELAPSED -lt 60 ]; then
            # Still in initial connection phase, log less frequently
            sleep $CHECK_INTERVAL
            continue
        fi
        
        # Log successful connection every 5 minutes
        if [ $((ELAPSED % 300)) -lt $CHECK_INTERVAL ]; then
            log_message "WiFi connection is active and internet connectivity confirmed"
        fi
    else
        # Not connected or no internet
        CURRENT_TIME=$(date +%s)
        TIME_SINCE_CONNECTED=$((CURRENT_TIME - LAST_CONNECTED_TIME))
        
        if [ $TIME_SINCE_CONNECTED -ge $CONNECTION_TIMEOUT ]; then
            log_message "WiFi connection lost or no internet for ${TIME_SINCE_CONNECTED} seconds"
            log_message "Timeout reached (${CONNECTION_TIMEOUT}s), switching to AP mode"
            switch_to_ap_mode
            break
        else
            log_message "WiFi connection issue detected. Time since last connection: ${TIME_SINCE_CONNECTED}s (timeout: ${CONNECTION_TIMEOUT}s)"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
