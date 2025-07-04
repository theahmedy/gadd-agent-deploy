#!/bin/bash

# 1️⃣ Ensure curl is available

export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_VERSION="8.2"
export NODE_OPTIONS="--max-old-space-size=4096"
export COMPOSER_ALLOW_SUPERUSER=1
export REPO_USER=$(yq '.bitbucket_user' "$SECRETS_FILE")
export REPO_TOKEN=$(yq '.bitbucket_token' "$SECRETS_FILE")
export NEXT_PUBLIC_API_URL=$(yq '.NEXT_PUBLIC_API_URL' "$SECRETS_FILE")
export NEXT_PUBLIC_SOCKET_URL=$(yq '.NEXT_PUBLIC_SOCKET_URL' "$SECRETS_FILE")
export NEXT_PUBLIC_SOCKET_APP_KEY=$(yq '.NEXT_PUBLIC_SOCKET_APP_KEY' "$SECRETS_FILE")
export DB_NAME=$(yq '.db_name' "$SECRETS_FILE")
export DB_HOST=$(yq '.db_host' "$SECRETS_FILE")
export DB_USERNAME=$(yq '.db_username' "$SECRETS_FILE")
export DB_PASSWORD=$(yq '.db_password' "$SECRETS_FILE")

export MONGO_DB_NAME=$(yq '.mongo_db_name // "gadd_socket"' "$SECRETS_FILE")
export MONGO_USERNAME=$(yq '.mongo_username // "gadd_mongo"' "$SECRETS_FILE")
export MONGO_PASSWORD=$(yq '.mongo_password // "GaddMongoPass123!"' "$SECRETS_FILE")
export DB_NAME=$(yq '.db_name' "$SECRETS_FILE")
export DB_HOST=$(yq '.db_host' "$SECRETS_FILE")
export DB_USERNAME=$(yq '.db_username' "$SECRETS_FILE")
export DB_PASSWORD=$(yq '.db_password' "$SECRETS_FILE")

if ! command -v curl &> /dev/null; then 
    echo "[INFO] Installing curl..."
    apt-get update
    apt-get install -y curl
fi



if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "[ERROR] Secrets file not found: $SECRETS_FILE"
    exit 1
fi

while IFS='=' read -r key value; do
  [[ $key =~ ^[A-Z0-9_]+$ ]] || continue
  export "$key=$value"
done < <(grep -v '^#' .env | sed '/^\s*$/d')





install_basic_tools() {
    apt-get remove needrestart -y
    apt-get clean  
    apt-get update  
    # apt-get install -y software-properties-common zip unzip git gnupg  
    apt-get install -y software-properties-common gnupg lsb-release zip git 
}

remove_apache() {
    systemctl stop apache2       > /dev/null 2>&1 || true
    apt-get purge apache2* -y    > /dev/null 2>&1 || true
    apt-get autoremove -y        > /dev/null 2>&1 || true
}

install_nginx() {
    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx  
        systemctl enable nginx   
        systemctl restart nginx  
    fi
}

install_php() {

     local codename
    codename=$(lsb_release -sc)

    echo "[INFO] Detected Ubuntu codename $codename"

    if dpkg -s php${PHP_VERSION}-fpm &> /dev/null; then
        echo "[INFO] PHP ${PHP_VERSION}-fpm already installed"
        return
    fi

    if [ "$codename" = "jammy" ]; then
        echo "[INFO] Ubuntu 22.04 detected. Adding PPA with add-apt-repository..."
        add-apt-repository -y ppa:ondrej/php
    elif [ "$codename" = "noble" ]; then

    

    echo "[INFO] PHP ${PHP_VERSION} not found, installing..."

    apt-get install -y software-properties-common gnupg curl lsb-release

    echo "[INFO] Adding PHP PPA..."
    if ! timeout 10s add-apt-repository ppa:ondrej/php -y; then
        echo "[WARN] add-apt-repository failed or timed out. Using manual fallback..."

        # Write the PPA repo manually
        echo "deb [signed-by=/usr/share/keyrings/ondrej-php.gpg] http://ppa.launchpad.net/ondrej/php/ubuntu $(lsb_release -sc) main" \
            | tee /etc/apt/sources.list.d/ondrej-php.list

        # Receive and combine both public keys
        for key in 71DAEAAB4AD4CAB6 4F4EA0AAE5267A6C; do
            gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" || {
                echo "[ERROR] Failed to fetch GPG key: $key"
                exit 1
            }
        done

        # Export combined keyring
        gpg --export 71DAEAAB4AD4CAB6 4F4EA0AAE5267A6C \
            | gpg --dearmor  --yes --output /usr/share/keyrings/ondrej-php.gpg || {
            echo "[ERROR] Failed to create GPG keyring"
            exit 1
        }
    fi

    fi

    apt-get update || {
        echo "[ERROR] apt-get update failed"
        exit 1
    }

    echo "[INFO] Installing PHP ${PHP_VERSION} and extensions..."
    apt-get install -y \
        php${PHP_VERSION} php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-{bcmath,calendar,mbstring,gd,xml,curl,gettext,zip,soap,sqlite3,intl,exif,mysqli,mysql,readline,ssh2,dev} \
        php-pear || {
        echo "[ERROR] Failed to install PHP packages"
        exit 1
    }

    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm

    echo "[SUCCESS] PHP ${PHP_VERSION} installed and running"
}



