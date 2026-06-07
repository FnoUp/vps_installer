#!/bin/bash

set -e

echo "=================================="
echo "Ubuntu 24 VPS Base Installation"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y

apt install -y 
curl 
wget 
git 
socat 
net-tools 
ufw

echo "Installing Remnawave Reverse Proxy..."

bash <(curl -Ls https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh)

echo "=================================="
echo "Installation completed"
echo "=================================="
