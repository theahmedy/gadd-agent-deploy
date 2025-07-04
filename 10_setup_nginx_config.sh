#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

SECRETS_FILE="./config.yml"
export PHP_VERSION=$(yq '.php_version' "$SECRETS_FILE")

NGINX_CONF_PATH="/etc/nginx/conf.d/gadd_agent.conf"

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
            fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
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
