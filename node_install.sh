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
apt install -y curl wget git socat net-tools ufw gpg

# ГАРАНТИРОВАННОЕ ИСПРАВЛЕНИЕ ДЛЯ UBUNTU 24.04:
# 1. Удаляем следы прошлых неудачных попыток, если они были
rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list /etc/apt/sources.list.d/speedtest.list

# 2. Скачиваем официальный GPG-ключ Ookla напрямую
mkdir -p /etc/apt/keyrings
curl -fsSL https://packagecloud.io | gpg --dearmor -o /etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg

# 3. Создаем файл репозитория вручную, принудительно указав стабильную ветку "jammy"
cat <<EOF > /etc/apt/sources.list.d/ookla_speedtest-cli.list
deb [signed-by=/etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg] https://packagecloud.io/ookla/speedtest-cli/ubuntu/ jammy main
deb-src [signed-by=/etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg] https://packagecloud.io/ookla/speedtest-cli/ubuntu/ jammy main
EOF

# 4. Обновляем кеш APT, чтобы он увидел добавленный репозиторий
apt update

# Установка официального speedtest и старой open-source версии
apt install -y speedtest speedtest-cli

# Настройка файрвола UFW (без дубликатов портов)
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
