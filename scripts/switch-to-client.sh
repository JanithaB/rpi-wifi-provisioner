#!/bin/bash

echo "Switching to Client Mode..."

# Stop AP services
echo "Stopping AP services..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo pkill -f portal_server.py

# Clear iptables rules
echo "Clearing firewall rules..."
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F
sudo netfilter-persistent save

# Reconfigure wlan0 for client mode
echo "Reconfiguring wlan0 interface..."
sudo ip addr flush dev wlan0
sudo ip link set wlan0 down
sleep 1

# Re-enable NetworkManager management of wlan0
echo "Configuring NetworkManager to manage wlan0..."
sudo rm -f /etc/NetworkManager/conf.d/unmanaged.conf
sudo systemctl reload NetworkManager

# Wait for NetworkManager to take over
sleep 3

# Bring up wlan0 for NetworkManager
sudo ip link set wlan0 up
sleep 1

echo ""
echo "✓ Client Mode activated!"
echo "✓ NetworkManager is now managing wlan0"
echo "✓ Ready to connect to WiFi network"
echo ""