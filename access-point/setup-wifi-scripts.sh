#!/bin/sh

# Setup WiFi management scripts and services

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Copy scripts to /usr/local/bin
sudo cp "$PROJECT_ROOT/scripts/switch-to-wifi-client.sh" /usr/local/bin/
sudo cp "$PROJECT_ROOT/scripts/wifi-connection-monitor.sh" /usr/local/bin/
sudo cp "$PROJECT_ROOT/scripts/wifi-reconnect-on-boot.sh" /usr/local/bin/
sudo cp "$PROJECT_ROOT/scripts/switch-to-ap-mode.sh" /usr/local/bin/
sudo cp "$PROJECT_ROOT/scripts/scan-wifi-networks.sh" /usr/local/bin/

# Make scripts executable
sudo chmod +x /usr/local/bin/switch-to-wifi-client.sh
sudo chmod +x /usr/local/bin/wifi-connection-monitor.sh
sudo chmod +x /usr/local/bin/wifi-reconnect-on-boot.sh
sudo chmod +x /usr/local/bin/switch-to-ap-mode.sh
sudo chmod +x /usr/local/bin/scan-wifi-networks.sh

# Create directory for WiFi credentials
sudo mkdir -p /etc/raspi-captive-portal

# Setup systemd services
sudo cp "$SCRIPT_DIR/wifi-connection-monitor.service" /etc/systemd/system/
sudo cp "$SCRIPT_DIR/wifi-reconnect-on-boot.service" /etc/systemd/system/

# Enable WiFi reconnect on boot service
sudo systemctl enable wifi-reconnect-on-boot.service

# Reload systemd
sudo systemctl daemon-reload

echo "WiFi management scripts and services installed successfully"
