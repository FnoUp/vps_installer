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

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 2222/tcp

echo "Installing Remnawave Reverse Proxy..."

bash <(curl -Ls "https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh")

echo "=================================="
echo "Installation completed"
echo "=================================="
