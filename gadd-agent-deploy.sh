#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error occurred on line $LINENO. Exiting..."; exit 1' ERR
apt-get install curl -y
SECRETS_FILE="./config.yml"

if ! command -v yq &> /dev/null; then
    curl -sSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

export V_PHP_VERSION=$(yq '.php_version' "$SECRETS_FILE")
export DB_NAME=$(yq '.db_name' "$SECRETS_FILE")
export DB_HOST=$(yq '.db_host' "$SECRETS_FILE")
export DB_USERNAME=$(yq '.db_username' "$SECRETS_FILE")
export DB_PASSWORD=$(yq '.db_password' "$SECRETS_FILE")
export APP_URL=$(yq '.app_url' "$SECRETS_FILE")
export BB_USER=$(yq '.bitbucket_user' "$SECRETS_FILE")
export BB_TOKEN=$(yq '.bitbucket_token' "$SECRETS_FILE")

install_basic_tools() {
    apt-get remove needrestart -y > /dev/null 2>&1 || true
    apt-get clean > /dev/null
    apt-get update > /dev/null
    apt-get upgrade -y > /dev/null
    apt-get install -y software-properties-common zip unzip git gnupg > /dev/null
}

remove_apache() {
    systemctl stop apache2 || true
    apt-get purge apache2* -y > /dev/null || true
    apt-get autoremove -y > /dev/null
}

install_nginx() {
    apt-get install -y nginx > /dev/null
    systemctl enable nginx > /dev/null
    systemctl restart nginx
}

install_php() {
    add-apt-repository ppa:ondrej/php -y > /dev/null
    apt-get update > /dev/null
    apt-get install -y php${V_PHP_VERSION} php${V_PHP_VERSION}-fpm \
        php${V_PHP_VERSION}-{bcmath,calendar,mbstring,gd,xml,curl,gettext,zip,soap,sqlite3,intl,exif,mysqli,mysql,readline,ssh2,dev} php-pear > /dev/null
    systemctl enable php${V_PHP_VERSION}-fpm > /dev/null
    systemctl start php${V_PHP_VERSION}-fpm
}

install_php_mongodb_extension() {
    if php -m | grep -q mongodb && pecl list | grep -q 'mongodb.*1.18.0'; then
        return
    fi
    pecl channel-update pecl.php.net > /dev/null
    printf "\n" | pecl install mongodb-1.18.0 > /dev/null 2>&1 || true
    echo "extension=mongodb.so" > /etc/php/${V_PHP_VERSION}/mods-available/mongodb.ini
    phpenmod mongodb
    systemctl restart php${V_PHP_VERSION}-fpm
}

install_composer() {
    export COMPOSER_ALLOW_SUPERUSER=1
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer -o composer-setup.php
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer > /dev/null
    fi
}

install_mariadb() {
    apt-get install -y mariadb-server > /dev/null 2>&1
    systemctl enable mariadb > /dev/null
    systemctl start mariadb
}

install_mongodb() {
    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg --dearmor | install -m 644 /dev/stdin /usr/share/keyrings/mongodb-server-6.0.gpg
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-6.0.list
    apt-get update > /dev/null
    apt-get install -y mongodb-org > /dev/null
    systemctl enable mongod > /dev/null
    systemctl start mongod
}

clone_projects() {
    git clone https://${BB_USER}:${BB_TOKEN}@bitbucket.org/wakebtech/agi_services.git /var/www/html/gadd-agent-backend > /dev/null
    git clone --branch release/gad https://${BB_USER}:${BB_TOKEN}@bitbucket.org/wakebtech/wakeb_agi_react.git /var/www/html/gadd-agent-frontend > /dev/null
    git clone https://${BB_USER}:${BB_TOKEN}@bitbucket.org/wakebtech/nest-socket-wakeb.git /var/www/html/gadd-agent-socket > /dev/null
}

setup_nginx_config() {
    rm -f /etc/nginx/sites-enabled/default
    cat <<EOF > /etc/nginx/sites-available/gadd_agent
server {
    listen 80;
    server_name localhost;
    root /var/www/html/gadd-agent-frontend/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /app {
        proxy_pass http://127.0.0.1:6001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /backend {
        alias /var/www/html/gadd-agent-backend/public;
        try_files \$uri \$uri/ /backend/index.php?\$query_string;

        location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php${V_PHP_VERSION}-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
        }
    }
}
EOF
    ln -s /etc/nginx/sites-available/gadd_agent /etc/nginx/sites-enabled/ || true
    systemctl restart nginx
}

setup_database() {
    mysql -u root <<EOF
DROP DATABASE IF EXISTS \`${DB_NAME}\`;
DROP USER IF EXISTS '${DB_USERNAME}'@'${DB_HOST}';
CREATE DATABASE \`${DB_NAME}\`;
CREATE USER '${DB_USERNAME}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USERNAME}'@'${DB_HOST}';
FLUSH PRIVILEGES;
EOF
}

setup_laravel() {
    cd /var/www/html/gadd-agent-backend
    cp .env.example .env
    sed -i "s|^DB_HOST=.*|DB_HOST=${DB_HOST}|" .env
    sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
    sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USERNAME}|" .env
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=\"${DB_PASSWORD}\"|" .env
    composer install --no-dev > /dev/null
    php artisan key:generate
    php artisan storage:link
    php artisan migrate --seed --force
    php artisan optimize
    mkdir -p storage/logs
    touch storage/logs/laravel.log
    chown -R www-data:www-data storage bootstrap/cache
    chmod -R 775 storage bootstrap/cache
}

setup_frontend() {
    cd /var/www/html/gadd-agent-frontend
    yarn install > /dev/null
    yarn build > /dev/null
    pm2 start npm --name gadd-agent-frontend -- start
}

setup_socket() {
    cd /var/www/html/gadd-agent-socket
    yarn install > /dev/null
    yarn build > /dev/null
    pm2 start dist/main.js --name gadd-agent-socket
}

# ---- MAIN ----
install_basic_tools
remove_apache
install_nginx
install_php
install_php_mongodb_extension
install_composer
install_mariadb
install_mongodb
clone_projects
setup_nginx_config
setup_database
setup_laravel
setup_frontend
setup_socket

echo "✅ GADD Agent full deployment completed!"
