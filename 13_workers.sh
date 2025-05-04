#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

echo "⚙️ [16] Setting up Laravel queue worker using Supervisor..."

APP_DIR="/var/www/html/gadd-agent-backend"
QUEUE_WORKER_NAME="gadd-agent-worker"

if ! command -v supervisorctl &>/dev/null; then
  echo "📦 Installing Supervisor..."
  apt-get install -y supervisor > /dev/null
fi

SUP_CONF="/etc/supervisor/conf.d/${QUEUE_WORKER_NAME}.conf"

if [ ! -f "$SUP_CONF" ]; then
  echo "➡️ Creating Supervisor config for Laravel worker..."

  cat <<EOF > "$SUP_CONF"
[program:${QUEUE_WORKER_NAME}]
process_name=%(program_name)s_%(process_num)02d
command=php ${APP_DIR}/artisan queue:work --sleep=3 --tries=3 --timeout=90
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=${APP_DIR}/storage/logs/queue-worker.log
EOF

  supervisorctl reread
  supervisorctl update
else
  echo "✅ Supervisor config already exists for ${QUEUE_WORKER_NAME}."
fi

echo "🔁 Restarting worker..."
supervisorctl restart "${QUEUE_WORKER_NAME}:*"

echo "✅ Laravel queue worker setup complete."
