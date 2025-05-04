#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

SECRETS_FILE="./config.yml"

if ! command -v curl &> /dev/null; then
    apt-get update
    apt-get install -y curl
fi

if ! command -v yq &> /dev/null; then
    curl -sSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi

apt-get install -y software-properties-common zip unzip git gnupg
apt-get install -y libcairo2-dev libjpeg-dev libpango1.0-dev libgif-dev build-essential g++ pkg-config libpixman-1-dev