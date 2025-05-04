#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

echo "📦 [09] Cloning and preparing projects..."

SECRETS_FILE="./config.yml"
export BB_USER=$(yq '.bitbucket_user' "$SECRETS_FILE")
export BB_TOKEN=$(yq '.bitbucket_token' "$SECRETS_FILE")
export NEXT_PUBLIC_API_URL=$(yq '.NEXT_PUBLIC_API_URL' "$SECRETS_FILE")
export NEXT_PUBLIC_SOCKET_URL=$(yq '.NEXT_PUBLIC_SOCKET_URL' "$SECRETS_FILE")
export NEXT_PUBLIC_SOCKET_APP_KEY=$(yq '.NEXT_PUBLIC_SOCKET_APP_KEY' "$SECRETS_FILE")
export COMPOSER_ALLOW_SUPERUSER=1

clone_projects() {
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
}

clone_projects