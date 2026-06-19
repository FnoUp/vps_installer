#!/bin/bash

# Выход при ошибке
set -e

echo "=================================="
echo "Ubuntu 24 VPS Base Installation"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

# Обновление системы
apt update
apt upgrade -y
apt autoremove -y

# Установка базовых утилит
apt install -y curl wget git socat net-tools ufw

# ИСПРАВЛЕНО: Правильное добавление репозитория Ookla Speedtest
curl -s https://speedtest.net | sudo bash 

# Установка Speedtest (официального и старого python-клиента)
sudo apt install -y speedtest speedtest-cli

# Настройка файрвола UFW (Дубликаты удалены)
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
bash <(curl -4 -Ls "https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh")

# ИСПРАВЛЕНО: Включение файрвола без интерактивных вопросов
ufw --force enable

echo "=================================="
echo "Installation completed. Rebooting..."
echo "=================================="

reboot
