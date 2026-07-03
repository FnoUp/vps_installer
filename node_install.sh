#!/bin/bash
set -euo pipefail

echo "=================================="
echo "Ubuntu 24 VPS Base Installation"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

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

echo "=================================="
echo "Installing Remnawave Reverse Proxy"
echo "=================================="

bash <(curl -4 -Ls "https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh")

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
read -r -p "Reboot server now? [y/N]: " reboot_answer

case "$reboot_answer" in
  y|Y|yes|YES)
    reboot
    ;;
  *)
    echo "Reboot skipped. Лучше перезагрузи сервер вручную позже: reboot"
    ;;
esac
