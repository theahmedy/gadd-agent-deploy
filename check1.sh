#!/usr/bin/env bash
set -euo pipefail

SECRETS_FILE="./config.yml"
echo "🔍  GADD Agent Pre-flight Check — Phase 01 (Basic Tools)"

warn=false

# 1️⃣ Check config file
if [ ! -f "$SECRETS_FILE" ]; then
  echo "❌  Missing $SECRETS_FILE"
  warn=true
else
  echo "✅  Found $SECRETS_FILE"
fi

# 2️⃣ Load values from config safely
required_keys=("php_version" "db_name" "db_host" "db_username" "db_password" "app_url" "bitbucket_user" "bitbucket_token")
for key in "${required_keys[@]}"; do
    value=$(yq ".$key" "$SECRETS_FILE" 2>/dev/null || echo "")
    if [ -z "$value" ] || [[ "$value" == "null" ]]; then
        echo "❌  Missing or empty key: $key in config.yml"
        warn=true
    else
        echo "✅  $key: $value"
    fi
done

# 3️⃣ Check required tools
echo "🔧 Checking essential commands:"
for cmd in curl yq git zip unzip add-apt-repository; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌  $cmd not found"
    warn=true
  else
    echo "✅  $cmd found"
  fi
done

# Final status
if [ "$warn" = true ]; then
  echo "⚠️  Some checks failed. Please fix them before continuing."
else
  echo "🎉  All Phase 01 checks passed."
fi


