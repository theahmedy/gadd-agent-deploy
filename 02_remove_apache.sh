#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR



remove_apache() {
    echo "🔧 [02] Removing Apache if installed..."

    if systemctl is-active --quiet apache2; then
        echo "➡️ Stopping Apache service..."
        systemctl stop apache2
    fi

    if dpkg -l | grep -q apache2; then
        echo "➡️ Purging apache2 packages..."
        apt-get purge -y apache2* > /dev/null
        echo "➡️ Running autoremove..."
        apt-get autoremove -y > /dev/null
        echo "✅ Apache removed successfully."
    else
        echo "ℹ️ Apache is not installed. Skipping removal."
    fi
}

remove_apache
