#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

SECRETS_FILE="./config.yml"
export V_PHP_VERSION=$(yq '.php_version' "$SECRETS_FILE")

install_php() {
    echo "🐘 [04] Checking and installing PHP ${V_PHP_VERSION}..."

    if ! dpkg -s php${V_PHP_VERSION}-fpm &> /dev/null; then
        echo "➡️ Adding PHP repository and installing PHP ${V_PHP_VERSION}..."
        add-apt-repository ppa:ondrej/php -y
        apt-get update
        apt-get install -y php${V_PHP_VERSION} php${V_PHP_VERSION}-fpm php-pear php-cli
    else
        echo "✅ PHP ${V_PHP_VERSION} is already installed."
    fi

    echo "🔍 Checking core PHP extensions..."
    extensions=(bcmath calendar mbstring gd xml curl gettext zip soap intl exif mysql readline ssh2 dev)
    for ext in "${extensions[@]}"; do
        if ! php -m | grep -qw "$ext"; then
            echo "❌ Missing extension: $ext"
            echo "➡️ Installing extension: php${V_PHP_VERSION}-$ext"
            apt-get install -y php${V_PHP_VERSION}-$ext
        else
            echo "✅ Extension: $ext"
        fi
    done

    echo "🔁 Enabling PHP FPM service..."
    systemctl enable php${V_PHP_VERSION}-fpm
    systemctl start php${V_PHP_VERSION}-fpm

    echo "✅ PHP ${V_PHP_VERSION} and required extensions installed successfully."
}

install_php
