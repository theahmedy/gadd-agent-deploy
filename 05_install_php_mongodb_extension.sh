#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

SECRETS_FILE="./config.yml"
export V_PHP_VERSION=$(yq '.php_version' "$SECRETS_FILE")

install_php_mongodb_extension() {
    echo "🧩 [05] Installing MongoDB PHP extension v1.18.0..."

    if php -m | grep -q mongodb && pecl list | grep -q 'mongodb.*1.18.0'; then
        echo "✅ MongoDB extension v1.18.0 is already installed."
        return
    fi

    echo "➡️ Installing via PECL..."
    pecl channel-update pecl.php.net
    printf "\n" | pecl install mongodb-1.18.0 || true

    # Enable extension if not already enabled
    ini_file="/etc/php/${V_PHP_VERSION}/mods-available/mongodb.ini"
    echo "extension=mongodb.so" > "$ini_file"
    phpenmod mongodb

    echo "🔁 Restarting PHP FPM service..."
    systemctl restart php${V_PHP_VERSION}-fpm

    echo "✅ MongoDB extension installed and enabled."
}

install_php_mongodb_extension
