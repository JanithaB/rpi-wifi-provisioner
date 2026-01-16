#!/bin/bash

# Script to scan for available WiFi networks
# This script temporarily stops hostapd if needed, scans for networks, then restarts it

INTERFACE="wlan0"
HOSTAPD_WAS_RUNNING=false

# Function to scan networks using iwlist (older method, more compatible)
scan_with_iwlist() {
    # Check if iwlist is available
    if command -v iwlist &> /dev/null; then
        iwlist "$INTERFACE" scan 2>/dev/null | awk '
        BEGIN {
            ssid=""
            encryption="Open"
            quality=0
        }
        /Cell [0-9]+/ {
            if (ssid != "" && ssid != "") {
                print ssid "|" encryption "|" quality
            }
            ssid=""
            encryption="Open"
            quality=0
        }
        /ESSID:/ {
            gsub(/.*ESSID:"/, "")
            gsub(/".*/, "")
            ssid=$0
        }
        /Encryption key:on/ {
            encryption="WPA/WPA2"
        }
        /Quality=/ {
            match($0, /Quality=([0-9]+)\/([0-9]+)/, arr)
            if (arr[1] != "" && arr[2] != "") {
                quality=int((arr[1]/arr[2])*100)
            }
        }
        END {
            if (ssid != "" && ssid != "") {
                print ssid "|" encryption "|" quality
            }
        }' | sort -t'|' -k3 -rn
        return $?
    fi
    return 1
}

# Function to scan networks using iw (newer method)
scan_with_iw() {
    # Check if iw is available
    if command -v iw &> /dev/null; then
        iw dev "$INTERFACE" scan 2>/dev/null | awk '
        BEGIN {
            ssid=""
            encryption="Open"
            signal=0
        }
        /BSS / {
            if (ssid != "" && ssid != "") {
                print ssid "|" encryption "|" signal
            }
            ssid=""
            encryption="Open"
            signal=0
        }
        /SSID: / {
            gsub(/.*SSID: /, "")
            ssid=$0
        }
        /signal: / {
            match($0, /signal: (-?[0-9]+)/, arr)
            if (arr[1] != "") {
                # Convert dBm to percentage (rough approximation: -100dBm = 0%, -50dBm = 100%)
                signal=int(100 + arr[1] * 2)
                if (signal < 0) signal = 0
                if (signal > 100) signal = 100
            }
        }
        /capability:.*Privacy/ {
            encryption="WPA/WPA2"
        }
        END {
            if (ssid != "" && ssid != "") {
                print ssid "|" encryption "|" signal
            }
        }' | sort -t'|' -k3 -rn | head -30
        return $?
    fi
    return 1
}

# Check if hostapd is running
if systemctl is-active --quiet hostapd; then
    HOSTAPD_WAS_RUNNING=true
    echo "Stopping hostapd temporarily to scan for networks..." >&2
    systemctl stop hostapd
    sleep 3
fi

# Try scanning with iw first (preferred, more modern)
if scan_with_iw; then
    if [ "$HOSTAPD_WAS_RUNNING" = true ]; then
        systemctl start hostapd
    fi
    exit 0
fi

# If iw fails, try with iwlist
if scan_with_iwlist; then
    if [ "$HOSTAPD_WAS_RUNNING" = true ]; then
        systemctl start hostapd
    fi
    exit 0
fi

# Restart hostapd if we stopped it
if [ "$HOSTAPD_WAS_RUNNING" = true ]; then
    systemctl start hostapd
fi

# If all methods fail, return empty (exit 0 to avoid error, but output nothing)
exit 0
