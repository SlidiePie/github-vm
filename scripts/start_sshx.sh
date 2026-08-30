#!/bin/bash
set -e

TIMEOUT_HOURS="${1:-6}"

echo "=========================================="
echo "Installing sshx..."
echo "=========================================="

curl -sSf https://sshx.io/get | sh

# Ensure sshx binary is in PATH
export PATH="$HOME/.sshx/bin:$PATH"

if ! command -v sshx &> /dev/null; then
    echo "ERROR: sshx installation failed."
    exit 1
fi

echo "Starting sshx..."
sshx > /tmp/sshx.log 2>&1 &
SSHX_PID=$!

echo "Waiting for sshx session URL..."
SSHX_URL=""
for i in {1..30}; do
    sleep 1
    if [ -f /tmp/sshx.log ]; then
        SSHX_URL=$(grep -o 'https://sshx.io/s/[^ ]*' /tmp/sshx.log | head -n 1 || true)
        if [ -n "$SSHX_URL" ]; then
            break
        fi
    fi
done

if [ -z "$SSHX_URL" ]; then
    echo "Could not capture sshx URL. Raw log:"
    cat /tmp/sshx.log
    exit 1
fi

echo ""
echo "================================================================="
echo " 🎉 SSHX TERMINAL IS READY!"
echo "================================================================="
echo ""
echo " 🌐 Terminal URL: $SSHX_URL"
echo ""
echo " Abre el enlace anterior en tu navegador para acceder a la terminal."
echo "================================================================="
echo ""

# Write to GitHub Step Summary
if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    cat << EOF >> "$GITHUB_STEP_SUMMARY"
# 🚀 Terminal Web (sshx) Lista

### 🌐 [Haz clic aquí para abrir la terminal web]($SSHX_URL)

**Enlace directo:**
\`$SSHX_URL\`

*La sesión permanecerá activa hasta ${TIMEOUT_HOURS} horas (o hasta que canceles el workflow).*
EOF
fi

# Keep alive loop
TOTAL_SECONDS=$(( TIMEOUT_HOURS * 3600 ))
START_TIME=$(date +%s)
END_TIME=$(( START_TIME + TOTAL_SECONDS ))

while [ $(date +%s) -lt $END_TIME ] && kill -0 $SSHX_PID 2>/dev/null; do
    REMAINING=$(( (END_TIME - $(date +%s)) / 60 ))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] sshx session active ($REMAINING min remaining)..."
    sleep 300
done

echo "Session finished."
