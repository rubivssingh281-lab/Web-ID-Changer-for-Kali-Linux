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
${YELLOW2} ░███  ░███      ███   ░███          ░███████████  ░███████████  ░███░░███░███ ░███          ░██████    ░██████████ ${DEFAULT}
${YELLOW2} ░███  ░███     ░███   ░███          ░███░░░░░███  ░███░░░░░███  ░███ ░░██████ ░███    █████ ░███░░█    ░███░░░░░███${DEFAULT}
${YELLOW2} ░███  ░███     ███    ░░███     ███ ░███    ░███  ░███    ░███  ░███  ░░█████ ░░███  ░░███  ░███ ░   █ ░███    ░███${DEFAULT}
${YELLOW2} █████ ███████████       ░░█████████  █████   █████ █████   █████ █████  ░░█████ ░░█████████  ██████████ █████   █████${DEFAULT}
${YELLOW2}░░░░░ ░░░░░░░░░░     ██    ░░░░░░░░░  ░░░░░   ░░░░░ ░░░░░   ░░░░░ ░░░░░    ░░░░░   ░░░░░░░░░  ░░░░░░░░░░ ░░░░░   ░░░░░${DEFAULT}

                  ${GREEN}${ITALIC}================                                   ${GREEN}${ITALIC}======================
                    ${YELLOW}${ITALIC}Version: ${RED}2.1 (hardened)${RED}                           ${YELLOW}${ITALIC}Coder : ${RED}CluelessCodes
                  ${GREEN}${ITALIC}================                                   ${GREEN}${ITALIC}======================

                                 ${YELLOW}${ITALIC}GitHub Profile ${RED}:${DEFAULT}${GREEN} https://github.com/rubivssingh281${DEFAULT}

