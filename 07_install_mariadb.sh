#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

install_mariadb() {
    echo "🐬 [07] Installing MariaDB Server..."

    if command -v mysql &>/dev/null; then
        echo "✅ MariaDB (MySQL client) already installed."
    else
        echo "➡️ Installing MariaDB Server..."
        apt-get install -y mariadb-server
    fi

    echo "🔁 Enabling and starting MariaDB service..."
    systemctl enable mariadb
    systemctl start mariadb

    echo "✅ MariaDB is ready."
}

install_mariadb
