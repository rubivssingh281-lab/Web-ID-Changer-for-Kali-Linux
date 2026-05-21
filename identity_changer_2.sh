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
${YELLOW2} █████ ███████████        █████████  █████   █████   █████████   ██████   █████   █████████  ██████████ ███████████${DEFAULT}
${YELLOW2}░░███ ░░███░░░░░███      ███░░░░░███░░███   ░░███   ███░░░░░███ ░░██████ ░░███   ███░░░░░███░░███░░░░░█░░███░░░░░███${DEFAULT}
${YELLOW2} ░███  ░███     ░███    ███     ░░░  ░███    ░███  ░███    ░███  ░███░███ ░███  ███     ░░░  ░███  █ ░  ░███    ░███${DEFAULT}
${YELLOW2} ░███  ░███      ███   ░███          ░███████████  ░███████████  ░███░░███░███ ░███          ░██████    ░██████████${DEFAULT}
${YELLOW2} ░███  ░███     ░███   ░███          ░███░░░░░███  ░███░░░░░███  ░███ ░░██████ ░███    █████ ░███░░█    ░███░░░░░███${DEFAULT}
${YELLOW2} ░███  ░███     ███    ░░███     ███ ░███    ░███  ░███    ░███  ░███  ░░█████ ░░███  ░░███  ░███ ░   █ ░███    ░███${DEFAULT}
${YELLOW2} █████ ███████████       ░░█████████  █████   █████ █████   █████ █████  ░░█████ ░░█████████  ██████████ █████   █████${DEFAULT}
${YELLOW2}░░░░░ ░░░░░░░░░░     ██    ░░░░░░░░░  ░░░░░   ░░░░░ ░░░░░   ░░░░░ ░░░░░    ░░░░░   ░░░░░░░░░  ░░░░░░░░░░ ░░░░░   ░░░░░${DEFAULT}

                  ${GREEN}${ITALIC}================                                   ${GREEN}${ITALIC}======================
                    ${YELLOW}${ITALIC}Version: ${RED}2.0${RED}                                      ${YELLOW}${ITALIC}Coder : ${RED}CluelessCodes
                  ${GREEN}${ITALIC}================                                   ${GREEN}${ITALIC}======================

                                 ${YELLOW}${ITALIC}GitHub Profile ${RED}:${DEFAULT}${GREEN} https://github.com/rubivssingh281${DEFAULT}

