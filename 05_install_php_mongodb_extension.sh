#!/bin/bash


install_php_mongodb_extension() {
    echo "🧩 [05] Installing MongoDB PHP extension v1.18.0..."

    if php -m | grep -q mongodb && pecl list | grep -q 'mongodb.*1.18.0'; then;
        return
    fi
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
