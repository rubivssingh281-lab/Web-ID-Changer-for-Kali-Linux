#!/bin/bash
clear
# Colors
DEFAULT='\033[0m'
GREEN='\033[1;92m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
YELLOW2='\033[1;93m'
ITALIC='\033[3m'

echo -e "
${YELLOW2} █████ ███████████       █████████  █████   █████   █████████   ██████   █████   █████████  ██████████ ███████████${DEFAULT}
${YELLOW2}░░███ ░░███░░░░░███     ███░░░░░███░░███   ░░███   ███░░░░░███ ░░██████ ░░███   ███░░░░░███░░███░░░░░█░░███░░░░░███${DEFAULT}
${YELLOW2} ░███  ░███    ░███    ███     ░░░  ░███    ░███  ░███    ░███  ░███░███ ░███  ███     ░░░  ░███  █ ░  ░███    ░███${DEFAULT}
${YELLOW2} ░███  ░██████████    ░███          ░███████████  ░███████████  ░███░░███░███ ░███          ░██████    ░██████████${DEFAULT}
${YELLOW2} ░███  ░███░░░░░░     ░███          ░███░░░░░███  ░███░░░░░███  ░███ ░░██████ ░███    █████ ░███░░█    ░███░░░░░███${DEFAULT}
${YELLOW2} ░███  ░███           ░░███     ███ ░███    ░███  ░███    ░███  ░███  ░░█████ ░░███  ░░███  ░███ ░   █ ░███    ░███${DEFAULT}
${YELLOW2} █████ █████           ░░█████████  █████   █████ █████   █████ █████  ░░█████ ░░█████████  ██████████ █████   █████${DEFAULT}
${YELLOW2}░░░░░ ░░░░░             ░░░░░░░░░  ░░░░░   ░░░░░ ░░░░░   ░░░░░ ░░░░░    ░░░░░   ░░░░░░░░░  ░░░░░░░░░░ ░░░░░   ░░░░░${DEFAULT}

                  ${GREEN}${ITALIC}================                                   ${GREEN}${ITALIC}======================
                    ${YELLOW}${ITALIC}Version: ${RED}1.0${RED}                                      ${YELLOW}${ITALIC}Code Author: ${RED}CluelessCodes
                  ${GREEN}${ITALIC}================                                   ${GREEN}${ITALIC}======================

                                 ${YELLOW}${ITALIC}GitHub Profile ${RED}:${DEFAULT}${GREEN} https://github.com/rubivssingh281-lab${DEFAULT}