\033[1;33;44m╔══════════════════════════════════════════════════════════════════╗\033[0m
\033[1;33;44m║  LinkedIn: https://www.linkedin.com/in/saksham-singh-6371133ab  ║\033[0m
\033[1;33;44m╚══════════════════════════════════════════════════════════════════╝\033[0m
"
# ====================================================================
# FULL WEB IDENTITY CHANGER - HARDENED FOR KALI (MEDIUM GRADE)
# ====================================================================
# Combines:
#   - Random jitter intervals (evades timing analysis)
#   - OUI-based MAC spoofing (blends with virtual environments)
#   - Kernel & TCP/IP stack hardening (anti-fingerprinting IMP!!)
#   - nftables Tor-only firewall (leak-proof networking IMP!!)
#   - Arkenfox + extra browser prefs (WebGL, canvas, audio, fonts)
#   - RAM disk for browser profile (optional)
#   - dmidecode disable
#   - Forensic log / history wiping on exit
#   - Robust Tor cookie auth with retry
#   - Obfs4 bridge placeholder
# ====================================================================

set -u
set -o pipefail

# ----------------------------- CONFIGURATION -------------------------
INTERFACE="eth0"                 # Active interface
BASE_INTERVAL=200                # Base seconds between rotations
JITTER_PERCENT=30                # ±30% jitter → actual interval 84–156s
TOR_CONTROL_PORT="9051"
TOR_SOCKS_PORT="9050"
TOR_TRANS_PORT="9040"
TOR_DNS_PORT="5353"
USE_RAMDISK=true                 # Run browser profiles in RAM
RAMDISK_SIZE="2G"
RAMDISK_MOUNT="/dev/shm/identity_ramdisk"

WIPE_LOGS_ON_EXIT=true           # Shred logs on exit/panic
WIPE_BASH_HISTORY=true
DISABLE_DMIDECODE=true           # Remove execute permission from dmidecode

# ----------------------------- FUNCTIONS -----------------------------
log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

random_interval() {
    local jitter=$(( RANDOM % (BASE_INTERVAL * JITTER_PERCENT / 100) ))
    local sign=$(( RANDOM % 2 ))
    if [[ $sign -eq 0 ]]; then
        echo $(( BASE_INTERVAL - jitter ))
    else
        echo $(( BASE_INTERVAL + jitter ))
    fi
}

random_hostname() {
    echo "kali-$(tr -dc 'a-z0-9' < /dev/urandom | fold -w 8 | head -n 1)"
}

get_current_public_ip() {
    curl --socks5-hostname 127.0.0.1:$TOR_SOCKS_PORT -s --max-time 5 \
        https://checkip.amazonaws.com 2>/dev/null
}

# One‑time system hardening: kernel, firewall, dmidecode, RAM disk
setup_system() {
    log "[*] Applying kernel hardening..."
    sudo sysctl -w net.ipv4.tcp_timestamps=0
    sudo sysctl -w net.ipv4.tcp_sack=0
    sudo sysctl -w net.ipv4.tcp_window_scaling=1
    sudo sysctl -w net.ipv4.tcp_mtu_probing=0
    sudo sysctl -w net.ipv4.tcp_syncookies=1
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
    sudo sysctl -w kernel.randomize_va_space=2
    sudo sysctl -w kernel.kptr_restrict=2
    sudo sysctl -w kernel.dmesg_restrict=1
    sudo sysctl -w net.ipv4.conf.all.accept_redirects=0
    sudo sysctl -w net.ipv4.conf.all.send_redirects=0
    sudo sysctl -w net.ipv4.conf.all.accept_source_route=0

    log "[*] Enforcing Tor‑only nftables firewall..."
    sudo nft flush ruleset 2>/dev/null || true
    sudo nft add table inet torwall
    sudo nft add chain inet torwall input { type filter hook input priority 0 \; policy drop \; }
    sudo nft add chain inet torwall output { type filter hook output priority 0 \; policy drop \; }
    sudo nft add chain inet torwall forward { type filter hook forward priority 0 \; policy drop \; }
    sudo nft add rule inet torwall input iif lo accept
    sudo nft add rule inet torwall output oif lo accept
    sudo nft add rule inet torwall output tcp dport $TOR_TRANS_PORT accept
    sudo nft add rule inet torwall output udp dport $TOR_DNS_PORT accept
    sudo nft add rule inet torwall output tcp dport $TOR_CONTROL_PORT accept
    sudo nft add rule inet torwall input ct state established,related accept
    sudo nft add rule inet torwall output ct state established,related accept
    sudo nft add rule inet torwall output udp dport 67 accept
    sudo nft add rule inet torwall input udp sport 67 accept
    sudo nft add rule inet torwall output meta skuid debian-tor accept

    if [[ "$DISABLE_DMIDECODE" == true ]] && [[ -x /usr/sbin/dmidecode ]]; then
        sudo chmod 000 /usr/sbin/dmidecode
        log "[✓] dmidecode disabled."
    fi

    if [[ "$USE_RAMDISK" == true ]]; then
        mkdir -p "$RAMDISK_MOUNT"
        if ! mountpoint -q "$RAMDISK_MOUNT"; then
            sudo mount -t tmpfs -o size="$RAMDISK_SIZE" tmpfs "$RAMDISK_MOUNT"
            sudo chown "$USER":"$USER" "$RAMDISK_MOUNT"
        fi
        export TMPDIR="$RAMDISK_MOUNT/tmp"
        mkdir -p "$TMPDIR"
        log "[✓] RAM disk mounted at $RAMDISK_MOUNT"
    fi
}

# Browser hardening
harden_browser_config() {
    log "[*] Embedding hardened browser preferences (Arkenfox + extras)..."
    local TEMP_JS="/tmp/user.js"

    # Arkenfox base (minimal critical subset – you can expand from the official repo)
    cat > "$TEMP_JS" << 'ARKENFOX'
// ===== Arkenfox user.js base =====
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);
user_pref("webgl.disabled", true);
user_pref("media.peerconnection.enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.webaudio.enabled", false);
user_pref("canvas.capturestream.enabled", false);
user_pref("font.system.whitelist", "");
user_pref("font.name.monospace.x-western", "Courier New");
user_pref("font.name.sans-serif.x-western", "Arial");
user_pref("font.name.serif.x-western", "Times New Roman");
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.send_pings", false);
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("dom.maxHardwareConcurrency", 2);
ARKENFOX

    # Extra production overrides (your previous additions)
    cat >> "$TEMP_JS" << 'EXTRAS'
// ===== EXTRA HARDENING =====
user_pref("privacy.window.maxInnerWidth", 1000);
user_pref("privacy.window.maxInnerHeight", 800);
user_pref("privacy.resistFingerprinting.letterboxing", false);
user_pref("media.peerconnection.enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.webaudio.enabled", false);
user_pref("canvas.capturestream.enabled", false);
user_pref("font.system.whitelist", "");
user_pref("font.name.monospace.x-western", "Courier New");
user_pref("font.name.sans-serif.x-western", "Arial");
user_pref("font.name.serif.x-western", "Times New Roman");
user_pref("dom.maxHardwareConcurrency", 2);
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1");
EXTRAS

    # Copy to existing profiles and store for later use
    for profile in ~/.mozilla/firefox/*.default*; do
        [[ -d "$profile" ]] && cp "$TEMP_JS" "$profile/user.js"
    done
    if [[ -d "$HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default" ]]; then
        cp "$TEMP_JS" "$HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/user.js"
    fi
    log "[✓] Browser preferences embedded successfully."
}

# Rotation loops – each sleeps a random interval

rotate_public_ip() {
    while true; do
        # Wait for Tor cookie with retry
        local cookie_found=false
        for i in {1..10}; do
            if [[ -f /run/tor/control.authcookie ]]; then
                cookie_found=true
                break
            fi
            sleep 1
        done
        if $cookie_found; then
            local COOKIE
            COOKIE=$(sudo hexdump -ve '1/1 "%.2x"' /run/tor/control.authcookie)
            {
                echo -e "AUTHENTICATE $COOKIE\r"
                sleep 0.5
                echo -e "SIGNAL NEWNYM\r"
                sleep 0.5
                echo -e "QUIT\r"
            } | nc 127.0.0.1 $TOR_CONTROL_PORT > /dev/null 2>&1
            log "[✓] New Tor circuit requested."
            local NEW_IP
            NEW_IP=$(get_current_public_ip)
            [[ -n "$NEW_IP" ]] && log "[→] New public IP: $NEW_IP"
        else
            log "[!] Tor cookie not available – skipping circuit rotation."
        fi
        sleep $(random_interval)
    done
}

rotate_mac_ip() {
    while true; do
        log "[⟳] Rotating MAC and local IP on $INTERFACE..."
        # OUI‑based MAC: QEMU/KVM virtual NIC (52:54:00)
        local RANDOM_MAC
        RANDOM_MAC=$(printf '52:54:00:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        sudo ip link set "$INTERFACE" down
        sudo macchanger -m "$RANDOM_MAC" "$INTERFACE" > /dev/null 2>&1
        sudo ip link set "$INTERFACE" up
        sudo dhclient -v "$INTERFACE" > /dev/null 2>&1 || sudo dhcpcd -n "$INTERFACE" > /dev/null 2>&1 || true
        local NEW_LOCAL_IP
        NEW_LOCAL_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        log "[→] New local IPv4: ${NEW_LOCAL_IP:-unknown}"
        sleep $(random_interval)
    done
}

rotate_ipv6() {
    while true; do
        log "[⟳] Rotating IPv6 temporary address..."
        sudo sysctl -w net.ipv6.conf."$INTERFACE".use_tempaddr=2 > /dev/null 2>&1
        sudo sysctl -w net.ipv6.conf.all.use_tempaddr=2 > /dev/null 2>&1
        sudo ip -6 addr flush scope global temporary "$INTERFACE" 2>/dev/null || true
        sudo systemctl restart networking > /dev/null 2>&1 || true
        local NEW_IPV6
        NEW_IPV6=$(ip -6 addr show "$INTERFACE" | grep -i temporary | grep -oP '(?<=inet6\s)[a-f0-9:]+' | head -1)
        log "[→] New temporary IPv6: ${NEW_IPV6:-none}"
        sleep $(random_interval)
    done
}

rotate_hostname() {
    while true; do
        local OLD_HOSTNAME=$(hostname)
        local NEW_HOSTNAME=$(random_hostname)
        log "[⟳] Changing hostname to $NEW_HOSTNAME..."

        # 1. Pre-seed /etc/hosts with the new name (and a .localdomain alias)
        #    This guarantees the new name resolves from the very first moment.
        echo "127.0.1.1 $NEW_HOSTNAME $NEW_HOSTNAME.localdomain" | sudo tee -a /etc/hosts >/dev/null

        # 2. Change the system hostname.
        sudo hostnamectl set-hostname "$NEW_HOSTNAME" >/dev/null 2>&1

        # 3. Remove only the old hostname entry to avoid clutter.
        if [[ -n "$OLD_HOSTNAME" ]]; then
            sudo sed -i "/^127\.0\.1\.1\s.*$OLD_HOSTNAME/d" /etc/hosts
        fi

        log "[→] New hostname: $NEW_HOSTNAME"
        sleep $(random_interval)
    done
}

rotate_machine_id() {
    while true; do
        log "[⟳] Rotating D-Bus Machine ID..."
        sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
        sudo systemd-machine-id-setup > /dev/null 2>&1
        local NEW_ID
        NEW_ID=$(cat /etc/machine-id 2>/dev/null)
        log "[→] New Machine ID: ${NEW_ID:0:8}..."
        sleep $(random_interval)
    done
}

rotate_dhcp_client_id() {
    while true; do
        log "[⟳] Reconfiguring DHCP client ID..."
        sudo nmcli connection modify "$INTERFACE" ipv4.dhcp-client-id "mac" > /dev/null 2>&1 || true
        sudo nmcli connection down "$INTERFACE" > /dev/null 2>&1 || true
        sudo nmcli connection up "$INTERFACE" > /dev/null 2>&1 || true
        log "[✓] DHCP client ID reconfigured."
        sleep $(random_interval)
    done
}

reset_browser_profile() {
    # Detect browser
    local BROWSER=""
    local PROFILE_DIR=""
    if command -v firefox >/dev/null; then
        BROWSER="firefox"
        if [[ "$USE_RAMDISK" == true ]]; then
            PROFILE_DIR="$RAMDISK_MOUNT/firefox_profile"
            mkdir -p "$PROFILE_DIR"
            export XDG_DATA_HOME="$RAMDISK_MOUNT/.local/share"
            export XDG_CONFIG_HOME="$RAMDISK_MOUNT/.config"
        else
            PROFILE_DIR="$HOME/.mozilla/firefox"
        fi
    elif [[ -f "$HOME/tor-browser/Browser/start-tor-browser" ]]; then
        BROWSER="tor-browser"
        PROFILE_DIR="$HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
    else
        log "[!] No supported browser found. Skipping profile rotation."
        return
    fi

    while true; do
        log "[⟳] Creating fresh browser profile..."
        pkill -f "$BROWSER" 2>/dev/null || true
        sleep 2

        if [[ "$BROWSER" == "firefox" ]]; then
            local TIMESTAMP
            TIMESTAMP=$(date +%s)
            firefox -CreateProfile "anon-$TIMESTAMP" > /dev/null 2>&1 || true
            sed -i "s/Default=.*/Default=anon-$TIMESTAMP/" ~/.mozilla/firefox/profiles.ini 2>/dev/null || true
            # Copy hardened user.js into new profile
            local NEW_PROFILE
            NEW_PROFILE=$(find ~/.mozilla/firefox -maxdepth 1 -name "*anon-$TIMESTAMP*" | head -1)
            if [[ -n "$NEW_PROFILE" && -f "/tmp/user.js" ]]; then
                cp "/tmp/user.js" "$NEW_PROFILE/user.js"
                rm -rf "$NEW_PROFILE/storage" "$NEW_PROFILE/serviceworker" "$NEW_PROFILE/cache2" 2>/dev/null || true
            fi
        elif [[ "$BROWSER" == "tor-browser" ]]; then
            rm -rf "$PROFILE_DIR" 2>/dev/null || true
            mkdir -p "$PROFILE_DIR"
            if [[ -f "/tmp/user.js" ]]; then
                cp "/tmp/user.js" "$PROFILE_DIR/user.js"
            fi
        fi
        log "[✓] Fresh browser profile ready."
        sleep $(random_interval)
    done
}

# Forensic cleanup – called on exit
wipe_forensic_traces() {
    log "[!] PANIC / EXIT: Wiping forensic traces..."

    # Journald
    sudo journalctl --rotate 2>/dev/null || true
    sudo journalctl --vacuum-time=1s 2>/dev/null || true
    sudo rm -rf /var/log/journal/* 2>/dev/null || true

    # Common logs
    for log in /var/log/{syslog,auth.log,kern.log,dpkg.log,apt/history.log}; do
        if [[ -f "$log" ]]; then
            sudo shred -zu -n 3 "$log" 2>/dev/null || true
        fi
    done

    # Shell history
    if [[ "$WIPE_BASH_HISTORY" == true ]]; then
        history -c 2>/dev/null || true
        history -w 2>/dev/null || true
        shred -zu -n 3 ~/.bash_history 2>/dev/null || true
        shred -zu -n 3 ~/.zsh_history 2>/dev/null || true
    fi

    # Temp & cache
    sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    rm -rf ~/.cache/* ~/.local/share/recently-used.xbel 2>/dev/null || true

    # udev / NetworkManager state
    sudo rm -f /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null || true
    sudo rm -f /var/lib/NetworkManager/NetworkManager.state 2>/dev/null || true

    # Remove temporary user.js
    rm -f /tmp/user.js 2>/dev/null || true

    log "[✓] Forensic traces wiped."
}

# Exit trap – restores system to a clean state
cleanup() {
    log "[*] Shutting down securely..."

    # Kill browsers
    pkill -f "firefox|tor-browser" 2>/dev/null || true

    # Flush firewall to restore normal connectivity
    sudo nft flush ruleset 2>/dev/null || true

    # Delete browser profiles (disk and RAM)
    rm -rf ~/.mozilla/firefox/*anon-* 2>/dev/null || true
    if [[ "$USE_RAMDISK" == true ]]; then
        sudo umount "$RAMDISK_MOUNT" 2>/dev/null || true
    fi
    rm -rf ~/tor-browser/Browser/TorBrowser/Data/Browser/profile.default 2>/dev/null || true

    # Restore machine-id and hostname to known state
    sudo rm -f /var/lib/dbus/machine-id /etc/machine-id
    sudo systemd-machine-id-setup > /dev/null 2>&1 || true
    sudo hostnamectl set-hostname "kali" 2>/dev/null || true
    sudo sed -i '/^127\.0\.1\.1/d' /etc/hosts
    echo "127.0.1.1 kali" | sudo tee -a /etc/hosts > /dev/null

    # Optionally re-enable dmidecode
    if [[ "$DISABLE_DMIDECODE" == true ]] && [[ -f /usr/sbin/dmidecode ]]; then
        sudo chmod 755 /usr/sbin/dmidecode 2>/dev/null || true
    fi

    # Wipe logs if configured
    [[ "$WIPE_LOGS_ON_EXIT" == true ]] && wipe_forensic_traces

    log "[✓] System restored. Exiting."
}

# ========================= MAIN =========================
trap cleanup EXIT INT TERM

log "=========================================="
log "  GENERAL IDENTITY CHANGER (ONLY FOR TESTS)"
log "  Base interval: $BASE_INTERVAL s (+-$JITTER_PERCENT% jitter)"
log "  Interface: $INTERFACE"
log "  Firewall: nftables Tor‑only"
log "  Browser hardening: Arkenfox + extra"
log "  RAM disk: $USE_RAMDISK"
log "=========================================="

# One‑time system preparation
setup_system
harden_browser_config

# Start Tor
log "[*] Starting Tor service..."
sudo systemctl start tor
log "[*] Waiting for Tor bootstrap (15s)..."
sleep 15

# Verify control port
if ! nc -z 127.0.0.1 "$TOR_CONTROL_PORT" 2>/dev/null; then
    log "[!] Tor control port $TOR_CONTROL_PORT not open. Check /etc/tor/torrc."
    exit 1
fi

# Launch all rotation loops in background
rotate_public_ip &
rotate_mac_ip &
rotate_ipv6 &
rotate_hostname &
rotate_machine_id &
rotate_dhcp_client_id &
reset_browser_profile &

log "[*] All systems running. Press Ctrl+C to stop cleanly."
wait
