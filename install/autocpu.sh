#!/usr/bin/env bash
# autocpu.sh - safe VPS monitor and service recovery
# No remote SSH keys, no authorized_keys changes, no chattr, no pkill, no reboot.
# Tested design target: Ubuntu/Debian with systemd. Run as root.

set -u
umask 077

# ---------- Configuration ----------
AUTO_RESTART_SERVICES="${AUTO_RESTART_SERVICES:-1}"
CHECK_SERVICES="${CHECK_SERVICES:-xray nginx haproxy ws}"
LOG_FILE="${LOG_FILE:-/var/log/autocpu.log}"
STATE_DIR="${STATE_DIR:-/var/lib/autocpu}"
# -----------------------------------

mkdir -p "$STATE_DIR" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/autocpu.log"

log() {
    local msg
    msg="$(date '+%F %T') | $*"
    printf '%s\n' "$msg" | tee -a "$LOG_FILE"
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "Jalankan sebagai root: sudo bash autocpu.sh"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "Sistem ini tidak menggunakan systemd; script dihentikan."
    exit 1
fi

# CPU usage sampled from /proc/stat (one-second interval).
read_cpu() {
    awk '/^cpu / {
        idle=$5+$6
        total=0
        for (i=2; i<=NF; i++) total += $i
        print total, idle
        exit
    }' /proc/stat
}

cpu1="$(read_cpu)"
sleep 1
cpu2="$(read_cpu)"
read -r total1 idle1 <<< "$cpu1"
read -r total2 idle2 <<< "$cpu2"

cpu_usage="N/A"
if [[ -n "${total1:-}" && -n "${total2:-}" ]] && (( total2 > total1 )); then
    dt=$((total2-total1))
    di=$((idle2-idle1))
    cpu_usage=$(( (100 * (dt-di)) / dt ))
fi

ram_line="$(free -m | awk '/^Mem:/ {printf "%s %s %s", $3, $2, $3*100/$2}')"
read -r ram_used ram_total ram_pct <<< "${ram_line:-0 0 0}"
ram_pct="${ram_pct%.*}"

disk_line="$(df -P / | awk 'NR==2 {print $5}')"
uptime_text="$(uptime -p 2>/dev/null || uptime)"

log "========== VPS MONITOR =========="
log "Hostname : $(hostname)"
log "CPU      : ${cpu_usage}%"
log "RAM      : ${ram_used:-0} MB / ${ram_total:-0} MB (${ram_pct:-0}%)"
log "Disk /   : ${disk_line:-N/A}"
log "Uptime   : ${uptime_text}"

# Optional existing license-days display; this script does not contact a license server.
if [[ -r /etc/masaaktif ]]; then
    log "Masa aktif (data lokal /etc/masaaktif): $(head -n1 /etc/masaaktif)"
else
    log "Masa aktif: tidak ada data lokal (/etc/masaaktif)"
fi

# Bandwidth summary, if vnStat is installed.
if command -v vnstat >/dev/null 2>&1; then
    vn_iface="$(vnstat --iflist 2>/dev/null | sed 's/.*: //' | awk '{print $1}')"
    if [[ -n "${vn_iface:-}" ]]; then
        log "Bandwidth vnStat (${vn_iface}) - ringkasan bulan:"
        vnstat -i "$vn_iface" -m 2>/dev/null | tail -n 5 | while IFS= read -r line; do
            log "  $line"
        done
    else
        log "vnStat terpasang, tetapi interface belum terdeteksi."
    fi
else
    log "vnStat tidak terpasang; pemeriksaan bandwidth dilewati."
fi

# Check only known service units. Never disable services or kill shell processes.
for service in $CHECK_SERVICES; do
    if ! systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "^${service}.service"; then
        log "SERVICE ${service}: unit tidak ditemukan (dilewati)"
        continue
    fi

    if systemctl is-active --quiet "$service"; then
        log "SERVICE ${service}: aktif"
    else
        state="$(systemctl is-active "$service" 2>/dev/null || true)"
        log "SERVICE ${service}: ${state:-tidak diketahui}"
        if [[ "$AUTO_RESTART_SERVICES" == "1" ]]; then
            log "Mencoba start ${service}..."
            if systemctl start "$service"; then
                sleep 2
                if systemctl is-active --quiet "$service"; then
                    log "SERVICE ${service}: berhasil aktif kembali"
                else
                    log "SERVICE ${service}: start dijalankan tetapi belum aktif; cek journalctl -u ${service}"
                fi
            else
                log "SERVICE ${service}: gagal start; cek journalctl -u ${service}"
            fi
        else
            log "Auto-start dimatikan (AUTO_RESTART_SERVICES=0)."
        fi
    fi
done

# KYT is checked only if its executable exists.
if [[ -x /usr/bin/kyt ]] && systemctl list-unit-files kyt.service --no-legend 2>/dev/null | grep -q '^kyt.service'; then
    if systemctl is-active --quiet kyt; then
        log "SERVICE kyt: aktif"
    elif [[ "$AUTO_RESTART_SERVICES" == "1" ]]; then
        log "SERVICE kyt: tidak aktif; mencoba start..."
        systemctl start kyt && log "SERVICE kyt: perintah start dikirim" || log "SERVICE kyt: gagal start"
    else
        log "SERVICE kyt: tidak aktif (auto-start dimatikan)"
    fi
fi

log "Pemeriksaan selesai."
