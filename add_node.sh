#!/bin/bash
# Обёртка: скачивает и запускает add_node.py через python3
set -e

if [ ! -t 0 ]; then
    exec < /dev/tty
fi

PY_URL="https://raw.githubusercontent.com/FnoUp/vps_installer/main/add_node.py"
TMP="/tmp/add_node_$$.py"

curl -4 -Ls "$PY_URL" -o "$TMP"
python3 "$TMP"
rm -f "$TMP"
