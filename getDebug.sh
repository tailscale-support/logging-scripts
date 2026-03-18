#! /bin/sh
set -euo pipefail

# Set Variables
tsBinary=$(which tailscale)
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
HOSTNAME="$(hostname 2>/dev/null || echo unknown-host)"
BASE_DIR="network_info_${HOSTNAME}_${TIMESTAMP}"
ARCHIVE_NAME="${BASE_DIR}.tar.gz"

# Check if root and whether to use sudo or doas
	CAN_ROOT=
	SUDO=
	if [ "$(id -u)" = 0 ]; then
		CAN_ROOT=1
		SUDO=""
	elif type sudo >/dev/null; then
		CAN_ROOT=1
		SUDO="sudo"
	elif type doas >/dev/null; then
		CAN_ROOT=1
		SUDO="doas"
	fi
	if [ "$CAN_ROOT" != "1" ]; then
		echo "This installer needs to run commands as root."
		echo "We tried looking for 'sudo' and 'doas', but couldn't find them."
		echo "Either re-run this script as root, or set up sudo/doas."
		exit 1
	fi

# Make logging folder
mkdir -p "$BASE_DIR"

run_and_log() {
    local outfile="$1"
    shift

    {
        echo "===== Command: $* ====="
        echo "===== Timestamp: $(date -Is) ====="
        echo
        "$@"
    } > "${BASE_DIR}/${outfile}" 2>&1 || true
}

copy_file_if_exists() {
    local src="$1"
    local dst="$2"

    {
        echo "===== Source: ${src} ====="
        echo "===== Timestamp: $(date -Is) ====="
        echo
        if [[ -e "$src" ]]; then
            cat "$src"
        else
            echo "File not found: $src"
        fi
    } > "${BASE_DIR}/${dst}" 2>&1
}

# Basic system context
{
    echo "Timestamp: $(date -Is)"
    echo "Hostname: ${HOSTNAME}"
    echo "Kernel: $(uname -a)"
    echo "User: $(id)"
} > "${BASE_DIR}/system_info.txt"

# IP information
if command -v ip >/dev/null 2>&1; then
    run_and_log "ip_addr.txt" ip addr
    run_and_log "ip_link.txt" ip link
    run_and_log "ip_route.txt" ip route show
    run_and_log "ip_route_table_all.txt" ip route show table all
    run_and_log "ip_rule.txt" ip rule show
    run_and_log "ip_neigh.txt" ip neigh
else
    echo "'ip' command not found" > "${BASE_DIR}/ip_command_missing.txt"
fi

# Legacy fallback commands if available
if command -v ifconfig >/dev/null 2>&1; then
    run_and_log "ifconfig.txt" ifconfig -a
fi

if command -v route >/dev/null 2>&1; then
    run_and_log "route_n.txt" route -n
fi

if command -v netstat >/dev/null 2>&1; then
    run_and_log "netstat_rn.txt" netstat -rn
fi

# Resolver configuration
copy_file_if_exists "/etc/resolv.conf" "resolv.conf.txt"

if [[ -d /etc/resolv.conf.d ]]; then
    tar -cf - /etc/resolv.conf.d 2>/dev/null | tar -xf - -C "${BASE_DIR}" 2>/dev/null || true
fi

if [[ -d /etc/systemd/resolved.conf.d ]]; then
    tar -cf - /etc/systemd/resolved.conf.d 2>/dev/null | tar -xf - -C "${BASE_DIR}" 2>/dev/null || true
fi

if [[ -f /etc/systemd/resolved.conf ]]; then
    copy_file_if_exists "/etc/systemd/resolved.conf" "systemd_resolved.conf.txt"
fi

# DNS status if available
if command -v resolvectl >/dev/null 2>&1; then
    run_and_log "resolvectl_status.txt" resolvectl status
    run_and_log "resolvectl_dns.txt" resolvectl dns
    run_and_log "resolvectl_domain.txt" resolvectl domain
elif command -v systemd-resolve >/dev/null 2>&1; then
    run_and_log "systemd_resolve_status.txt" systemd-resolve --status
fi

# NetworkManager info if available
if command -v nmcli >/dev/null 2>&1; then
    run_and_log "nmcli_device_show.txt" nmcli device show
    run_and_log "nmcli_connection_show.txt" nmcli connection show
fi

# Tailscale info if available
if command -v tailscale >/dev/null 2>&1; then
    run_and_log "tailscale_status.txt" tailscale status
    run_and_log "tailscale_netcheck.txt" tailscale netcheck
    run_and_log "tailscale_debug_ts2021.txt" tailscale debug ts2021 --verbose
    run_and_log "tailscale_bugreport.txt" tailscale bugreport
    run_and_log "tailscale_debug_prefs.txt" tailscale debug prefs
else
    echo "tailscale command not found" > "${BASE_DIR}/tailscale_missing.txt"
fi

# Create archive
tar -czf "$ARCHIVE_NAME" "$BASE_DIR"

# Verify archive creation before deleting
if [[ -f "$ARCHIVE_NAME" ]]; then
    rm -rf "$BASE_DIR"
    echo "Cleaned up folder: $BASE_DIR"
else
    echo "Archive not created, keeping folder: $BASE_DIR"
fi

echo "Created archive: $ARCHIVE_NAME"