\033[1;33;44m╔══════════════════════════════════════════════════════════════════╗\033[0m
\033[1;33;44m║  LinkedIn: https://www.linkedin.com/in/saksham-singh-6371133ab  ║\033[0m
\033[1;33;44m╚══════════════════════════════════════════════════════════════════╝\033[0m
"

# ======================================================
# FULL WEB IDENTITY CHANGER - EVERY 120 SECONDS
# ======================================================
# WARNING: Changing identity too fast (<60s) will cause
# Tor rate limiting and network instability.
# 120 seconds is the recommended minimum for reliability.
# ======================================================

# --- CONFIGURATION ---
INTERFACE="eth0"          # Change to interface (wlan0, etc.)
INTERVAL=120              # <--- SET DESIRED INTERVAL (SECONDS)
                          # 30 = unstable, 60 = borderline, 120+ = stable

TOR_CONTROL_PORT="9051"
TOR_SOCKS_PORT="9050"

# --- Helper Functions ---
random_hostname() {
    echo "kali-$(tr -dc 'a-z0-9' < /dev/urandom | fold -w 8 | head -n 1)"
}

get_current_public_ip() {
    curl --socks5-hostname 127.0.0.1:$TOR_SOCKS_PORT -s --max-time 5 https://checkip.amazonaws.com 2>/dev/null
}

# --- Start Tor and wait for bootstrap ---
echo "[*] Starting Tor service..."
sudo systemctl start tor
echo "[*] Waiting for Tor to bootstrap (15 seconds)..."
sleep 15

# Verify Tor control port is reachable
if ! nc -z 127.0.0.1 $TOR_CONTROL_PORT 2>/dev/null; then
    echo "[!] Tor control port $TOR_CONTROL_PORT not open. Enable ControlPort and CookieAuthentication in /etc/tor/torrc"
    exit 1
fi

# --- 1. PUBLIC IP ROTATION (IPv4 & IPv6 via Tor) ---
rotate_public_ip() {
    while true; do
        if [ -f /run/tor/control.authcookie ]; then
            COOKIE=$(sudo hexdump -ve '1/1 "%.2x"' /run/tor/control.authcookie)
            {
                echo -e "AUTHENTICATE $COOKIE\r"
                sleep 1
                echo -e "SIGNAL NEWNYM\r"
                sleep 1
                echo -e "QUIT\r"
            } | nc 127.0.0.1 $TOR_CONTROL_PORT > /dev/null 2>&1
            echo "[$(date '+%H:%M:%S')] [✓] New Tor circuit requested."
            
            # Optional: show new public IP
            NEW_IP=$(get_current_public_ip)
            if [ -n "$NEW_IP" ]; then
                echo "[$(date '+%H:%M:%S')] [→] New public IP: $NEW_IP"
            fi
        else
            echo "[!] Tor cookie not found. Is Tor running with CookieAuthentication enabled?"
        fi
        sleep $INTERVAL
    done
}

# --- 2. MAC & LOCAL IP ROTATION (IPv4) ---
rotate_mac_ip() {
    while true; do
        echo "[$(date '+%H:%M:%S')] [⟳] Rotating MAC and local IP on $INTERFACE..."
        
        sudo ip link set $INTERFACE down
        sudo macchanger -r $INTERFACE > /dev/null 2>&1
        sudo ip link set $INTERFACE up
        
        # Try dhclient first, fallback to dhcpcd
        sudo dhclient -v $INTERFACE > /dev/null 2>&1 || sudo dhcpcd -n $INTERFACE > /dev/null 2>&1
        
        # Get new local IPv4
        NEW_LOCAL_IP=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        echo "[$(date '+%H:%M:%S')] [→] New local IPv4: ${NEW_LOCAL_IP:-unknown}"
        
        sleep $INTERVAL
    done
}

# --- 3. IPV6 ROTATION (Privacy Extensions) ---
rotate_ipv6() {
    while true; do
        echo "[$(date '+%H:%M:%S')] [⟳] Rotating IPv6 temporary address..."
        
        # Enable privacy extensions if not already
        if ! sysctl net.ipv6.conf.$INTERFACE.use_tempaddr | grep -q "= 2"; then
            sudo sysctl -w net.ipv6.conf.$INTERFACE.use_tempaddr=2 > /dev/null 2>&1
            sudo sysctl -w net.ipv6.conf.all.use_tempaddr=2 > /dev/null 2>&1
            sudo sysctl -w net.ipv6.conf.default.use_tempaddr=2 > /dev/null 2>&1
        fi
        
        # Force regeneration of temporary IPv6 address
        sudo ip -6 addr flush scope global temporary $INTERFACE 2>/dev/null
        sudo systemctl restart networking > /dev/null 2>&1
        
        # Show new temporary IPv6 (if any)
        NEW_IPV6=$(ip -6 addr show $INTERFACE | grep -i temporary | grep -oP '(?<=inet6\s)[a-f0-9:]+' | head -1)
        echo "[$(date '+%H:%M:%S')] [→] New temporary IPv6: ${NEW_IPV6:-none}"
        
        sleep $INTERVAL
    done
}

# --- 4. HOSTNAME ROTATION ---
rotate_hostname() {
    while true; do
        NEW_HOSTNAME=$(random_hostname)
        echo "[$(date '+%H:%M:%S')] [⟳] Changing hostname to $NEW_HOSTNAME..."
        
        sudo hostnamectl set-hostname "$NEW_HOSTNAME" > /dev/null 2>&1
        sudo sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
        
        echo "[$(date '+%H:%M:%S')] [→] New hostname: $NEW_HOSTNAME"
        sleep $INTERVAL
    done
}

# --- 5. MACHINE ID ROTATION ---
rotate_machine_id() {
    while true; do
        echo "[$(date '+%H:%M:%S')] [⟳] Rotating D-Bus Machine ID..."
        
        sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
        sudo systemd-machine-id-setup > /dev/null 2>&1
        
        NEW_ID=$(cat /etc/machine-id 2>/dev/null)
        echo "[$(date '+%H:%M:%S')] [→] New Machine ID: ${NEW_ID:0:8}..."
        sleep $INTERVAL
    done
}

# --- 6. DHCP CLIENT ID ROTATION ---
rotate_dhcp_client_id() {
    while true; do
        echo "[$(date '+%H:%M:%S')] [⟳] Reconfiguring DHCP client ID..."
        
        # Use MAC as client ID so it changes when MAC changes
        sudo nmcli connection modify "$INTERFACE" ipv4.dhcp-client-id "mac" > /dev/null 2>&1
        sudo nmcli connection down "$INTERFACE" > /dev/null 2>&1
        sudo nmcli connection up "$INTERFACE" > /dev/null 2>&1
        
        echo "[$(date '+%H:%M:%S')] [✓] DHCP client ID reconfigured."
        sleep $INTERVAL
    done
}

# --- 7. BROWSER PROFILE RESET (Firefox/Tor Browser) ---
reset_browser_profile() {
    # Detect which browser is available
    if command -v firefox >/dev/null; then
        BROWSER="firefox"
        PROFILE_DIR="$HOME/.mozilla/firefox"
    elif [ -f "$HOME/tor-browser/Browser/start-tor-browser" ]; then
        BROWSER="tor-browser"
        PROFILE_DIR="$HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
    else
        echo "[!] No supported browser found. Skipping browser profile reset."
        return
    fi
    
    while true; do
        echo "[$(date '+%H:%M:%S')] [⟳] Creating fresh browser profile..."
        
        # Kill running browser instances
        pkill -f "$BROWSER" 2>/dev/null
        sleep 2
        
        if [ "$BROWSER" = "firefox" ]; then
            # Backup and remove old profiles
            TIMESTAMP=$(date +%s)
            firefox -CreateProfile "anon-$TIMESTAMP" > /dev/null 2>&1
            # Set the new profile as default
            sed -i "s/Default=.*/Default=anon-$TIMESTAMP/" ~/.mozilla/firefox/profiles.ini 2>/dev/null
        elif [ "$BROWSER" = "tor-browser" ]; then
            # For Tor Browser, simply delete the profile directory (it will be recreated on launch)
            rm -rf "$PROFILE_DIR" 2>/dev/null
        fi
        
        echo "[$(date '+%H:%M:%S')] [✓] Fresh browser profile ready."
        sleep $INTERVAL
    done
}

# --- 8. BROWSER FINGERPRINT HARDENING (Arkenfox user.js) ---
harden_browser() {
    # Only run once at start, not every cycle, because it's a static configuration
    echo "[*] Applying Arkenfox user.js for anti-fingerprinting..."
    
    ARKENFOX_URL="https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"
    TEMP_JS="/tmp/user.js"
    
    curl -s -o "$TEMP_JS" "$ARKENFOX_URL"
    if [ $? -eq 0 ]; then
        # Apply to Firefox profiles
        for profile in ~/.mozilla/firefox/*.default*; do
            if [ -d "$profile" ]; then
                cp "$TEMP_JS" "$profile/user.js"
                echo "[✓] Hardened user.js applied to $profile"
            fi
        done
        
        # Apply to Tor Browser if present
        if [ -d "$HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default" ]; then
            cp "$TEMP_JS" "$HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/user.js"
            echo "[✓] Hardened user.js applied to Tor Browser"
        fi
    else
        echo "[!] Failed to download Arkenfox user.js"
    fi
}

# --- OPTIONAL: Launch browser with fresh profile ---
launch_browser() {
    while true; do
        sleep $((INTERVAL - 5))  # Launch near the end of each cycle
        if command -v firefox >/dev/null; then
            firefox --new-window about:blank &
        elif [ -f "$HOME/tor-browser/Browser/start-tor-browser" ]; then
            "$HOME/tor-browser/Browser/start-tor-browser" &
        fi
        sleep 5
    done
}

# --- RUN ALL ROTATIONS IN PARALLEL ---
echo "=========================================="
echo "  FULL WEB IDENTITY CHANGER"
echo "  Interval: $INTERVAL seconds"
echo "  Interface: $INTERFACE"
echo "=========================================="

if [ $INTERVAL -lt 60 ]; then
    echo "[!] WARNING: Interval <60 seconds may cause Tor rate limiting and network instability."
    echo "[!] Recommended minimum is 120 seconds for reliable operation."
fi

# Apply browser hardening once at start
harden_browser

# Start all background loops
rotate_public_ip &
rotate_mac_ip &
rotate_ipv6 &
rotate_hostname &
rotate_machine_id &
rotate_dhcp_client_id &
reset_browser_profile &
# launch_browser &   # Uncomment if you want auto-launch

echo "[*] All systems running. Press Ctrl+C to stop."
wait