install_composer() {
    if ! command -v composer &> /dev/null; then
        export COMPOSER_ALLOW_SUPERUSER=1
        echo "[info] Downloading the Composer installer..."
        curl -sS https://getcomposer.org/installer -o composer-setup.php

        echo "[info] Attempting Composer installation via installer..."
        if ! timeout 10s php composer-setup.php --install-dir=/usr/local/bin --filename=composer; then
            echo "[warn] Installer timed out or failed. Falling back to direct composer.phar download..."
            curl -sSL https://getcomposer.org/download/latest-stable/composer.phar -o /usr/local/bin/composer
            chmod +x /usr/local/bin/composer
        else
            echo "[success] Composer installed via installer."
        fi

        # Final verification
        if command -v composer &> /dev/null; then
            echo "[success] Composer version: $(composer --version)"
        else
            echo "[error] Composer installation failed!"
            exit 1
        fi
    else
        echo "[info] Composer is already installed: $(composer --version)"
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
    [ -d /var/www/html/supportad_backend ]  || \
      git clone https://${REPO_TOKEN}$@github.com/${REPO_USER}/supportad_backend.git \
      /var/www/html/supportad_backend 
    [ -d /var/www/html/supportad_frontend ] || \
      git clone https://${REPO_TOKEN}$@github.com/${REPO_USER}/supportad_frontend.git \
      /var/www/html/supportad_frontend  
}

setup_nginx_config() {
    if [ ! -f /etc/nginx/conf.d/supportad.conf ]; then
        rm -f /etc/nginx/sites-enabled/default
        cat <<EOF > /etc/nginx/conf.d/supportad.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/html/supportad_frontend/dist;
    index index.html;
    location / { try_files \$uri \$uri/ /index.html; }
    location /app {
        proxy_pass http://127.0.0.1:6001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location /backend {
        alias /var/www/html/supportad_backend/public;
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
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

    echo "[INFO] Creating or updating user..."
    mysql -u root -e "
        CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
        ALTER USER '${DB_USERNAME}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USERNAME}'@'${DB_HOST}';
        FLUSH PRIVILEGES;
    "
}


setup_laravel() {
    cd /var/www/html/supportad_backend || exit 1




    # Ensure .env exists with correct permissions
    if [ ! -f .env ]; then
        cp .env.example .env
        chown www-data:www-data .env
        chmod 664 .env
    fi

 
        set_env_var "DB_CONNECTION" "mysql"
        set_env_var "DB_HOST" "${DB_HOST}"
        set_env_var "DB_DATABASE" "${DB_NAME}"
        set_env_var "DB_USERNAME" "${DB_USERNAME}"
        set_env_var "DB_PASSWORD" "\"${DB_PASSWORD}"\"
        set_env_var "DB_PORT" "3306"
    
        

    # Laravel setup
    [ -d vendor ] || composer install --no-dev
    php artisan key:generate --force
    php artisan storage:link --force
    php artisan db:wipe
    php artisan migrate
    php artisan db:seed
    php artisan optimize

    # Set proper permissions
    chown -R www-data:www-data storage bootstrap/cache
    chmod -R 775 storage bootstrap/cache

}

# set_env_var() {
#     local key="$1"
#     local value="$2"
#     local file=".env"

#     # Escape backslashes and dollars for safety
#     value="${value//\\/\\\\}"
#     value="${value//\$/\\\$}"

#     # Uncomment if commented and replace value
#     if grep -Eq "^[# ]*${key}=.*" "$file"; then
#         sed -i "s|^[# ]*${key}=.*|${key}=${value}|" "$file"
#     elif ! grep -q "^${key}=" "$file"; then
#         echo "${key}=${value}" >> "$file"
#     fi
# }

get_env_var() {
    local key="$1"
    grep -E "^${key}=" .env | cut -d '=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/'
}




install_frontend_tools()
{
            # Install Node.js v22.12.0
    if command -v node &>/dev/null && node -v | grep -q "^v22\."; then
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
    if ! command -v dotenv-cli &>/dev/null; then
  npm install -g dotenv-cli > /dev/null 2>&1 || yarn global add dotenv-cli > /dev/null 2>&1
fi
    

if ! command -v pm2 &>/dev/null; then
  npm install -g pm2 > /dev/null 2>&1 || yarn global add pm2 > /dev/null 2>&1
fi
}

setup_frontend() {
    cd /var/www/html/supportad_frontend
        yarn install     
        yarn build       
        pm2 start npm --name nextjs -- start >/dev/null 2>&1 || true
}


# ---- MAIN ----
# install_basic_tools
# remove_apache
# install_nginx
# install_php
# install_composer
# install_mariadb
# clone_projects
# setup_nginx_config
setup_database
# install_frontend_tools
# setup_frontend
setup_laravel


echo "✅ Supportad full deployment completed!"