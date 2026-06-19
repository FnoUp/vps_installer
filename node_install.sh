#!/bin/bash

# Выход из скрипта при возникновении любой ошибки
set -e

echo "=================================="
echo "Ubuntu 24 VPS Base Installation"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

# Обновление списков пакетов и компонентов системы
apt update
apt upgrade -y
apt autoremove -y

# Установка базовых сетевых и системных утилит
apt install -y curl wget git socat net-tools ufw

# Подключение репозитория Ookla Speedtest с Packagecloud
# Подменяем кодовое имя 'noble' на 'jammy', так как официальной ветки для Ubuntu 24 пока нет
curl -s https://packagecloud.io | sed 's/noble/jammy/g' | sudo bash

# Установка официального speedtest и старой open-source версии
sudo apt install -y speedtest speedtest-cli

# Настройка файрвола UFW (все дубликаты портов удалены)
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
# Запуск официального скрипта установки Remnawave
bash <(curl -4 -Ls "https://githubusercontent.com")

# Принудительное включение файрвола без интерактивных запросов (Y/N)
ufw --force enable

echo "=================================="
echo "Installation completed. Rebooting..."
echo "=================================="

# Перезагрузка сервера для применения обновлений
reboot
