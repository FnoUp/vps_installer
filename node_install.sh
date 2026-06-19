#!/bin/bash

set -e

echo "=================================="
echo "Ubuntu 24 VPS Base Installation"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt autoremove -y

apt install -y curl wget git socat net-tools ufw

# ИСПРАВЛЕНИЕ ДЛЯ UBUNTU 24.04: маскируемся под jammy
curl -s https://install.speedtest.net/app/cli/install.deb.sh | sed 's/noble/jammy/g' | sudo bash
sudo apt install -y speedtest speedtest-cli

# Настройка файрвола UFW
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

echo "Installing Remnawave Reverse Proxy..."
bash <(curl -4 -Ls "https://githubusercontent.com")

ufw --force enable

echo "=================================="
echo "Installation completed"
echo "=================================="

reboot
