# Web-ID-Changer-for-Kali-Linux
Web ID Changer: Kali Linux tool for one‑click browser fingerprint spoofing, IP masking via proxy/Tor, and auto‑clearing cookies/cache. Perfect for ethical pen testing &amp; OSINT, A Bash-based online identity rotation tool for Kali Linux that routes all traffic through Tor and continuously rotates network, system, and browser identifiers to enhance privacy. Stay Anonymous.

---

## Features

**Tor-Only Firewall**
All traffic is forced through Tor via nftables. A transparent NAT proxy redirects every outgoing TCP connection and DNS query through Tor automatically. Non-Tor traffic is blocked at the kernel level — no leaks possible through misconfigured apps.

**Public IP Rotation**
Requests a new Tor circuit at randomised intervals, changing your visible exit IP address periodically and automatically.

**MAC Address Rotation**
Spoofs the network interface's MAC address using real vendor OUIs (QEMU, VMware, VirtualBox, Parallels) so the device doesn't appear consistent on the local network.

**Hostname Rotation**
Changes the system hostname to a random string at each interval, preventing hostname-based identification on local networks.

**Machine ID Rotation**
Regenerates the D-Bus machine ID, which applications and services use to fingerprint the device.

**DHCP Client ID Rotation**
Cycles the DHCP client identity so the router sees a new client after each MAC rotation.

**Browser Hardening**
Injects a hardened `user.js` into Firefox and Tor Browser profiles, disabling WebGL, WebRTC, canvas fingerprinting, audio fingerprinting, battery API, sensors, and enforcing all traffic through Tor SOCKS with no bypass exceptions.

**RAM Disk**
Mounts a 2 GB tmpfs RAM disk and runs browser profiles and temp files entirely in memory. Nothing is written to disk during a session.

**Forensic Cleanup on Exit**
On Ctrl+C or any exit signal, the tool wipes system logs, shell history, browser profiles, temp files, and NetworkManager state. Restores hostname and machine ID to defaults.

**Kernel Hardening**
Disables TCP timestamps, SACK, ICMP redirects, and source routing. Enables reverse path filtering, SYN cookies, and restricts kernel pointer exposure — all of which reduce OS-level fingerprinting.

---

## How It Works

1. On launch, the firewall is applied and all outbound traffic is transparently redirected through Tor.
2. Six rotation loops run in the background, each on a randomised timer (default ±30% of 200 seconds) to avoid predictable patterns.
3. The browser profile is periodically wiped and recreated with hardened preferences applied fresh each time.
4. On exit (Ctrl+C), a cleanup routine kills all loops, restores the system to its original state, and wipes forensic traces.

---

## Requirements

**System packages**
```bash
sudo apt install -y tor macchanger nftables curl netcat-openbsd iproute2 \
    procps coreutils network-manager isc-dhcp-client firefox-esr
```

**`/etc/tor/torrc` entries**
```
ControlPort 9051
CookieAuthentication 1
TransPort 9040 IsolateClientAddr IsolateClientProtocol
DNSPort 5353
```

Restart Tor after editing:
```bash
sudo systemctl restart tor
```

---

## Usage

**Make executable (first time only)**
```bash
chmod +x id_changer_v2.1.sh
```

**Run**
```bash
sudo ./id_changer_v2.1.sh
```

**Use a different network interface**
```bash
sudo INTERFACE=wlan0 ./id_changer_v2.1.sh
```

**Stop cleanly**
```
Ctrl+C
```
The cleanup routine runs automatically on exit — logs are wiped, firewall is flushed, and the system is restored.

---

## Configuration

All settings are at the top of the script:

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `eth0` | Network interface to rotate |
| `BASE_INTERVAL` | `200` | Base seconds between rotations |
| `JITTER_PERCENT` | `30` | Random variance on interval (±%) |
| `USE_RAMDISK` | `true` | Run browser profile in RAM |
| `RAMDISK_SIZE` | `2G` | Size of the RAM disk |
| `WIPE_LOGS_ON_EXIT` | `true` | Shred logs on exit |
| `WIPE_BASH_HISTORY` | `true` | Wipe shell history on exit |
| `DISABLE_DMIDECODE` | `true` | Remove execute permission from dmidecode |

---

## Notes

- Requires `sudo` — firewall and kernel changes need root.
- The tool is intended for testing and educational use only.
- Tor must be fully bootstrapped before rotation begins (the script waits 20 seconds after starting it).
- If Tor fails to start, check `sudo journalctl -u tor --no-pager | tail -20`.
