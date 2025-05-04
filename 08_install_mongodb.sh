#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

install_mongodb() {
    if command -v mongod &>/dev/null && command -v mongo &>/dev/null; then
        return
    fi

    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg --dearmor \
      | install -m 644 /dev/stdin /usr/share/keyrings/mongodb-server-6.0.gpg

    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-6.0.list

    apt-get update -qq
    apt-get install -y -qq mongodb-org mongodb-org-shell

    systemctl enable mongod
    systemctl start mongod
}

install_mongodb
