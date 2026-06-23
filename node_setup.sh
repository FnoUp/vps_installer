#!/bin/bash
# ============================================================
#  VPN Node Setup Script
#  Устанавливает мониторинг на новую EU-ноду:
#    - prometheus-node-exporter
#    - cAdvisor (Docker)
#    - iptables: закрывает порты 9100 и 8080 от всех кроме панели
#
#  Запуск: bash node_setup.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "============================================"
echo "   VPN Node Monitoring Setup"
echo "============================================"
echo ""

# ── Проверка root ─────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "Запусти скрипт от root: sudo bash node_setup.sh"
fi

# ── Вопросы ───────────────────────────────────────────────────
read -rp "IP адрес панели (Remnawave): " PANEL_IP
if [[ -z "$PANEL_IP" ]]; then
    error "IP панели не может быть пустым"
fi

read -rp "Сетевой интерфейс ноды (Enter = ens3): " NET_DEV
NET_DEV="${NET_DEV:-ens3}"

echo ""
info "Панель: $PANEL_IP"
info "Интерфейс: $NET_DEV"
echo ""
read -rp "Всё верно? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && { echo "Отмена."; exit 0; }
echo ""

# ── Обновление пакетов ────────────────────────────────────────
info "Обновляем пакеты..."
apt-get update -q

# ── node_exporter ─────────────────────────────────────────────
info "Устанавливаем prometheus-node-exporter..."
apt-get install -y prometheus-node-exporter

systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

if systemctl is-active --quiet prometheus-node-exporter; then
    success "node_exporter запущен на порту 9100"
else
    error "node_exporter не запустился, проверь: systemctl status prometheus-node-exporter"
fi

# ── Docker проверка ───────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    warn "Docker не найден — устанавливаем..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    success "Docker установлен"
else
    success "Docker уже установлен"
fi

# ── cAdvisor ──────────────────────────────────────────────────
info "Запускаем cAdvisor..."

# Останавливаем старый если есть
docker rm -f cadvisor 2>/dev/null || true

docker run -d \
    --name=cadvisor \
    --restart=always \
    -p 8080:8080 \
    -v /:/rootfs:ro \
    -v /var/run:/var/run:ro \
    -v /sys:/sys:ro \
    -v /var/lib/docker/:/var/lib/docker:ro \
    gcr.io/cadvisor/cadvisor:latest

sleep 3

if docker ps | grep -q cadvisor; then
    success "cAdvisor запущен на порту 8080"
else
    error "cAdvisor не запустился, проверь: docker logs cadvisor"
fi

# ── iptables ──────────────────────────────────────────────────
info "Закрываем порты метрик от публичного доступа..."

# Устанавливаем iptables-persistent
apt-get install -y iptables-persistent

# Удаляем старые правила на эти порты если есть
iptables -D INPUT -p tcp --dport 9100 -j DROP 2>/dev/null || true
iptables -D INPUT -p tcp --dport 8080 -j DROP 2>/dev/null || true

# Разрешаем только с панели
iptables -I INPUT -p tcp --dport 9100 ! -s "$PANEL_IP" -j DROP
iptables -I INPUT -p tcp --dport 8080 ! -s "$PANEL_IP" -j DROP

# Сохраняем
iptables-save > /etc/iptables/rules.v4
success "Порты 9100 и 8080 закрыты, доступны только с $PANEL_IP"

# ── Проверка ──────────────────────────────────────────────────
echo ""
echo "============================================"
echo "   Проверка"
echo "============================================"

NODE_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# node_exporter
if curl -s "http://127.0.0.1:9100/metrics" | grep -q "node_boot_time"; then
    success "node_exporter метрики доступны локально"
else
    warn "node_exporter метрики не отвечают"
fi

# cAdvisor
if curl -s "http://127.0.0.1:8080/metrics" | grep -q "container_"; then
    success "cAdvisor метрики доступны локально"
else
    warn "cAdvisor метрики не отвечают"
fi

echo ""
echo "============================================"
echo -e "${GREEN}   Нода настроена!${NC}"
echo "============================================"
echo ""
echo "Данные для add_node.py на панели:"
echo "  IP ноды:          $NODE_IP"
echo "  Интерфейс:        $NET_DEV"
echo ""
echo "Что добавить в Remnawave вручную:"
echo "  1. Создать ноду в панели (Settings → Nodes)"
echo "  2. Создать хост и привязать к ноде"
echo "  3. Скопировать UUID хоста для add_node.py"
echo ""
