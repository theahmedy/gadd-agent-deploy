#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR


SECRETS_FILE="./config.yml"
export DB_NAME=$(yq '.db_name' "$SECRETS_FILE")
export DB_HOST=$(yq '.db_host' "$SECRETS_FILE")
export DB_USERNAME=$(yq '.db_username' "$SECRETS_FILE")
export DB_PASSWORD=$(yq '.db_password' "$SECRETS_FILE")

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
