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

# Stop the captive portal server (keep it enabled for potential AP fallback)
systemctl stop access-point-server || true

# Remove static IP configuration for wlan0 in dhcpcd.conf
echo "Removing static IP configuration..."
sed -i '/^interface wlan0$/,/^$/d' /etc/dhcpcd.conf
sed -i '/^    static ip_address=192.168.4.1\/24$/d' /etc/dhcpcd.conf
sed -i '/^    nohook wpa_supplicant$/d' /etc/dhcpcd.conf

# Create wpa_supplicant configuration if it doesn't exist
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# Get country code from hostapd.conf if available, default to LK
COUNTRY_CODE="LK"
if [ -f "/etc/hostapd/hostapd.conf" ]; then
    HOSTAPD_COUNTRY=$(grep "^country_code=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
    if [ -n "$HOSTAPD_COUNTRY" ]; then
        COUNTRY_CODE="$HOSTAPD_COUNTRY"
    fi
fi

# Backup existing config if it exists
if [ -f "$WPA_SUPPLICANT_CONF" ]; then
    echo "Backing up existing wpa_supplicant.conf..."
    cp "$WPA_SUPPLICANT_CONF" "${WPA_SUPPLICANT_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create fresh wpa_supplicant.conf with proper headers
echo "Creating wpa_supplicant.conf..."
cat > "$WPA_SUPPLICANT_CONF" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY_CODE

EOF

# Set proper permissions (important for persistence)
chmod 600 "$WPA_SUPPLICANT_CONF"
chown root:root "$WPA_SUPPLICANT_CONF"

# Add network configuration to wpa_supplicant.conf
# Handle open networks (no password) vs secured networks
if [ -z "$PASSWORD" ]; then
    # Open network - no password required
    echo "Configuring open network..."
    cat >> "$WPA_SUPPLICANT_CONF" << EOF
network={
    ssid="$SSID"
    key_mgmt=NONE
    priority=1
}
EOF
else
    # Secured network - use wpa_passphrase to generate proper PSK hash
    echo "Generating WiFi configuration with hashed password..."
    
    # Generate the network configuration with hashed PSK
    # wpa_passphrase outputs the config with the hashed password
    wpa_passphrase "$SSID" "$PASSWORD" >> "$WPA_SUPPLICANT_CONF"
    
    # Add priority to the network block we just added
    # Find the last network block and add priority before the closing brace
    sed -i '$s/}/\tpriority=1\n}/' "$WPA_SUPPLICANT_CONF"
fi

# Ensure proper permissions again after writing
chmod 600 "$WPA_SUPPLICANT_CONF"
chown root:root "$WPA_SUPPLICANT_CONF"

echo ""
echo "=== wpa_supplicant.conf content (passwords hidden) ==="
cat "$WPA_SUPPLICANT_CONF" | sed 's/psk=.*/psk=***HIDDEN***/g'
echo "=== End of configuration ==="
echo ""

# Save WiFi credentials for fallback script
mkdir -p /etc/raspi-captive-portal
echo "$SSID" > /etc/raspi-captive-portal/wifi_ssid
echo "$PASSWORD" > /etc/raspi-captive-portal/wifi_password

# Make sure wpa_supplicant config directory has correct permissions
chmod 755 /etc/wpa_supplicant

# Restart dhcpcd to apply network changes
echo "Restarting network services..."
systemctl restart dhcpcd

# Wait a moment for services to restart
sleep 3

# Stop any running wpa_supplicant instances
echo "Stopping existing wpa_supplicant instances..."
killall wpa_supplicant 2>/dev/null || true
sleep 2

# Ensure wpa_supplicant is using the correct config file
# Some systems have multiple wpa_supplicant services
echo "Starting wpa_supplicant..."
systemctl enable wpa_supplicant
systemctl restart wpa_supplicant

# Also try the interface-specific service if it exists
if systemctl list-unit-files | grep -q "wpa_supplicant@wlan0.service"; then
    systemctl enable wpa_supplicant@wlan0
    systemctl restart wpa_supplicant@wlan0
fi

# Wait for wpa_supplicant to start
sleep 3

# Force wpa_supplicant to reload the configuration
echo "Reloading wpa_supplicant configuration..."
wpa_cli -i wlan0 reconfigure 2>/dev/null || true
sleep 2

# Force a scan to find the network
echo "Scanning for networks..."
wpa_cli -i wlan0 scan 2>/dev/null || true
sleep 3

# Get scan results
echo "Looking for SSID: $SSID"
wpa_cli -i wlan0 scan_results 2>/dev/null | grep -i "$SSID" || echo "  Network may not be in range yet"

# Force reconnect
echo "Initiating connection..."
wpa_cli -i wlan0 reassociate 2>/dev/null || true
wpa_cli -i wlan0 reconnect 2>/dev/null || true
sleep 2

# Verify wpa_supplicant is reading the config
echo ""
echo "=== wpa_supplicant status ==="
wpa_cli -i wlan0 status 2>/dev/null || echo "Could not get wpa_supplicant status"
echo ""

# Wait for connection with active monitoring
echo "Connecting to WiFi network: $SSID"
echo "This may take up to 30 seconds..."

MAX_WAIT=30
ELAPSED=0
CONNECTED=false

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if connected to SSID
    if iwgetid wlan0 &> /dev/null; then
        CURRENT_SSID=$(iwgetid wlan0 -r)
        if [ "$CURRENT_SSID" = "$SSID" ]; then
            echo "✓ Connected to SSID: $SSID"
            CONNECTED=true
            break
        fi
    fi
    
    # Show progress
    if [ $((ELAPSED % 5)) -eq 0 ]; then
        echo "  Waiting... ${ELAPSED}s"
    fi
    
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ "$CONNECTED" = true ]; then
    # Wait a bit more for DHCP to assign IP
    echo "Waiting for IP address..."
    sleep 5
    
    # Check if we have an IP
    if ip addr show wlan0 | grep -q "inet "; then
        IP_ADDR=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
        echo "✓ IP Address assigned: $IP_ADDR"
    fi
    
    # Check internet connectivity
    echo "Testing internet connectivity..."
    if ping -c 3 -W 5 8.8.8.8 > /dev/null 2>&1; then
        echo "✓ Successfully connected to WiFi network: $SSID"
        echo "✓ Internet connectivity confirmed!"
    else
        echo "⚠ Connected to WiFi but no internet access detected."
        echo "  This might be normal if your network doesn't provide internet."
    fi
