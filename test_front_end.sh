#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

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
pm2 start server.js --name "$APP_NAME"

echo "💾 Saving PM2 process list..."
pm2 save

echo "✅ Done. Test at: http://<your-server-ip>/"
