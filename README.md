# WMS Gateway - Raspberry Pi Captive Portal

A complete WiFi captive portal and access point setup for Raspberry Pi, allowing easy WiFi configuration through a web interface.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi-red.svg)
![OS](https://img.shields.io/badge/OS-Raspberry%20Pi%20OS%2012-green.svg)

## Features

✨ **Complete Access Point Setup** - Turn your Raspberry Pi into a WiFi hotspot  
🌐 **Captive Portal** - Automatic web portal when devices connect  
📱 **Mobile-Friendly UI** - Clean, modern web interface  
🔒 **Secure & Open Networks** - Supports both WPA2 and open WiFi networks  
⚡ **Auto-Detection** - Automatically detects network security type  
🔄 **Easy WiFi Switching** - Connect to any available WiFi network through the portal  
💾 **Persistent Configuration** - Settings survive reboots

## What You Get

When you deploy this project:

1. **Access Point Mode**: Your Raspberry Pi broadcasts a WiFi network (`RPi-Setup`)
2. **Captive Portal**: Devices connecting to the AP are redirected to a configuration page
3. **WiFi Scanner**: Scan and connect to any available WiFi network
4. **Automatic Switching**: Seamlessly switch between AP mode and client mode

## Requirements

### Hardware
- Raspberry Pi 4 (recommended) or Raspberry Pi 3
- MicroSD card (8GB minimum)
- Power supply
- Built-in WiFi adapter (or compatible USB WiFi adapter)

### Software
- **Raspberry Pi OS**: Bookworm (12) - 64-bit (tested)
- **Python**: 3.x (pre-installed)
- **Network Access**: Ethernet connection recommended for initial setup

### Important Notes
⚠️ If connecting via SSH, use **Ethernet connection**, NOT WiFi. The setup will reconfigure WiFi and may lock you out.

## Installation

### 1. Clone the Repository

```bash
cd ~/Documents
git clone https://github.com/JanithaB/raspi-captive-portal.git
cd raspi-captive-portal
```

### 2. Run Initial Setup

The setup script will install all required dependencies and configure the system:

```bash
sudo python3 setup.py
```

This script will:
- Install required packages (`hostapd`, `dnsmasq`, `netfilter-persistent`, etc.)
- Configure network interfaces
- Set up the captive portal web server
- Install scripts to `/usr/local/bin/`
- Copy web files to `/var/www/portal/`
- Enable and start all services

### 3. Verify Installation

After setup completes, check if services are running:

```bash
# Check Access Point
sudo systemctl status hostapd

# Check DHCP/DNS
sudo systemctl status dnsmasq

# Check portal server
ps aux | grep portal_server.py
```

## Configuration

### WiFi Access Point Settings

Edit the hostapd configuration:

```bash
sudo nano /etc/hostapd/hostapd.conf
```

**Key settings to customize:**

```ini
ssid=RPi-Setup                    # Change WiFi network name
wpa_passphrase=raspberry123       # Change WiFi password (min 8 characters)
channel=6                         # WiFi channel (1-11)
country_code=US                   # Your country code
```

### DHCP/DNS Settings

Edit the dnsmasq configuration:

```bash
sudo nano /etc/dnsmasq.conf
```

**Key settings:**

```ini
interface=wlan0
listen-address=192.168.5.1
dhcp-range=192.168.5.100,192.168.5.200,24h
address=/#/192.168.5.1
```

### Network Settings

The default static IP for the Raspberry Pi in AP mode is `192.168.5.1/24`. To change it, modify:

```bash
# Edit the switch-to-ap.sh script
sudo nano scripts/switch-to-ap.sh

# Find and change this line:
sudo ip addr add 192.168.5.1/24 dev wlan0
```

### Portal Customization

#### Change Logo

Replace the logo file:

```bash
sudo cp /path/to/your/logo.png /var/www/portal/logo.png
```

Logo should be 500x500px PNG format for best results.

#### Customize Web Interface

Edit the HTML/CSS:

```bash
sudo nano /var/www/portal/index.html
```

After making changes, restart the portal server:

```bash
sudo pkill -f portal_server.py
sudo /usr/local/bin/portal_server.py &
```

## Usage

### Switch to Access Point Mode

```bash
sudo /usr/local/bin/switch-to-ap.sh
```

This will:
- Configure wlan0 with static IP (192.168.5.1)
- Start hostapd (WiFi AP)
- Start dnsmasq (DHCP/DNS)
- Start the captive portal web server
- Enable iptables rules for captive portal redirection

**Access Point Details:**
- **SSID**: RPi-Setup
- **Password**: raspberry123
- **IP Address**: 192.168.5.1
- **Portal URL**: http://192.168.5.1

### Connect to the Portal

1. **Find the Network**: Look for `RPi-Setup` in your WiFi networks
2. **Connect**: Use password `raspberry123`
3. **Portal Opens**: Your device should automatically open the captive portal
4. **Manual Access**: If not, open a browser and visit any website or http://192.168.5.1

### Configure WiFi

Once connected to the portal:

1. Click **"↻ Refresh Networks"** to scan for available WiFi
2. **Select a network** from the dropdown
3. **Enter password** (field appears automatically for secured networks)
4. Click **"Connect to Network"**

The Raspberry Pi will:
- Switch to client mode
- Connect to the selected WiFi
- Save the connection for future use

### Switch to Client Mode

To manually switch to client mode (connect to existing WiFi):

```bash
sudo /usr/local/bin/switch-to-client.sh
```

This will:
- Stop the access point
- Stop DHCP/DNS services
- Enable NetworkManager to manage wlan0
- Ready to connect to WiFi networks

### Manual WiFi Connection

```bash
# For secured networks
sudo /usr/local/bin/wifi-connect.sh "NetworkName" "password"

# For open networks
sudo /usr/local/bin/wifi-connect.sh "NetworkName" --open
```

## Architecture

### System Components

```
┌─────────────────────────────────────┐
│     Raspberry Pi WiFi Adapter       │
│         (wlan0 interface)           │
└──────────┬─────────────┬────────────┘
           │             │
    ┌──────▼─────┐  ┌───▼────────┐
    │  hostapd   │  │ dnsmasq    │
    │ (WiFi AP)  │  │ (DHCP/DNS) │
    └──────┬─────┘  └───┬────────┘
           │             │
    ┌──────▼─────────────▼────────┐
    │      iptables (NAT)          │
    │  HTTP/HTTPS → 192.168.5.1:80 │
    └──────────┬───────────────────┘
               │
    ┌──────────▼───────────────────┐
    │   Portal Server (Python)     │
    │   - Serves HTML/CSS/JS       │
    │   - WiFi scanning (/scan)    │
    │   - WiFi connection (/connect)│
    └──────────────────────────────┘
```

### File Structure

```
raspi-captive-portal/
├── config/
│   ├── dnsmasq.conf            # DHCP/DNS configuration
│   └── hostapd.conf            # Access point configuration
├── scripts/
│   ├── switch-to-ap.sh         # Switch to AP mode
│   ├── switch-to-client.sh     # Switch to client mode
│   ├── wifi-connect.sh         # Connect to WiFi
│   └── wifi_setup.sh           # WiFi setup helper
├── webpage/
│   ├── index.html              # Captive portal webpage
│   └── portal_server.py        # Main web server
├── public/
│   └── logo.png                # Portal logo
├── setup.py                    # Installation script
└── README.md                   # This file
```

### Network Flow

1. **Device connects** to `RPi-Setup` WiFi
2. **DHCP assigns IP** (192.168.5.100-200 range)
3. **DNS redirects** all domains to 192.168.5.1
4. **iptables redirects** HTTP/HTTPS to portal
5. **Portal serves** configuration interface
6. **User selects** WiFi network
7. **System switches** to client mode
8. **Connects** to selected network

## Services

### hostapd
- **Purpose**: WiFi Access Point
- **Config**: `/etc/hostapd/hostapd.conf`
- **Control**: `sudo systemctl {start|stop|status} hostapd`

### dnsmasq
- **Purpose**: DHCP and DNS server
- **Config**: `/etc/dnsmasq.conf`
- **Control**: `sudo systemctl {start|stop|status} dnsmasq`
- **Leases**: `/var/lib/misc/dnsmasq.leases`

### portal_server.py
- **Purpose**: Captive portal web interface
- **Location**: `/usr/local/bin/portal_server.py`
- **Port**: 80
- **Logs**: Check with `ps aux | grep portal_server`

## Troubleshooting

### AP Not Visible

**Check if hostapd is running:**
```bash
sudo systemctl status hostapd
```

**Verify wlan0 is in AP mode:**
```bash
sudo iw dev wlan0 info
```

**Restart the AP:**
```bash
sudo systemctl restart hostapd
```

**Check for WiFi blocking:**
```bash
sudo rfkill list wlan
# If blocked:
sudo rfkill unblock wlan
```

### Can't Connect to AP

**Verify password:**
- Default password is `raspberry123` (minimum 8 characters)

**Check DHCP:**
```bash
sudo systemctl status dnsmasq
cat /var/lib/misc/dnsmasq.leases
```

### Portal Not Loading

**Check portal server:**
```bash
ps aux | grep portal_server.py
```

**Restart portal:**
```bash
sudo pkill -f portal_server.py
sudo /usr/local/bin/portal_server.py &
```

**Test portal manually:**
```bash
curl http://192.168.5.1/
```

### WiFi Connection Fails

**Check logs:**
```bash
cat /tmp/wifi-connect.log
sudo journalctl -u NetworkManager -n 50
```

**Verify NetworkManager:**
```bash
systemctl status NetworkManager
```

**Manual connection test:**
```bash
sudo nmcli device wifi list
sudo nmcli device wifi connect "SSID" password "password"
```

### Services Won't Start

**Check NetworkManager conflict:**
```bash
cat /etc/NetworkManager/conf.d/unmanaged.conf
# Should contain:
# [keyfile]
# unmanaged-devices=interface-name:wlan0
```

**Reinstall:**
```bash
cd ~/Documents/raspi-captive-portal
sudo python3 setup.py
```

## Advanced Configuration

### Enable IP Forwarding (Persistent)

To make the Raspberry Pi route traffic:

```bash
sudo nano /etc/sysctl.conf
# Uncomment:
net.ipv4.ip_forward=1

# Apply:
sudo sysctl -p
```

### Add Internet Sharing

To share internet from Ethernet to WiFi clients:

```bash
# Add to switch-to-ap.sh:
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
```

### Custom Portal Domain

To use a custom domain (e.g., wms.gateway):

```bash
# Edit /etc/dnsmasq.conf
address=/wms.gateway/192.168.5.1

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

### Auto-Start on Boot

The services are already configured to start on boot. To verify:

```bash
sudo systemctl is-enabled hostapd
sudo systemctl is-enabled dnsmasq
```

To make AP mode start automatically on boot:

```bash
# Add to /etc/rc.local (before exit 0):
/usr/local/bin/switch-to-ap.sh &
```

## Monitoring

### View Logs

**System logs:**
```bash
sudo journalctl -u hostapd -f
sudo journalctl -u dnsmasq -f
sudo journalctl -u NetworkManager -f
```

**WiFi connection log:**
```bash
tail -f /tmp/wifi-connect.log
```

### Connected Devices

```bash
# Show connected stations
sudo iw dev wlan0 station dump

# Show DHCP leases
cat /var/lib/misc/dnsmasq.leases
```

### Network Statistics

```bash
# WiFi interface info
iwconfig wlan0

# IP configuration
ip addr show wlan0

# Routing table
ip route show
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Change default password** in `/etc/hostapd/hostapd.conf`
2. **Use strong passwords** (minimum 8 characters)
3. **Don't expose the AP** to public areas without additional security
4. **Monitor connections** regularly
5. **Keep the system updated**: `sudo apt update && sudo apt upgrade`

## Uninstallation

To remove the captive portal and restore default settings:

```bash
# Stop and disable services
sudo systemctl stop hostapd dnsmasq
sudo systemctl disable hostapd dnsmasq

# Remove installed files
sudo rm /usr/local/bin/switch-to-ap.sh
sudo rm /usr/local/bin/switch-to-client.sh
sudo rm /usr/local/bin/wifi-connect.sh
sudo rm /usr/local/bin/portal_server.py
sudo rm -rf /var/www/portal

# Remove NetworkManager config
sudo rm /etc/NetworkManager/conf.d/unmanaged.conf
sudo systemctl reload NetworkManager

# Clear iptables rules
sudo iptables -t nat -F
sudo iptables -F
sudo netfilter-persistent save
```

## FAQ

**Q: Can I use this with a USB WiFi adapter?**  
A: Yes, but you need to change `wlan0` to your adapter's interface name in all configuration files.

**Q: Does this work on Raspberry Pi Zero?**  
A: Yes, but performance may be limited. Raspberry Pi 3 or 4 is recommended.

**Q: Can I run this alongside other services?**  
A: Yes, but ensure other services don't use port 80 or conflict with network configuration.

**Q: How do I change the IP address range?**  
A: Edit `/etc/dnsmasq.conf` and change the `dhcp-range` and `listen-address` values.

**Q: Can I use 5GHz WiFi?**  
A: Yes, if your adapter supports it. Change `hw_mode=g` to `hw_mode=a` and set an appropriate channel in hostapd.conf.

## Credits

Based on the excellent work from:
- [Splines/raspi-captive-portal](https://github.com/Splines/raspi-captive-portal)
- Raspberry Pi Foundation documentation
- Community contributions

## License

MIT License - Feel free to use and modify for your projects.

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check the troubleshooting section above
- Review system logs for detailed error messages

---

**Made with ❤️ for WMS Gateway**
