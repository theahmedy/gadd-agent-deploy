#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR


install_nginx() {
    echo "🌐 [03] Checking and installing NGINX..."

    if command -v nginx &>/dev/null; then
        echo "✅ NGINX is already installed."
    else
        echo "➡️ Installing NGINX..."
        apt-get install -y nginx
    fi

    echo "🔁 Enabling and restarting NGINX..."
    systemctl enable nginx
    systemctl restart nginx

    echo "✅ NGINX setup complete."
}

install_nginx