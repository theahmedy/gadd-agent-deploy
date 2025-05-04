
# 🌐 Phase 02: Apache status check
echo "🌐 Checking Apache presence and activity..."

if dpkg -l | grep -q apache2; then
    echo "⚠️  Apache is installed."
    warn=true
else
    echo "✅  Apache package not installed."
fi

if systemctl list-units --type=service --all | grep -q apache2; then
    if systemctl is-active --quiet apache2; then
        echo "❌  Apache2 service is running!"
        warn=true
    else
        echo "✅  Apache2 service exists but not active."
    fi
else
    echo "✅  Apache2 service not registered."
fi

# ✅ Final status for Phase 02
if [ "$warn" = true ]; then
  echo "⚠️  Some Phase 02 checks failed. Please fix them before continuing."
else
  echo "🎉  All Phase 02 checks passed."
fi