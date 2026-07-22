#!/bin/bash
set -euo pipefail

echo "=================================="
echo "Ubuntu 24 VPS Base Installation"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

# SKIP_REMNAWAVE_INSTALL=1 — не запускать встроенный интерактивный установщик
# eGamesAPI ниже: используется, когда Remnawave/нода ставятся отдельным шагом
# (например VPN Node Manager делает это сам через API, без интерактивного меню).
SKIP_REMNAWAVE_INSTALL="${SKIP_REMNAWAVE_INSTALL:-}"
# AUTO_REBOOT=y|n — пропустить финальный вопрос про перезагрузку.
AUTO_REBOOT="${AUTO_REBOOT:-ask}"

if [ "$EUID" -ne 0 ]; then
  echo "Запусти скрипт от root"
  exit 1
fi
echo "=================================="
echo "Updating system..."
echo "=================================="
apt update
apt upgrade -y
apt autoremove -y

echo "=================================="
echo "Installing base packages..."
echo "=================================="

apt install -y \
  curl wget git socat net-tools ufw gpg ca-certificates \
  iproute2 dnsutils iperf3 htop nano unzip jq
  
echo "=================================="
echo "Disabling IPv6..."
echo "=================================="

cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl --system

echo "=================================="
echo "Configuring firewall..."
echo "=================================="
ufw --force reset

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 80/udp
ufw allow 443/tcp
ufw allow 443/udp
ufw allow 1234/tcp
ufw allow 1234/udp
ufw allow 2222/tcp
ufw allow 2222/udp
ufw allow 8443/tcp
ufw allow 8443/udp
ufw allow 9999/tcp
ufw allow 9999/udp


echo "=================================="
echo "Network information"
echo "=================================="

NET_INFO_LOG="/tmp/vps_install_netinfo.log"
: > "$NET_INFO_LOG"

echo
echo "IP region information:" | tee -a "$NET_INFO_LOG"
{ timeout 200 bash <(curl -4 -fsSL https://raw.githubusercontent.com/FnoUp/ipregion/master/ipregion.sh) 2>&1 \
    || echo "ipregion check failed or timed out"; } | tee -a "$NET_INFO_LOG"

echo
echo "Russian iPerf3 speedtest:" | tee -a "$NET_INFO_LOG"
{ timeout 200 bash <(wget -4 -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh) 2>&1 \
    || echo "iPerf3 speedtest failed or timed out"; } | tee -a "$NET_INFO_LOG"

echo "=================================="
echo "Installing Fail2Ban..."
echo "=================================="

apt install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 24h
findtime = 15m
maxretry = 3
backend = systemd

ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban

echo "=================================="
echo "Fail2Ban installed and started"
echo "=================================="

if [[ "$SKIP_REMNAWAVE_INSTALL" == "1" ]]; then
    echo "=================================="
    echo "SKIP_REMNAWAVE_INSTALL=1 — пропускаю встроенный интерактивный установщик eGamesAPI"
    echo "(Remnawave/нода ставятся отдельным неинтерактивным шагом)"
    echo "=================================="
else
    echo "=================================="
    echo "Installing Remnawave Reverse Proxy"
    echo "=================================="

    bash <(curl -4 -Ls "https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh")
fi

echo "=================================="
echo "Setting up custom geo-data (freedomnet.life) for domain-based routing"
echo "=================================="

GEO_DIR="/var/lib/remnanode"
COMPOSE_FILE="/opt/remnanode/docker-compose.yml"

if [ -f "$COMPOSE_FILE" ]; then
    mkdir -p "$GEO_DIR"

    curl -4 -sL --max-time 30 -o "$GEO_DIR/geoip-freedomnet.dat" "https://geo.freedomnet.life/geoip.dat" \
        && echo "geoip-freedomnet.dat скачан" || echo "WARNING: не удалось скачать geoip-freedomnet.dat"
    curl -4 -sL --max-time 30 -o "$GEO_DIR/geosite-freedomnet.dat" "https://geo.freedomnet.life/geosite.dat" \
        && echo "geosite-freedomnet.dat скачан" || echo "WARNING: не удалось скачать geosite-freedomnet.dat"

    if ! grep -q "geoip-freedomnet.dat" "$COMPOSE_FILE"; then
        cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak.$(date +%F-%H%M%S)"
        python3 - "$COMPOSE_FILE" << 'PYEOF'
import re, sys
path = sys.argv[1]
lines = open(path).readlines()
out = []
inserted = False
in_remnanode = False
for line in lines:
    out.append(line)
    if re.match(r'^  remnanode:\s*$', line):
        in_remnanode = True
    elif re.match(r'^  \S', line):
        in_remnanode = False
    if in_remnanode and not inserted and re.match(r'^(\s*)volumes:\s*$', line):
        indent = re.match(r'^(\s*)volumes:', line).group(1) + "  "
        out.append(f'{indent}- /var/lib/remnanode/geoip-freedomnet.dat:/usr/local/share/xray/geoip-freedomnet.dat\n')
        out.append(f'{indent}- /var/lib/remnanode/geosite-freedomnet.dat:/usr/local/share/xray/geosite-freedomnet.dat\n')
        inserted = True
open(path, "w").writelines(out)
print("volumes добавлены" if inserted else "WARNING: секция volumes не найдена в docker-compose.yml, добавь монтирование вручную")
PYEOF

        echo "Перезапускаем remnanode с новыми volume..."
        (cd /opt/remnanode && { docker compose down && docker compose up -d --remove-orphans; } 2>/dev/null \
            || { docker-compose down && docker-compose up -d --remove-orphans; }) \
            || echo "WARNING: не удалось перезапустить remnanode — примени volume-маунты и перезапусти вручную"
    else
        echo "Volume для geo-freedomnet уже настроен, пропускаем правку docker-compose.yml"
    fi

    cat > /etc/cron.d/geo-freedomnet-update << 'CRON_EOF'
0 4 * * 0 root curl -4 -sL --max-time 30 -o /var/lib/remnanode/geoip-freedomnet.dat https://geo.freedomnet.life/geoip.dat && curl -4 -sL --max-time 30 -o /var/lib/remnanode/geosite-freedomnet.dat https://geo.freedomnet.life/geosite.dat
CRON_EOF
    echo "Еженедельное обновление гео-файлов настроено (cron, вс 04:00)"
else
    echo "WARNING: $COMPOSE_FILE не найден — пропускаем настройку кастомных гео-данных."
    echo "Если нода Remnawave установлена, но по другому пути — настрой geo-freedomnet.dat вручную:"
    echo "  https://geo.freedomnet.life/geoip.dat, geosite.dat -> /var/lib/remnanode/"
    echo "  + volume mounts в docker-compose.yml на /usr/local/share/xray/geoip-freedomnet.dat"
fi

ufw --force enable

echo "=================================="
echo "Installation completed"
echo "=================================="

echo
echo "=================================="
echo "Network & Speedtest Summary"
echo "=================================="
if [ -s "$NET_INFO_LOG" ]; then
    cat "$NET_INFO_LOG"
else
    echo "(no data captured)"
fi
echo "=================================="

echo
if [[ "$AUTO_REBOOT" == "ask" ]]; then
    read -r -p "Reboot server now? [y/N]: " reboot_answer
else
    reboot_answer="$AUTO_REBOOT"
fi

case "$reboot_answer" in
  y|Y|yes|YES)
    reboot
    ;;
  *)
    echo "Reboot skipped. Лучше перезагрузи сервер вручную позже: reboot"
    ;;
esac
