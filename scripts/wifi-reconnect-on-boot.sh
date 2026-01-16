#!/bin/bash

# Script to attempt WiFi reconnection on boot
# This script runs at boot time and tries to connect to the saved WiFi network
# If connection fails after a timeout, it switches to AP mode

LOG_FILE="/var/log/wifi-reconnect.log"
WIFI_SSID_FILE="/etc/raspi-captive-portal/wifi_ssid"
WIFI_PASSWORD_FILE="/etc/raspi-captive-portal/wifi_password"
CONNECTION_TIMEOUT=180  # 3 minutes

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if WiFi credentials exist
if [ ! -f "$WIFI_SSID_FILE" ] || [ ! -f "$WIFI_PASSWORD_FILE" ]; then
    log_message "No saved WiFi credentials found. Starting in AP mode."
    exit 0
fi

SSID=$(cat "$WIFI_SSID_FILE")
PASSWORD=$(cat "$WIFI_PASSWORD_FILE")

log_message "Attempting to connect to saved WiFi network: $SSID"

# Wait for network services to be ready
sleep 10

# Check if already connected
check_connection() {
    if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for connection with timeout
START_TIME=$(date +%s)
while [ $(($(date +%s) - START_TIME)) -lt $CONNECTION_TIMEOUT ]; do
    if check_connection; then
        log_message "Successfully connected to WiFi network: $SSID"
        log_message "Internet connectivity confirmed. Starting connection monitor."
        
        # Start the connection monitor service
        systemctl start wifi-connection-monitor.service || true
        
        exit 0
    fi
    
    sleep 5
done

# Connection failed, switch to AP mode
log_message "Failed to connect to WiFi network after ${CONNECTION_TIMEOUT} seconds"
log_message "Switching to Access Point mode..."

# Execute the switch to AP mode
/usr/local/bin/switch-to-ap-mode.sh

exit 0
