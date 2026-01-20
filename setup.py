#!/usr/bin/env python3
"""
RPi WiFi Portal - Main Setup Script with Captive Portal
Run this once to install everything
"""

import os
import subprocess
import sys

def run_command(cmd):
    """Run shell command"""
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True)
    return result.returncode == 0

def main():
    print("=" * 50)
    print("RPi WiFi Portal - Installation")
    print("=" * 50)
    
    # Get the script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("\n[1/7] Updating system packages...")
    run_command("sudo apt-get update")
    
    print("\n[2/7] Installing required packages...")
    run_command("sudo apt-get install -y hostapd dnsmasq python3 iw iptables-persistent")
    
    print("\n[3/7] Stopping services...")
    run_command("sudo systemctl stop hostapd")
    run_command("sudo systemctl stop dnsmasq")
    run_command("sudo systemctl disable hostapd")
    run_command("sudo systemctl disable dnsmasq")
    
    print("\n[4/7] Copying configuration files...")
    run_command(f"sudo cp {script_dir}/config/hostapd.conf /etc/hostapd/hostapd.conf")
    run_command(f"sudo cp {script_dir}/config/dnsmasq.conf /etc/dnsmasq.conf")
    run_command('sudo sed -i \'s|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|\' /etc/default/hostapd')
    
    print("\n[5/7] Making scripts executable...")
    run_command(f"chmod +x {script_dir}/scripts/*.sh")
    run_command(f"sudo cp {script_dir}/scripts/*.sh /usr/local/bin/")
    run_command(f"sudo cp {script_dir}/webpage/portal_server.py /usr/local/bin/")
    run_command(f"sudo chmod +x /usr/local/bin/*.sh")
    run_command(f"sudo chmod +x /usr/local/bin/portal_server.py")
    
    print("\n[6/7] Creating webpage directory...")
    run_command("sudo mkdir -p /var/www/portal")
    run_command(f"sudo cp {script_dir}/webpage/index.html /var/www/portal/")
    
    print("\n[7/7] Backing up dhcpcd.conf...")
    run_command("sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup")
    
    print("\n" + "=" * 50)
    print("Installation Complete!")
    print("=" * 50)
    print("\nUsage:")
    print("  Switch to AP mode:     sudo /usr/local/bin/switch-to-ap.sh")
    print("  Switch to Client mode: sudo /usr/local/bin/switch-to-client.sh")
    print("\nWhen in AP mode:")
    print("  SSID: RPi-Setup")
    print("  Security: OPEN (No Password)")
    print("  Portal will auto-open when connected")
    print("\nNote: NetworkManager will be automatically managed during mode switches")
    print("\n")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Please run with sudo: sudo python3 setup.py")
        sys.exit(1)
    main()
    