else
    echo "✗ Failed to connect to WiFi network: $SSID"
    echo "  Please check:"
    echo "  - SSID is correct and in range"
    echo "  - Password is correct"
    echo "  - Network is working"
    echo ""
    echo "  View logs: sudo journalctl -u wpa_supplicant -n 50"
    echo "  Check status: sudo wpa_cli -i wlan0 status"
fi

# Only enable monitoring if we successfully connected
if [ "$CONNECTED" = true ]; then
    echo ""
    echo "Enabling WiFi connection monitor..."
    systemctl enable wifi-connection-monitor.service
    systemctl start wifi-connection-monitor.service
    
    echo ""
    echo "════════════════════════════════════════"
    echo "✓ WiFi Client Mode Activated Successfully!"
    echo "════════════════════════════════════════"
    echo "  Network: $SSID"
    echo "  Status: Connected"
    echo "  Monitor: Running"
    echo ""
    echo "The device will automatically:"
    echo "  - Reconnect to this network on boot"
    echo "  - Fall back to AP mode if connection fails"
    echo "════════════════════════════════════════"
else
    echo ""
    echo "════════════════════════════════════════"
    echo "✗ WiFi Connection Failed"
    echo "════════════════════════════════════════"
    echo "Switching back to AP mode..."
    
    # Switch back to AP mode since connection failed
    /usr/local/bin/switch-to-ap-mode.sh
    
    exit 1
fi
