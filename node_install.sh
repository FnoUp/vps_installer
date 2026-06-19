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

echo "Updating system..."
apt update
apt upgrade -y
apt autoremove -y

echo "Installing base packages..."
apt install -y \
  curl wget git socat net-tools ufw gpg ca-certificates \
  iproute2 dnsutils iperf3 htop nano unzip jq

echo "Configuring firewall..."
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

ufw --force enable

echo "=================================="
echo "Network information"
echo "=================================="

echo
echo "IP region information:"
if ! timeout 120 bash <(curl -4 -fsSL https://ipregion.vrntt.xyz); then
  echo "curl failed, trying wget..."
  timeout 120 bash <(wget -4 -qO- https://ipregion.vrntt.xyz) || echo "IP region test failed or timed out"
fi

echo
echo "Russian iPerf3 speedtest:"
timeout 220 bash <(wget -4 -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh) || echo "iPerf3 speedtest failed or timed out"

echo "=================================="
echo "Installing Remnawave Reverse Proxy"
echo "=================================="

bash <(curl -4 -Ls "https://githubusercontent.com")

echo "=================================="
echo "Installation completed"
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
