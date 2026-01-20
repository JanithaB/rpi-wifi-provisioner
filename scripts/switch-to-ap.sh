#!/bin/bash

echo "Switching to AP Mode..."

# Stop any existing wpa_supplicant
sudo killall wpa_supplicant 2>/dev/null

# Tell NetworkManager to stop managing wlan0
echo "Configuring NetworkManager to ignore wlan0..."
sudo mkdir -p /etc/NetworkManager/conf.d/
sudo tee /etc/NetworkManager/conf.d/unmanaged.conf > /dev/null <<EOF
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
sudo systemctl reload NetworkManager

# Wait for NetworkManager to release wlan0
sleep 2

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null

# Unblock wlan
sudo rfkill unblock wlan

# Bring down wlan0 first
sudo ip link set wlan0 down
sleep 1

# Bring up wlan0 with static IP
sudo ip link set wlan0 up
sudo ip addr flush dev wlan0
sudo ip addr add 192.168.5.1/24 dev wlan0

# Start/restart dnsmasq
sudo systemctl unmask dnsmasq 2>/dev/null
sudo systemctl enable dnsmasq 2>/dev/null
if ! sudo systemctl restart dnsmasq; then
    echo "Error: Failed to start dnsmasq"
    sudo systemctl status dnsmasq
    exit 1
fi

# Start/restart hostapd
sudo systemctl unmask hostapd 2>/dev/null
sudo systemctl enable hostapd 2>/dev/null
if ! sudo systemctl restart hostapd; then
    echo "Error: Failed to start hostapd"
    sudo systemctl status hostapd
    exit 1
fi

# Give services time to start
sleep 2

# Set up iptables rules for captive portal
# Clear existing rules
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F

# Allow traffic to/from the portal server
sudo iptables -A INPUT -i wlan0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p udp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p udp --dport 67:68 -j ACCEPT

# Redirect all HTTP/HTTPS traffic to the portal
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 192.168.5.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j DNAT --to-destination 192.168.5.1:80

# Save iptables rules to persist across reboots
sudo netfilter-persistent save

# Start web portal
sudo pkill -f portal_server.py
sleep 1
sudo /usr/local/bin/portal_server.py &

echo "AP Mode activated!"
echo "SSID: RPi-Setup"
echo "Security: OPEN (No Password Required)"
echo "Portal: http://192.168.5.1"