\033[1;33;44m╔══════════════════════════════════════════════════════════════════╗\033[0m
\033[1;33;44m║  LinkedIn: https://www.linkedin.com/in/saksham-singh-6371133ab  ║\033[0m
\033[1;33;44m╚══════════════════════════════════════════════════════════════════╝\033[0m
"

# ====================================================================
# FULL WEB IDENTITY CHANGER v2.1 - HARDENED FOR KALI
# ====================================================================
# FIXES vs v2.0:
#   [1] nftables: Added ip tornat NAT table with PREROUTING + OUTPUT
#       REDIRECT rules for true transparent Tor proxying.
#       Without these, non-Tor traffic was simply dropped (no Tor
#       routing at all), breaking the whole point of the firewall.
#   [2] IPv6: Removed rotate_ipv6() — it conflicted with
#       disable_ipv6=1 sysctl. Added per-interface disable instead.
#   [3] DHCP: dhclient -r (release) before renew to clear stale leases.
#   [4] Browser rotation: pgrep wait loop + SIGTERM→SIGKILL escalation
#       before touching profile directory.
#   [5] user.js: Deduplicated entirely. Fixed letterboxing conflict
#       (extras block set it false, overriding the true above it).
#       Cleared no_proxies_on to "" (no proxy bypass allowed).
#   [6] Log wipe: Flush journald with USR2 signal before vacuum.
#   [7] Background PIDs tracked in BGPIDS[] for clean shutdown.
#   [8] MAC rotation: Now cycles 5 OUIs, not just QEMU 52:54:00.
#   [9] Prerequisite check: check_deps() + torrc TransPort warning.
#  [10] Additional kernel hardening: rp_filter, log_martians.
# ====================================================================
#
# REQUIRED /etc/tor/torrc entries (add if missing):
#   TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr IsolateDestPort
#   DNSPort 5353
#   ControlPort 9051
#   CookieAuthentication 1
#
# ====================================================================

set -u
set -o pipefail

# ----------------------------- CONFIGURATION -------------------------
INTERFACE="${INTERFACE:-eth0}"       # Override via env: INTERFACE=wlan0 ./script.sh
BASE_INTERVAL=300                    # Base seconds between identity rotations
JITTER_PERCENT=30                    # ±30% jitter → ~140–260 s actual range
TOR_CONTROL_PORT="9051"
TOR_SOCKS_PORT="9050"
TOR_TRANS_PORT="9040"
TOR_DNS_PORT="5353"
USE_RAMDISK=true
RAMDISK_SIZE="2G"
RAMDISK_MOUNT="/dev/shm/identity_ramdisk"
NETWORK_LOCK="/run/identity_changer_net.lock"
WIPE_LOGS_ON_EXIT=true
WIPE_BASH_HISTORY=true
DISABLE_DMIDECODE=true

# Track background job PIDs for clean shutdown
BGPIDS=()

# ----------------------------- FUNCTIONS -----------------------------
log() {
    echo -e "[$(date '+%H:%M:%S')] $*"
}

die() {
    log "${RED}[✗] FATAL: $* Aborting.${DEFAULT}" >&2
    exit 1
}

random_interval() {
    local max_jitter=$(( BASE_INTERVAL * JITTER_PERCENT / 100 ))
    local jitter=$(( RANDOM % (max_jitter + 1) ))
    if (( RANDOM % 2 == 0 )); then
        echo $(( BASE_INTERVAL - jitter ))
    else
        echo $(( BASE_INTERVAL + jitter ))
    fi
}

random_hostname() {
    local suffix
    suffix=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)
    echo "host-${suffix}"
}

get_current_public_ip() {
    local -a ENDPOINTS=(
        "https://api.ipify.org"
        "https://icanhazip.com"
        "http://checkip.amazonaws.com"
        "https://ipecho.net/plain"
        "https://ifconfig.me/ip"
    )
    local attempts=3
    for (( i=1; i<=attempts; i++ )); do
        for endpoint in "${ENDPOINTS[@]}"; do
            local ip
            ip=$(curl --socks5-hostname "127.0.0.1:${TOR_SOCKS_PORT}" \
                 -s --max-time 15 \
                 "$endpoint" 2>/dev/null | tr -d '[:space:]')
            if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$ip"
                return 0
            fi
        done
        (( i < attempts )) && {
            log "[!] IP probe attempt ${i}/${attempts} failed — retrying in 10s..."
            sleep 10
        }
    done
    echo "unavailable"
}

wait_for_tor_bootstrap() {
    local max_wait=120
    local elapsed=0
    local bootstrap=0

    log "[*] Waiting for Tor SOCKS port to open..."
    while ! nc -z 127.0.0.1 "$TOR_SOCKS_PORT" 2>/dev/null; do
        sleep 2; (( elapsed += 2 ))
        if (( elapsed >= max_wait )); then
            die "Tor SOCKS port ${TOR_SOCKS_PORT} never opened after ${max_wait}s. Check torrc."
        fi
    done
    log "[✓] SOCKS port is open. Polling bootstrap percentage..."

    while (( elapsed < max_wait )); do
        bootstrap=0

        # Method 1: Query control port directly (most reliable)
        if nc -z 127.0.0.1 "$TOR_CONTROL_PORT" 2>/dev/null; then
            local cookie_file="/run/tor/control.authcookie"
            if [[ -f "$cookie_file" ]]; then
                local COOKIE
                COOKIE=$(sudo hexdump -ve '1/1 "%.2x"' "$cookie_file" 2>/dev/null)
                local response
                response=$(printf 'AUTHENTICATE %s\r\nGETINFO status/bootstrap-phase\r\nQUIT\r\n' \
                    "$COOKIE" | nc -q 1 127.0.0.1 "$TOR_CONTROL_PORT" 2>/dev/null)
                bootstrap=$(echo "$response" | grep -oP 'PROGRESS=\K\d+' | head -1)
                bootstrap=${bootstrap:-0}
            fi
        fi

        # Method 2: Tor log files (Kali default paths)
        if (( bootstrap == 0 )); then
            bootstrap=$(cat /var/log/tor/log \
                            /var/log/tor/notices.log \
                            /var/log/tor/debug.log 2>/dev/null \
                        | grep -oP 'Bootstrapped \K\d+' | tail -1)
            bootstrap=${bootstrap:-0}
        fi

        # Method 3: journald with both unit name variants
        if (( bootstrap == 0 )); then
            bootstrap=$(sudo journalctl -u tor -u tor@default \
                            -n 300 --no-pager 2>/dev/null \
                        | grep -oP 'Bootstrapped \K\d+' | tail -1)
            bootstrap=${bootstrap:-0}
        fi

        if (( bootstrap >= 100 )); then
            log "[✓] Tor bootstrapped (100%). Allowing 15s for circuits to stabilise..."
            sleep 15
            return 0    
        fi

        log "[*] Bootstrap: ${bootstrap}% — waiting 5s..."
        sleep 5; (( elapsed += 5 ))
    done

    log "[!] Bootstrap stalled at ${bootstrap}% after ${max_wait}s — proceeding anyway."
}

verify_socks_connectivity() {
    log "[*] Verifying Tor SOCKS5 connectivity..."
    local attempt=1
    while (( attempt <= 3 )); do
        if curl --socks5-hostname "127.0.0.1:${TOR_SOCKS_PORT}" \
                -s --max-time 15 --head \
                "https://check.torproject.org" > /dev/null 2>&1; then
            log "[✓] SOCKS5 connectivity confirmed."
            return 0
        fi
        log "[!] SOCKS5 check failed (attempt ${attempt}/3) — waiting 10s..."
        sleep 10
        (( attempt++ ))
    done
    log "[!] SOCKS5 unresponsive after 3 attempts — proceeding anyway."
}

# ----------------------------- PREREQUISITES -------------------------
check_deps() {
    local missing=()
    for cmd in tor nc macchanger nft ip dhclient hostnamectl shred curl hexdump; do
        command -v "$cmd" > /dev/null 2>&1 || missing+=("$cmd")
    done
    if (( ${#missing[@]} > 0 )); then
        die "Missing dependencies: ${missing[*]}"
    fi

    # Warn if torrc isn't configured for transparent proxying
    if ! grep -qE "^\s*TransPort\s+${TOR_TRANS_PORT}" /etc/tor/torrc 2>/dev/null; then
        log "${YELLOW}[!] WARNING: TransPort ${TOR_TRANS_PORT} not found in /etc/tor/torrc${DEFAULT}"
        log "    Transparent proxying will NOT work without:"
        log "      TransPort ${TOR_TRANS_PORT} IsolateClientAddr IsolateClientProtocol"
        log "      DNSPort ${TOR_DNS_PORT}"
        log "      ControlPort ${TOR_CONTROL_PORT}"
        log "      CookieAuthentication 1"
    fi
}

# ----------------------------- SYSTEM SETUP --------------------------
setup_system() {
    log "[*] Applying kernel hardening..."

    # TCP fingerprinting mitigations
    sudo sysctl -qw net.ipv4.tcp_timestamps=0         # Timestamp-based fingerprinting
    sudo sysctl -qw net.ipv4.tcp_sack=0               # SACK fingerprinting
    sudo sysctl -qw net.ipv4.tcp_window_scaling=1
    sudo sysctl -qw net.ipv4.tcp_mtu_probing=0
    sudo sysctl -qw net.ipv4.tcp_syncookies=1

    # FIX [2]: Disable IPv6 consistently (removed rotate_ipv6 which conflicted)
    sudo sysctl -qw net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -qw net.ipv6.conf.default.disable_ipv6=1
    sudo sysctl -qw "net.ipv6.conf.${INTERFACE}.disable_ipv6=1" 2>/dev/null || true

    # Kernel hardening
    sudo sysctl -qw kernel.randomize_va_space=2
    sudo sysctl -qw kernel.kptr_restrict=2
    sudo sysctl -qw kernel.dmesg_restrict=1

    # Network hardening
    sudo sysctl -qw net.ipv4.conf.all.accept_redirects=0
    sudo sysctl -qw net.ipv4.conf.default.accept_redirects=0
    sudo sysctl -qw net.ipv4.conf.all.send_redirects=0
    sudo sysctl -qw net.ipv4.conf.all.accept_source_route=0
    sudo sysctl -qw net.ipv4.conf.all.log_martians=1   # FIX [10]: log spoofed pkts
    sudo sysctl -qw net.ipv4.conf.all.rp_filter=1      # FIX [10]: reverse path filter

    log "[✓] Kernel hardening applied."

    # ------------------------------------------------------------------
    # FIX [1]: nftables — filter table + NAT table for transparent proxy
    # ------------------------------------------------------------------
    log "[*] Building nftables ruleset (filter + transparent NAT)..."
    sudo nft flush ruleset 2>/dev/null || true

    # --- Filter table: default-drop everything ---
    sudo nft add table inet torwall
    sudo nft add chain inet torwall input  '{ type filter hook input  priority 0; policy drop; }'
    sudo nft add chain inet torwall output '{ type filter hook output priority 0; policy drop; }'
    sudo nft add chain inet torwall forward '{ type filter hook forward priority 0; policy drop; }'

    # Loopback: always allow
    sudo nft add rule inet torwall input  iif lo accept
    sudo nft add rule inet torwall output oif lo accept

    # Established/related connections
    sudo nft add rule inet torwall input  ct state established,related accept
    sudo nft add rule inet torwall output ct state established,related accept

    # DHCP (needed to acquire an address after MAC rotation)
    sudo nft add rule inet torwall output udp dport 67 accept
    sudo nft add rule inet torwall input  udp sport 67 accept

    # Tor process itself can connect out freely (identified by UID)
    sudo nft add rule inet torwall output skuid debian-tor accept

    # Local Tor ports (SOCKS / control / TransPort / DNS) on loopback
    sudo nft add rule inet torwall output \
        ip daddr 127.0.0.1 \
        tcp dport "{ ${TOR_SOCKS_PORT}, ${TOR_CONTROL_PORT}, ${TOR_TRANS_PORT} }" \
        accept
    sudo nft add rule inet torwall output \
        ip daddr 127.0.0.1 \
        udp dport "${TOR_DNS_PORT}" \
        accept

    # --- NAT table: redirect all traffic through Tor transparently ---
    # Without this table the filter rules just drop non-Tor traffic;
    # apps never reach the network. This NAT redirects before dropping.
    sudo nft add table ip tornat
    sudo nft add chain ip tornat prerouting '{ type nat hook prerouting priority -100; }'
    sudo nft add chain ip tornat output     '{ type nat hook output     priority -100; }'

    # Exemptions: Tor's own traffic and loopback must not be redirected
    sudo nft add rule ip tornat output skuid debian-tor      return
    sudo nft add rule ip tornat output ip daddr 127.0.0.0/8  return
    sudo nft add rule ip tornat output ip daddr 192.168.0.0/16 return  # local LAN
    sudo nft add rule ip tornat output ip daddr 10.0.0.0/8     return  # local LAN
    sudo nft add rule ip tornat output ip daddr 172.16.0.0/12  return  # local LAN

    # DNS → Tor DNSPort (prevents DNS leaks outside Tor)
    sudo nft add rule ip tornat output udp dport 53 \
        redirect to ":${TOR_DNS_PORT}"

    # All other TCP SYNs → TransPort (transparent proxy)
    sudo nft add rule ip tornat output \
        tcp flags '& (fin|syn|rst|ack) == syn' \
        redirect to ":${TOR_TRANS_PORT}"

    log "[✓] nftables: filter table + transparent NAT applied."

    # Disable dmidecode (hardware info leak)
    if [[ "$DISABLE_DMIDECODE" == true ]] && [[ -x /usr/sbin/dmidecode ]]; then
        sudo chmod 000 /usr/sbin/dmidecode
        log "[✓] dmidecode disabled."
    fi

    # RAM disk for browser profile and temp files
    if [[ "$USE_RAMDISK" == true ]]; then
        mkdir -p "$RAMDISK_MOUNT"
        if ! mountpoint -q "$RAMDISK_MOUNT"; then
            sudo mount -t tmpfs -o "size=${RAMDISK_SIZE},mode=700" \
                tmpfs "$RAMDISK_MOUNT"
            sudo chown "${USER}:${USER}" "$RAMDISK_MOUNT"
        fi
        export TMPDIR="${RAMDISK_MOUNT}/tmp"
        mkdir -p "$TMPDIR"
        log "[✓] RAM disk mounted at ${RAMDISK_MOUNT} (${RAMDISK_SIZE})"
    fi
}
# Create network lock file for inter-loop coordination
    sudo touch "$NETWORK_LOCK"
    sudo chmod 666 "$NETWORK_LOCK"
    log "[✓] Network lock file ready."

# ----------------------------- BROWSER HARDENING --------------------
harden_browser_config() {
    log "[*] Embedding hardened browser preferences..."
    local TEMP_JS="/tmp/user.js"

    # FIX [5]: Fully deduplicated — no conflicting duplicate entries.
    #          Key fix: letterboxing is now consistently TRUE.
    #          no_proxies_on is "" (no bypass exceptions at all).
    cat > "$TEMP_JS" << 'USERJS'
// ===== Hardened user.js v2.1 (deduplicated, conflict-free) =====

// --- Fingerprinting resistance ---
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);  // FIX: was overridden to false in v2.0

// --- WebGL / Canvas / Audio ---
user_pref("webgl.disabled", true);
user_pref("webgl.enable-webgl2", false);
user_pref("dom.webaudio.enabled", false);
user_pref("canvas.capturestream.enabled", false);

// --- WebRTC (IP leak) ---
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("media.peerconnection.ice.default_address_only", true);

// --- Hardware / sensor APIs ---
user_pref("dom.battery.enabled", false);
user_pref("dom.gamepad.enabled", false);
user_pref("dom.vr.enabled", false);
user_pref("device.sensors.enabled", false);

// --- Font fingerprinting ---
user_pref("font.system.whitelist", "");
user_pref("font.name.monospace.x-western", "Courier New");
user_pref("font.name.sans-serif.x-western", "Arial");
user_pref("font.name.serif.x-western", "Times New Roman");

// --- Viewport normalisation ---
user_pref("privacy.window.maxInnerWidth", 1000);
user_pref("privacy.window.maxInnerHeight", 800);

// --- Hardware concurrency (fingerprinting) ---
user_pref("dom.maxHardwareConcurrency", 2);

// --- Proxy: all traffic via Tor SOCKS, no exceptions ---
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "");   // FIX: was "localhost,127.0.0.1" — now no bypass

// --- Tracking protection ---
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);

// --- Safe Browsing (sends data to Google) ---
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);

// --- Misc leak prevention ---
user_pref("browser.send_pings", false);
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
user_pref("beacon.enabled", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);

// --- Storage isolation ---
user_pref("privacy.firstparty.isolate", true);
user_pref("privacy.partition.network_state", true);
USERJS

    # Apply to existing Firefox profiles
    local applied=0
    for profile in "${HOME}/.mozilla/firefox/"*.default*; do
        if [[ -d "$profile" ]]; then
            cp "$TEMP_JS" "${profile}/user.js"
            log "[✓] Prefs → $(basename "$profile")"
            (( applied++ )) || true
        fi
    done

    # Apply to Tor Browser if present
    local TB_PROFILE="${HOME}/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
    if [[ -d "$TB_PROFILE" ]]; then
        cp "$TEMP_JS" "${TB_PROFILE}/user.js"
        log "[✓] Prefs → Tor Browser profile"
        (( applied++ )) || true
    fi

    (( applied == 0 )) && log "[!] No browser profiles found; prefs saved to /tmp/user.js for later."
}

# ----------------------------- ROTATION LOOPS -----------------------

rotate_public_ip() {
    log "[✓] IP rotation loop started."
    while true; do
        local interval
        interval=$(random_interval)
        log "[*] Next IP rotation in ${interval}s..."
        sleep "$interval"

        local cookie_file="/run/tor/control.authcookie"
        if [[ ! -f "$cookie_file" ]]; then
            log "[!] Tor auth cookie not found — skipping rotation."
            continue
        fi

        local COOKIE
        COOKIE=$(sudo hexdump -ve '1/1 "%.2x"' "$cookie_file" 2>/dev/null) || {
            log "[!] Failed to read auth cookie — skipping."
            continue
        }

        local response
        response=$(printf 'AUTHENTICATE %s\r\nSIGNAL NEWNYM\r\nQUIT\r\n' "$COOKIE" \
            | nc -q 2 127.0.0.1 "$TOR_CONTROL_PORT" 2>/dev/null)

        if echo "$response" | grep -q "250 OK"; then
            log "[⟳] NEWNYM sent — waiting 10s for new circuit..."
            sleep 10
            # Acquire lock only for the IP check so it doesn't race with
            # MAC/DHCP rotation bringing the interface down mid-request
            local NEW_IP
            (
                flock -x -w 20 200 || { log "[!] Net lock timeout — skipping IP check."; exit 0; }
                NEW_IP=$(get_current_public_ip)
                log "[→] Public IP: ${NEW_IP}"
            ) 200>"$NETWORK_LOCK"
        else
            log "[!] NEWNYM failed — response: ${response:-none}"
        fi
    done
}

rotate_mac_ip() {
    local initial_offset="${1:-0}"
    [[ "$initial_offset" -gt 0 ]] && {
        log "[*] MAC rotation starting in ${initial_offset}s..."
        sleep "$initial_offset"
    }

    local -a OUIS=(
        "52:54:00"   # QEMU/KVM
        "00:50:56"   # VMware
        "08:00:27"   # VirtualBox
        "00:0C:29"   # VMware (alternate)
        "00:1C:42"   # Parallels
    )

    log "[✓] MAC rotation loop started."
    while true; do
        sleep "$(random_interval)"
        log "[⟳] Rotating MAC + local IP on ${INTERFACE}..."
        (
            flock -x -w 30 200 || {
                log "[!] Net lock timeout — skipping MAC rotation."
                exit 0
            }
            local OUI="${OUIS[$((RANDOM % ${#OUIS[@]}))]}"
            local RANDOM_MAC
            RANDOM_MAC=$(printf '%s:%02X:%02X:%02X' \
                "$OUI" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))

            sudo ip link set "$INTERFACE" down 2>/dev/null
            sudo macchanger -m "$RANDOM_MAC" "$INTERFACE" > /dev/null 2>&1
            sudo ip link set "$INTERFACE" up 2>/dev/null

            sudo dhclient -r "$INTERFACE" > /dev/null 2>&1 || true
            sleep 1
            sudo dhclient "$INTERFACE" > /dev/null 2>&1 || \
                sudo dhcpcd -n "$INTERFACE" > /dev/null 2>&1 || true

            local NEW_IP
            NEW_IP=$(ip -4 addr show "$INTERFACE" 2>/dev/null \
                | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
            log "[→] MAC: ${RANDOM_MAC}  Local IPv4: ${NEW_IP:-unknown}"
        ) 200>"$NETWORK_LOCK"
    done
}

rotate_hostname() {
    local initial_offset="${1:-0}"
    [[ "$initial_offset" -gt 0 ]] && {
        log "[*] Hostname rotation starting in ${initial_offset}s..."
        sleep "$initial_offset"
    }

    log "[✓] Hostname rotation loop started."
    while true; do
        sleep "$(random_interval)"
        local OLD_HOSTNAME NEW_HOSTNAME
        OLD_HOSTNAME=$(hostname)
        NEW_HOSTNAME=$(random_hostname)

        log "[⟳] Hostname: ${OLD_HOSTNAME} → ${NEW_HOSTNAME}"
        echo "127.0.1.1 ${NEW_HOSTNAME} ${NEW_HOSTNAME}.localdomain" \
            | sudo tee -a /etc/hosts > /dev/null
        sudo hostnamectl set-hostname "$NEW_HOSTNAME" > /dev/null 2>&1
        [[ -n "$OLD_HOSTNAME" ]] && \
            sudo sed -i "/^127\.0\.1\.1[[:space:]].*${OLD_HOSTNAME}\b/d" /etc/hosts
        log "[→] Hostname: ${NEW_HOSTNAME}"
    done
}

rotate_machine_id() {
    local initial_offset="${1:-0}"
    [[ "$initial_offset" -gt 0 ]] && {
        log "[*] Machine ID rotation starting in ${initial_offset}s..."
        sleep "$initial_offset"
    }

    log "[✓] Machine ID rotation loop started."
    while true; do
        sleep "$(random_interval)"
        log "[⟳] Rotating D-Bus Machine ID..."
        sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
        sudo systemd-machine-id-setup > /dev/null 2>&1
        local NEW_ID
        NEW_ID=$(cat /etc/machine-id 2>/dev/null || echo "unknown")
        log "[→] Machine ID: ${NEW_ID:0:8}..."
    done
}

rotate_dhcp_client_id() {
    local initial_offset="${1:-0}"
    [[ "$initial_offset" -gt 0 ]] && {
        log "[*] DHCP client ID rotation starting in ${initial_offset}s..."
        sleep "$initial_offset"
    }

    log "[✓] DHCP client ID rotation loop started."
    while true; do
        sleep "$(random_interval)"
        if ! command -v nmcli > /dev/null 2>&1; then
            log "[!] nmcli not found — skipping DHCP client ID rotation."
            sleep "$(random_interval)"
            continue
        fi
        log "[⟳] Reconfiguring DHCP client ID via nmcli..."
        (
            flock -x -w 30 200 || {
                log "[!] Net lock timeout — skipping DHCP rotation."
                exit 0
            }
            sudo nmcli connection modify "$INTERFACE" \
                ipv4.dhcp-client-id "mac" > /dev/null 2>&1 || true
            sudo nmcli connection down "$INTERFACE" > /dev/null 2>&1 || true
            sleep 1
            sudo nmcli connection up   "$INTERFACE" > /dev/null 2>&1 || true
            log "[✓] DHCP client ID reconfigured."
        ) 200>"$NETWORK_LOCK"
    done
}

reset_browser_profile() {
    local initial_offset="${1:-0}"
    [[ "$initial_offset" -gt 0 ]] && {
        log "[*] Browser profile rotation starting in ${initial_offset}s..."
        sleep "$initial_offset"
    }

    local BROWSER=""
    if command -v firefox > /dev/null 2>&1; then
        BROWSER="firefox"
    elif [[ -f "${HOME}/tor-browser/Browser/start-tor-browser" ]]; then
        BROWSER="tor-browser"
    else
        log "[!] No supported browser found. Skipping profile rotation."
        return
    fi

    log "[✓] Browser profile rotation loop started (${BROWSER})."
    while true; do
        sleep "$(random_interval)"
        log "[⟳] Resetting ${BROWSER} profile..."

        pkill -TERM -f "$BROWSER" 2>/dev/null || true
        local waited=0
        while pgrep -f "$BROWSER" > /dev/null 2>&1; do
            sleep 1; (( waited++ )) || true
            if (( waited >= 10 )); then
                log "[!] ${BROWSER} didn't exit cleanly — sending SIGKILL."
                pkill -KILL -f "$BROWSER" 2>/dev/null || true
                break
            fi
        done
        sleep 1

        if [[ "$BROWSER" == "firefox" ]]; then
            local TIMESTAMP PROFILE_NAME
            TIMESTAMP=$(date +%s)
            PROFILE_NAME="anon-${TIMESTAMP}"
            firefox -CreateProfile "${PROFILE_NAME}" > /dev/null 2>&1 || true
            sleep 1
            local INI="${HOME}/.mozilla/firefox/profiles.ini"
            [[ -f "$INI" ]] && \
                sudo sed -i "s/^Default=.*/Default=${PROFILE_NAME}/" "$INI" 2>/dev/null || true
            local NEW_PROFILE
            NEW_PROFILE=$(find "${HOME}/.mozilla/firefox" \
                -maxdepth 1 -name "*${PROFILE_NAME}*" -type d 2>/dev/null | head -1)
            if [[ -n "$NEW_PROFILE" && -f "/tmp/user.js" ]]; then
                cp "/tmp/user.js" "${NEW_PROFILE}/user.js"
                rm -rf "${NEW_PROFILE}/storage" \
                       "${NEW_PROFILE}/serviceworker" \
                       "${NEW_PROFILE}/cache2" 2>/dev/null || true
            fi
        elif [[ "$BROWSER" == "tor-browser" ]]; then
            local TB_PROFILE="${HOME}/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
            rm -rf "$TB_PROFILE" 2>/dev/null || true
            mkdir -p "$TB_PROFILE"
            [[ -f "/tmp/user.js" ]] && cp "/tmp/user.js" "${TB_PROFILE}/user.js"
        fi
        log "[✓] Fresh ${BROWSER} profile ready."
    done
}
# ----------------------------- FORENSIC CLEANUP ---------------------
wipe_forensic_traces() {
    log "[!] Wiping forensic traces..."

    # FIX [6]: Flush in-memory journald buffer before vacuum
    sudo systemctl kill --kill-who=main --signal=USR2 systemd-journald 2>/dev/null || true
    sleep 1
    sudo journalctl --rotate > /dev/null 2>&1 || true
    sudo journalctl --vacuum-time=1s > /dev/null 2>&1 || true
    sudo journalctl --vacuum-size=1 > /dev/null 2>&1 || true
    sudo rm -rf /var/log/journal/ 2>/dev/null || true
    sudo systemctl restart systemd-journald 2>/dev/null || true

    # Plaintext system logs
    for f in /var/log/syslog \
              /var/log/auth.log \
              /var/log/kern.log \
              /var/log/dpkg.log \
              /var/log/apt/history.log; do
        [[ -f "$f" ]] && sudo shred -zu -n 3 "$f" 2>/dev/null || true
    done

    # Shell histories
    if [[ "$WIPE_BASH_HISTORY" == true ]]; then
        history -c 2>/dev/null || true
        history -w 2>/dev/null || true
        for hist in "${HOME}/.bash_history" \
                    "${HOME}/.zsh_history" \
                    "${HOME}/.fish_history" \
                    "${HOME}/.python_history"; do
            [[ -f "$hist" ]] && shred -zu -n 3 "$hist" 2>/dev/null || true
        done
        unset HISTFILE
        export HISTSIZE=0
        export HISTFILESIZE=0
    fi

    # Temp / cache
    sudo find /tmp /var/tmp -mindepth 1 -delete 2>/dev/null || true
    rm -rf "${HOME}/.cache/"* \
           "${HOME}/.local/share/recently-used.xbel" 2>/dev/null || true

    # NetworkManager / udev state
    sudo rm -f /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null || true
    sudo rm -f /var/lib/NetworkManager/NetworkManager.state 2>/dev/null || true

    rm -f /tmp/user.js 2>/dev/null || true
    log "[✓] Forensic traces wiped."
}

# ----------------------------- CLEANUP TRAP -------------------------
cleanup() {
    log "[*] Shutting down securely..."

    # FIX [7]: Kill tracked background jobs cleanly
    for pid in "${BGPIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    # Give them a moment, then force
    sleep 2
    for pid in "${BGPIDS[@]}"; do
        kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
    done

    # Kill browsers
    pkill -TERM -f "firefox|tor-browser" 2>/dev/null || true
    sleep 4
    pkill -KILL -f "firefox|tor-browser" 2>/dev/null || true

    # Flush firewall (restore normal connectivity)
    sudo nft flush ruleset 2>/dev/null || true

    # Clean browser profiles
    rm -rf "${HOME}/.mozilla/firefox/"*anon-* 2>/dev/null || true

    # Unmount RAM disk
    if [[ "$USE_RAMDISK" == true ]] && mountpoint -q "$RAMDISK_MOUNT" 2>/dev/null; then
        sudo umount "$RAMDISK_MOUNT" 2>/dev/null || true
    fi

    # Restore hostname
    sudo sed -i '/^127\.0\.1\.1/d' /etc/hosts 2>/dev/null || true
    echo "127.0.1.1 kali" | sudo tee -a /etc/hosts > /dev/null
    sudo hostnamectl set-hostname "kali" 2>/dev/null || true

    # Restore machine-id
    sudo rm -f /var/lib/dbus/machine-id /etc/machine-id
    sudo systemd-machine-id-setup > /dev/null 2>&1 || true

    # Re-enable dmidecode
    if [[ "$DISABLE_DMIDECODE" == true ]] && [[ -f /usr/sbin/dmidecode ]]; then
        sudo chmod 755 /usr/sbin/dmidecode 2>/dev/null || true
    fi

    [[ "$WIPE_LOGS_ON_EXIT" == true ]] && wipe_forensic_traces

    log "[✓] System restored. Goodbye."
}

# ========================= MAIN =====================================
trap cleanup EXIT INT TERM

log "=========================================="
log "  IDENTITY CHANGER v2.1 (HARDENED)"
log "  Base interval : ${BASE_INTERVAL}s (±${JITTER_PERCENT}% jitter)"
log "  Interface     : ${INTERFACE}"
log "  Firewall      : nftables filter + transparent NAT"
log "  Browser prefs : Arkenfox (conflict-free)"
log "  RAM disk      : ${USE_RAMDISK}"
log "=========================================="

check_deps
setup_system
harden_browser_config

log "[*] Starting Tor service..."
sudo systemctl start tor
wait_for_tor_bootstrap

if ! nc -z 127.0.0.1 "$TOR_CONTROL_PORT" 2>/dev/null; then
    die "Tor control port ${TOR_CONTROL_PORT} unreachable after bootstrap. Check torrc."
fi
log "[✓] Tor control port reachable."

verify_socks_connectivity

INITIAL_IP=$(get_current_public_ip)
log "[→] Initial Tor exit IP: ${INITIAL_IP}"

# Launch rotation loops; track their PIDs
rotate_public_ip                          & BGPIDS+=($!)
rotate_mac_ip         $(( BASE_INTERVAL / 6  )) & BGPIDS+=($!)   # +50s
rotate_hostname       $(( BASE_INTERVAL / 4  )) & BGPIDS+=($!)   # +75s
rotate_machine_id     $(( BASE_INTERVAL / 3  )) & BGPIDS+=($!)   # +100s
rotate_dhcp_client_id $(( BASE_INTERVAL / 2  )) & BGPIDS+=($!)   # +150s
reset_browser_profile $(( BASE_INTERVAL * 2/3)) & BGPIDS+=($!)   # +200s

log "[*] All rotation loops active (PIDs: ${BGPIDS[*]})."
log "[*] Press Ctrl+C to stop and restore system."
wait
