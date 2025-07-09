#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load and export env vars
extract_env_var() {
    local env_name="$1"
    local key="$2"
    local file="$SCRIPT_DIR/.env.${env_name}"

    if [[ ! -f "$file" || "$file" == *example* || "$file" == "$SCRIPT_DIR/.env" ]]; then
        echo "[INFO] Ignoring invalid env file: $file"
        return 1
    fi

    local line value
    line=$(grep -E "^${key}=" "$file" | head -n 1)

    if [[ "$line" =~ ^${key}=\"(.*)\"$ ]]; then
        value="${BASH_REMATCH[1]}"
    else
        value="${line#*=}"
    fi

    export "${key}=${value}"
    echo "$value"
}

# Load required env vars
extract_env_var "common" "NODE_OPTIONS"
extract_env_var "common" "COMPOSER_ALLOW_SUPERUSER"
extract_env_var "common" "FRONTEND_NAME"
extract_env_var "common" "FRONTEND_REPO"
extract_env_var "common" "FRONTEND_DIR"
extract_env_var "common" "BACKEND_REPO"
extract_env_var "common" "BACKEND_DIR"
extract_env_var "common" "PHP_VERSION"

extract_env_var "laravel" "DB_USERNAME"
extract_env_var "laravel" "DB_PASSWORD"
extract_env_var "laravel" "DB_DATABASE"
extract_env_var "laravel" "DB_HOST"
extract_env_var "laravel" "DB_PORT"

extract_env_var "nextjs" "NEXT_PUBLIC_API_URL"

if ! command -v curl &> /dev/null; then 
    echo "[INFO] Installing curl..."
    apt-get update
    apt-get install -y curl
fi

install_basic_tools() {
    apt-get remove needrestart -y
    apt-get clean
    apt-get update
    apt-get install -y software-properties-common gnupg lsb-release zip git
}

remove_apache() {
    systemctl stop apache2 > /dev/null 2>&1 || true
    apt-get purge apache2* -y > /dev/null 2>&1 || true
    apt-get autoremove -y > /dev/null 2>&1 || true
}

install_nginx() {
    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx
        systemctl enable nginx
        systemctl restart nginx
    fi
}

install_php() {
    local codename=$(lsb_release -sc)
    echo "[INFO] Detected Ubuntu codename $codename"

    if dpkg -s php${PHP_VERSION}-fpm &> /dev/null; then
        echo "[INFO] PHP ${PHP_VERSION}-fpm already installed"
        return
    fi

    if [ "$codename" = "jammy" ]; then
        add-apt-repository -y ppa:ondrej/php
    elif [ "$codename" = "noble" ]; then
        echo "[INFO] Adding PHP PPA manually for noble..."
        apt-get install -y software-properties-common gnupg curl lsb-release
        echo "deb [signed-by=/usr/share/keyrings/ondrej-php.gpg] http://ppa.launchpad.net/ondrej/php/ubuntu $codename main" \
            | tee /etc/apt/sources.list.d/ondrej-php.list

        for key in 71DAEAAB4AD4CAB6 4F4EA0AAE5267A6C; do
            gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" || {
                echo "[ERROR] Failed to fetch GPG key: $key"
                exit 1
            }
        done

        gpg --export 71DAEAAB4AD4CAB6 4F4EA0AAE5267A6C \
            | gpg --dearmor --yes --output /usr/share/keyrings/ondrej-php.gpg || {
            echo "[ERROR] Failed to create GPG keyring"
            exit 1
        }
    fi

    apt-get update || { echo "[ERROR] apt-get update failed"; exit 1; }

    echo "[INFO] Installing PHP ${PHP_VERSION} and extensions..."
    apt-get install -y \
        php${PHP_VERSION} php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-{bcmath,calendar,mbstring,gd,xml,curl,gettext,zip,soap,sqlite3,intl,exif,mysqli,mysql,readline,ssh2,dev} \
        php-pear || { echo "[ERROR] Failed to install PHP packages"; exit 1; }

    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm

    echo "[SUCCESS] PHP ${PHP_VERSION} installed and running"
}

install_composer() {
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer -o composer-setup.php
        if ! timeout 10s php composer-setup.php --install-dir=/usr/local/bin --filename=composer; then
            curl -sSL https://getcomposer.org/download/latest-stable/composer.phar -o /usr/local/bin/composer
            chmod +x /usr/local/bin/composer
        fi
        rm -f composer-setup.php 
        command -v composer &> /dev/null || { echo "[ERROR] Composer install failed"; exit 1; }
    fi
}

install_mariadb() {
    if ! command -v mysql &> /dev/null; then
        apt-get install -y mariadb-server
        systemctl enable mariadb
        systemctl start mariadb
    fi
}

clone_projects() {
    if [ ! -d "${BACKEND_DIR}/.git" ]; then
        echo "[INFO] Cloning backend..."
        git clone --branch dev/deploy-bugs "${BACKEND_REPO}" "${BACKEND_DIR}" || {
            echo "[ERROR] Failed to clone backend repo"
            exit 1
        }
    fi

    if [ ! -d "${FRONTEND_DIR}/.git" ]; then
        echo "[INFO] Cloning frontend..."
        git clone --branch dev/deploy-bugs "${FRONTEND_REPO}" "${FRONTEND_DIR}" || {
            echo "[ERROR] Failed to clone frontend repo"
            exit 1
        }
    fi
}

setup_nginx_config() {
    if [ ! -f /etc/nginx/conf.d/supportad.conf ]; then
        rm -f /etc/nginx/sites-enabled/default
        cat <<EOF > /etc/nginx/conf.d/supportad.conf
server {
    listen 80;
    server_name localhost;
    root ${FRONTEND_DIR}/dist;
    index index.html;
    location / { try_files \$uri \$uri/ /index.html; }
    location /app {
        proxy_pass http://127.0.0.1:6001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location /backend {
        alias ${BACKEND_DIR}/public;
        try_files \$uri \$uri/ /backend/index.php?\$query_string;
        location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
        }
    }
}
EOF
        systemctl restart nginx
    fi
}

