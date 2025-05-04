#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

        export COMPOSER_ALLOW_SUPERUSER=1


install_composer_node_yarn() {
    echo "🎼 [06] Installing Composer..."

    if command -v composer &>/dev/null; then
        echo "✅ Composer already installed with version : $(composer --version)"
    else

    echo "➡️ Downloading Composer installer..."
    curl -sS https://getcomposer.org/installer -o composer-setup.php

    echo "➡️ Installing Composer globally..."
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer

    rm -f composer-setup.php

    fi

        # Install Node.js v22.12.0
    if command -v node &>/dev/null && node -v | grep -q "v22.12.0"; then
        echo "✅ Node.js v22.12.0 already installed."
    else
        echo "➡️ Installing Node.js v22.12.0..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    fi

    # Install Yarn
    if command -v yarn &>/dev/null; then
        echo "✅ Yarn already installed: $(yarn -v)"
    else
        echo "➡️ Installing Yarn..."
        npm install -g yarn
    fi

if ! command -v pm2 &>/dev/null; then
  npm install -g pm2 > /dev/null 2>&1 || yarn global add pm2 > /dev/null 2>&1
fi

}

install_composer_node_yarn
