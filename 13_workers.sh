#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

echo "⚙️ [16] Setting up Laravel queue worker using Supervisor..."

APP_DIR="/var/www/html/gadd-agent-backend"
QUEUE_WORKER_NAME="LARAVEL-QUEUE-WORKER"

Service_Path="/lib/systemd/system/${QUEUE_WORKER_NAME}.service"

if [ ! -f "$Service_Path" ]; then
  echo "➡️ Creating Service for Laravel worker..."

  cat <<EOF > "$Service_Path"
[Unit]
      Description=${QUEUE_WORKER_NAME}
      After=network.target

      [Service]
      ExecStart=/usr/bin/php ${APP_DIR}/artisan queue:work --sleep=3 --tries=3 --timeout=300
      WorkingDirectory=${APP_DIR}
      User=www-data
      Group=www-data
      Restart=always
      StandardOutput=syslog
      StandardError=syslog
      SyslogIdentifier=laravel-queue-worker

      [Install]
      WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "${QUEUE_WORKER_NAME}"
  systemctl start "${QUEUE_WORKER_NAME}"
else
  echo "✅ Service already exists for ${QUEUE_WORKER_NAME}."
fi

echo "🔁 Restarting worker..."
systemctl restart "${QUEUE_WORKER_NAME}"

echo "✅ Laravel queue worker setup complete."
