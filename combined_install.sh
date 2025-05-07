#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR


if ! command -v curl &> /dev/null; then
    apt-get update
    apt-get install -y curl
fi

if ! command -v yq &> /dev/null; then
    curl -sSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi
export NODE_OPTIONS="--max-old-space-size=4096" # for build RAM
export COMPOSER_ALLOW_SUPERUSER=1
SECRETS_FILE="./config.yml"
export V_PHP_VERSION=$(yq '.php_version' "$SECRETS_FILE")
export BB_USER=$(yq '.bitbucket_user' "$SECRETS_FILE")
export BB_TOKEN=$(yq '.bitbucket_token' "$SECRETS_FILE")
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


apt-get install -y software-properties-common zip unzip git gnupg
apt-get install -y libcairo2-dev libjpeg-dev libpango1.0-dev libgif-dev build-essential g++ pkg-config libpixman-1-dev




    echo "🌐 [03] Checking and installing NGINX..."

    if ! command -v nginx &>/dev/null; then
        apt-get install -y nginx > /dev/null
    fi

    systemctl enable nginx
    systemctl restart nginx

    echo "🐘 [04] Installing PHP ${V_PHP_VERSION} and its extensions..."

    if ! command -v php &> /dev/null; then
        add-apt-repository ppa:ondrej/php -y
        apt-get update
        apt-get install -y php${V_PHP_VERSION}-fpm php-pear
    fi

    extensions=(bcmath calendar mbstring gd xml curl gettext zip soap intl exif mysql readline ssh2 dev)
    for ext in "${extensions[@]}"; do
        if ! php -m | grep -qw "$ext"; then
            apt-get install -y php${V_PHP_VERSION}-$ext
        else
            echo "✅ Extension: $ext"
        fi
    done

    systemctl enable php${V_PHP_VERSION}-fpm
    systemctl start php${V_PHP_VERSION}-fpm


     echo "🧩 [05] Installing MongoDB PHP extension v1.18.0..."

    if ! php -m | grep -q mongodb && ! pecl list | grep -q 'mongodb.*1.18.0'; then
    pecl channel-update pecl.php.net
    printf "\n" | pecl install mongodb-1.18.0 || true
    echo "extension=mongodb.so" > "/etc/php/${V_PHP_VERSION}/mods-available/mongodb.ini"
    phpenmod mongodb
    systemctl restart php${V_PHP_VERSION}-fpm

    fi

    if ! command -v composer &>/dev/null; then
        echo "🎼 [06] Installing Composer..."

    curl -sS https://getcomposer.org/installer -o composer-setup.php

    php composer-setup.php --install-dir=/usr/local/bin --filename=composer

    rm -f composer-setup.php

    fi

        # Install Node.js v22.12.0
    if ! command -v node &>/dev/null && node -v | grep -q "v22.12.0"; then

        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    fi

    # Install Yarn
    if ! command -v yarn &>/dev/null; then

        npm install -g yarn
    fi

if ! command -v pm2 &>/dev/null; then
  npm install -g pm2 > /dev/null 2>&1 || yarn global add pm2 > /dev/null 2>&1
fi

   if ! command -v mysql &>/dev/null; then
        apt-get install -y mariadb-server
        systemctl enable mariadb
        systemctl start mariadb
    fi


         if command -v mongod &>/dev/null && command -v mongo &>/dev/null; then
        return
    fi

    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg --dearmor \
      | install -m 644 /dev/stdin /usr/share/keyrings/mongodb-server-6.0.gpg

    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-6.0.list

    apt-get update -qq
    apt-get install -y -qq mongodb-org mongodb-org-shell

    systemctl enable mongod
    systemctl start mongod

    rm -rf /var/www/html/
    mkdir -p /var/www/html
    [ -d /var/www/html/gadd-agent-backend ]  || git clone https://${BB_USER}:${BB_TOKEN}@bitbucket.org/wakebtech/agi_services.git /var/www/html/gadd-agent-backend > /dev/null
    [ -d /var/www/html/gadd-agent-frontend ] || git clone --branch release/gad https://${BB_USER}:${BB_TOKEN}@bitbucket.org/wakebtech/wakeb_agi_react.git /var/www/html/gadd-agent-frontend > /dev/null
    [ -d /var/www/html/gadd-agent-socket ]   || git clone https://${BB_USER}:${BB_TOKEN}@bitbucket.org/wakebtech/nest-socket-wakeb.git /var/www/html/gadd-agent-socket > /dev/null

    cd /var/www/html/gadd-agent-socket
    yarn cache clean
    if [ ! -d node_modules ] || [ package.json -nt node_modules ] || [ yarn.lock -nt node_modules ]; then
        yarn install
    fi
    yarn cache clean
    yarn build
    pm2 start dist/main.js --name gadd-agent-socket >/dev/null 2>&1 || true


    cd /var/www/html/gadd-agent-frontend
    yarn cache clean
    if [ ! -d node_modules ] || [ package.json -nt node_modules ] || [ yarn.lock -nt node_modules ]; then
        yarn install
    fi
    cat <<EOF > .env
NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
NEXT_PUBLIC_SOCKET_URL=${NEXT_PUBLIC_SOCKET_URL}
NEXT_PUBLIC_SOCKET_APP_KEY=${NEXT_PUBLIC_SOCKET_APP_KEY}
EOF
    yarn cache clean
    yarn build
    pm2 start npm --name gadd-agent-frontend -- start || true


    cd /var/www/html/gadd-agent-backend
    if [ ! -d vendor ] || [ composer.json -nt vendor ] || [ composer.lock -nt vendor ]; then
        composer install --no-dev
    fi

    mysql -u root -e "DROP USER IF EXISTS '${DB_USERNAME}'@'${DB_HOST}';"

# 2️⃣ Create database if missing
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 3️⃣ Recreate user and grant privileges
mysql -u root <<EOF
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USERNAME}'@'${DB_HOST}';
FLUSH PRIVILEGES;
EOF

# 2️⃣ MongoDB shell detection
if command -v mongosh &>/dev/null; then
  SHELL_CLI="mongosh --quiet"
elif command -v mongo &>/dev/null; then
  SHELL_CLI="mongo --quiet"
else
  echo "❌ Neither mongosh nor mongo CLI found. Install mongodb-org-shell."
  exit 1
fi

# 3️⃣ MongoDB user creation (idempotent)
$SHELL_CLI <<EOF
use ${MONGO_DB_NAME}
if (!db.getUser("${MONGO_USERNAME}")) {
  db.createUser({
    user: "${MONGO_USERNAME}",
    pwd: "${MONGO_PASSWORD}",
    roles: [{ role: "readWrite", db: "${MONGO_DB_NAME}" }]
  })
}
EOF

cd /var/www/html/gadd-agent-backend

[ -f .env ] || cp .env.example .env

sed -i "s|^DB_HOST=.*|DB_HOST=${DB_HOST}|" .env
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USERNAME}|" .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=\"${DB_PASSWORD}\"|" .env

php artisan key:generate --force
php artisan storage:link --force
php artisan migrate --seed --force &> /dev/null || true
php artisan optimize &> /dev/null || true

chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache


# Remove default site if it exists
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default 2>/dev/null || true

# Write config if not already present
if [ ! -f "$NGINX_CONF_PATH" ]; then
cat <<EOF > "$NGINX_CONF_PATH"
server {
    listen 80;
    server_name localhost;

    root /var/www/html/gadd-agent-frontend/.next;

    index index.html index.htm index.php;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /app {
        proxy_pass http://127.0.0.1:6001;
        proxy_set_header Host \$host;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_cache_bypass \$http_upgrade;
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

        if (!-e \$request_filename) {
            rewrite ^/backend/(.*)\$ /backend/index.php?/\$1 last;
        }
    }
}
EOF
fi

# Reload nginx
nginx -t && systemctl restart nginx

mkdir -p /var/www/html/test



APP_DIR="/var/www/html/gadd-agent-frontend-test"
APP_NAME="gadd-agent-frontend-test"
APP_PORT=3000

echo "🛠️ Setting up simple Node.js server at $APP_DIR..."

mkdir -p "$APP_DIR"
cat <<'EOF' > "$APP_DIR/server.js"
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end('<h1>Hello World</h1>');
});

server.listen(3000, () => {
  console.log('✅ Test server running on http://localhost:3000');
});
EOF

# Set proper permissions
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

echo "🚀 Starting server with PM2..."
cd "$APP_DIR"
pm2 kill
pm2 start server.js --name "$APP_NAME"

echo "💾 Saving PM2 process list..."
pm2 save

echo "✅ Done. Test at: http://<your-server-ip>/"