#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

echo "🛢️ [11] Creating MySQL and MongoDB databases and users..."

SECRETS_FILE="./config.yml"
export DB_NAME=$(yq '.db_name' "$SECRETS_FILE")
export DB_HOST=$(yq '.db_host' "$SECRETS_FILE")
export DB_USERNAME=$(yq '.db_username' "$SECRETS_FILE")
export DB_PASSWORD=$(yq '.db_password' "$SECRETS_FILE")

export MONGO_DB_NAME=$(yq '.mongo_db_name // "gadd_socket"' "$SECRETS_FILE")
export MONGO_USERNAME=$(yq '.mongo_username // "gadd_mongo"' "$SECRETS_FILE")
export MONGO_PASSWORD=$(yq '.mongo_password // "GaddMongoPass123!"' "$SECRETS_FILE")

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