setup_database() {
    echo "[INFO] Creating database if it does not exist..."
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS \\`${DB_DATABASE}\\`;"

    echo "[INFO] Creating or updating user..."
    mysql -u root -e "
        CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
        ALTER USER '${DB_USERNAME}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \\`${DB_DATABASE}\\`.* TO '${DB_USERNAME}'@'${DB_HOST}';
        FLUSH PRIVILEGES;
    "
}

setup_laravel() {
    cd "$BACKEND_DIR" || exit 1

cp $SCRIPT_DIR/.env.nextjs "$FRONTEND_DIR"/src/.env
    chown www-data:www-data "$BACKEND_DIR"/.env
    chmod 664 "$BACKEND_DIR"/.env

    [ -d vendor ] || composer install --no-dev
    php artisan key:generate --force
    php artisan storage:link --force
    php artisan db:wipe
    php artisan migrate
    php artisan db:seed
    php artisan optimize

    chown -R www-data:www-data storage bootstrap/cache
    chmod -R 775 storage bootstrap/cache
}

install_frontend_tools() {
    if ! command -v node &>/dev/null || ! node -v | grep -q "^v22\."; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    fi

    command -v yarn &>/dev/null || npm install -g yarn
    command -v pm2 &>/dev/null || npm install -g pm2 || yarn global add pm2
}

setup_frontend() {
    cd "$FRONTEND_DIR"
    cp $SCRIPT_DIR/.env.nextjs "$FRONTEND_DIR"/src/.env
    yarn cache clean
    yarn install
    yarn cache clean
    yarn build
    PORT=3000 NODE_ENV=production pm2 start npm --name "${FRONTEND_NAME}" -- start > /dev/null 2>&1 || true
    pm2 startup systemd -u $(whoami) --hp $HOME
    pm2 save
    systemctl enable pm2-$(whoami)
}

# ---- MAIN ----
install_basic_tools
remove_apache
install_nginx
install_php
install_composer
install_mariadb
clone_projects
setup_nginx_config
setup_database
install_frontend_tools
setup_frontend
setup_laravel

echo "✅ Supportad full deployment completed!"