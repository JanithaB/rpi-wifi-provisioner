#!/bin/bash

# Script to switch from Access Point mode to WiFi client mode
# This script stops AP services, configures wpa_supplicant, and connects to the specified WiFi network

SSID="$1"
PASSWORD="$2"

if [ -z "$SSID" ]; then
    echo "Usage: $0 <SSID> [PASSWORD]"
    echo "Note: PASSWORD is optional for open networks"
    exit 1
fi

echo "Switching from AP mode to WiFi client mode..."
echo "Connecting to network: $SSID"

# Stop AP services
echo "Stopping Access Point services..."
systemctl stop hostapd
systemctl stop dnsmasq
systemctl disable hostapd
systemctl disable dnsmasq

# Stop and disable the captive portal server (will be restarted if needed)
systemctl stop access-point-server || true

# Remove static IP configuration for wlan0 in dhcpcd.conf
echo "Removing static IP configuration..."
sed -i '/^interface wlan0$/,/^$/d' /etc/dhcpcd.conf
sed -i '/^    static ip_address=192.168.4.1\/24$/d' /etc/dhcpcd.conf
sed -i '/^    nohook wpa_supplicant$/d' /etc/dhcpcd.conf

# Create wpa_supplicant configuration if it doesn't exist
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# Get country code from hostapd.conf if available, default to DE
COUNTRY_CODE="DE"
if [ -f "/etc/hostapd/hostapd.conf" ]; then
    HOSTAPD_COUNTRY=$(grep "^country_code=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
    if [ -n "$HOSTAPD_COUNTRY" ]; then
        COUNTRY_CODE="$HOSTAPD_COUNTRY"
    fi
fi

# Check if wpa_supplicant.conf exists, if not create it
if [ ! -f "$WPA_SUPPLICANT_CONF" ]; then
    echo "Creating wpa_supplicant.conf..."
    cat > "$WPA_SUPPLICANT_CONF" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY_CODE
EOF
else
    # Update country code if it exists in the file
    if grep -q "^country=" "$WPA_SUPPLICANT_CONF"; then
        sed -i "s/^country=.*/country=$COUNTRY_CODE/" "$WPA_SUPPLICANT_CONF"
    else
        # Add country code if it doesn't exist
        sed -i "/^ctrl_interface=/a country=$COUNTRY_CODE" "$WPA_SUPPLICANT_CONF"
    fi
fi

# Add network configuration to wpa_supplicant.conf
# Remove existing network entry for this SSID if it exists
sed -i "/network={/,/}/ { /ssid=\"$SSID\"/,/}/d; }" "$WPA_SUPPLICANT_CONF"

# Add new network configuration at the end
# Handle open networks (no password) vs secured networks
if [ -z "$PASSWORD" ]; then
    # Open network - no password required
    cat >> "$WPA_SUPPLICANT_CONF" << EOF

network={
    ssid="$SSID"
    key_mgmt=NONE
    priority=1
}
EOF
else
    # Secured network - password required
    cat >> "$WPA_SUPPLICANT_CONF" << EOF

network={
    ssid="$SSID"
    psk="$PASSWORD"
    priority=1
}
EOF
fi

# Save WiFi credentials for fallback script
mkdir -p /etc/raspi-captive-portal
echo "$SSID" > /etc/raspi-captive-portal/wifi_ssid
echo "$PASSWORD" > /etc/raspi-captive-portal/wifi_password

# Restart dhcpcd to apply network changes
echo "Restarting network services..."
systemctl restart dhcpcd

# Wait a moment for services to restart
sleep 3

# Enable wpa_supplicant
systemctl enable wpa_supplicant
systemctl restart wpa_supplicant

# Wait for connection
echo "Waiting for WiFi connection..."
sleep 10

# Check connection status
if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
    echo "Successfully connected to WiFi network: $SSID"
    echo "Internet connectivity confirmed."
else
    echo "Warning: Connected to WiFi but no internet connectivity detected."
    echo "The device will attempt to reconnect on boot."
fi

# Enable the WiFi connection monitor service
systemctl enable wifi-connection-monitor.service
systemctl start wifi-connection-monitor.service

echo "WiFi client mode activated. The device will automatically reconnect on boot."
