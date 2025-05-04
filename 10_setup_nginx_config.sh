#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

SECRETS_FILE="./config.yml"
export V_PHP_VERSION=$(yq '.php_version' "$SECRETS_FILE")
export DB_NAME=$(yq '.db_name' "$SECRETS_FILE")
export DB_HOST=$(yq '.db_host' "$SECRETS_FILE")
export DB_USERNAME=$(yq '.db_username' "$SECRETS_FILE")
export DB_PASSWORD=$(yq '.db_password' "$SECRETS_FILE")
export APP_URL=$(yq '.app_url' "$SECRETS_FILE")
export BB_USER=$(yq '.bitbucket_user' "$SECRETS_FILE")
export BB_TOKEN=$(yq '.bitbucket_token' "$SECRETS_FILE")


setup_nginx_config() {
if [ ! -f /etc/nginx/sites-available/gadd_agent ]; then
        rm -f /etc/nginx/sites-enabled/default
        cat <<EOF > /etc/nginx/sites-available/gadd_agent
server {
    listen 80;
    server_name localhost;
    root /var/www/html/gadd-agent-frontend/dist;
    index index.html;
    location / { try_files \$uri \$uri/ /index.html; }
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

setup_nginx_config
