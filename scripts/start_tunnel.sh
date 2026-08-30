#!/bin/bash
set -e

NGROK_TOKEN="$1"
SSH_USER="${2:-runner}"
SSH_PASS="${3:-antigravity}"
TIMEOUT_HOURS="${4:-6}"

OS_TYPE="$(uname -s)"
SSH_HOST=""
SSH_PORT=""
PROVIDER=""

if [ -n "$NGROK_TOKEN" ]; then
    echo "=========================================="
    echo "Starting tunnel with ngrok..."
    echo "=========================================="

    if [ "$OS_TYPE" = "Linux" ]; then
        if ! command -v ngrok &> /dev/null; then
            curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
            echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
            sudo apt-get update -qq && sudo apt-get install -y -qq ngrok
        fi
    elif [ "$OS_TYPE" = "Darwin" ]; then
        if ! command -v ngrok &> /dev/null; then
            brew install --cask ngrok 2>/dev/null || brew install ngrok 2>/dev/null || true
        fi
    fi

    ngrok config add-authtoken "$NGROK_TOKEN" 2>/dev/null || true
    ngrok tcp 22 --log=stdout > /tmp/ngrok.log 2>&1 &
    
    echo "Waiting for ngrok tunnel..."
    for i in {1..20}; do
        sleep 2
        TUNNEL_INFO=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null || true)
        PUBLIC_URL=$(echo "$TUNNEL_INFO" | grep -o '"public_url":"tcp://[^"]*' | sed 's/"public_url":"tcp:\/\///' || true)
        if [ -n "$PUBLIC_URL" ]; then
            SSH_HOST=$(echo "$PUBLIC_URL" | cut -d':' -f1)
            SSH_PORT=$(echo "$PUBLIC_URL" | cut -d':' -f2)
            PROVIDER="ngrok"
            break
        fi
    done
fi

# Fallback to Pinggy if ngrok was not configured or didn't connect
if [ -z "$SSH_HOST" ]; then
    echo "=========================================="
    echo "Starting tunnel with Pinggy (zero-config)..."
    echo "=========================================="
    
    # Run pinggy tcp tunnel
    ssh -p 443 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R0:localhost:22 tcp@a.pinggy.io > /tmp/pinggy.log 2>&1 &
    PINGGY_PID=$!
    
    echo "Waiting for Pinggy tunnel..."
    for i in {1..20}; do
        sleep 2
        if [ -f /tmp/pinggy.log ]; then
            PINGGY_LINE=$(grep -o 'tcp://[^ ]*' /tmp/pinggy.log | head -n 1 || true)
            if [ -z "$PINGGY_LINE" ]; then
                PINGGY_LINE=$(grep -o '[a-z0-9.-]*\.pinggy\.link:[0-9]*' /tmp/pinggy.log | head -n 1 || true)
            fi
            if [ -n "$PINGGY_LINE" ]; then
                CLEAN_URL=$(echo "$PINGGY_LINE" | sed 's/tcp:\/\///')
                SSH_HOST=$(echo "$CLEAN_URL" | cut -d':' -f1)
                SSH_PORT=$(echo "$CLEAN_URL" | cut -d':' -f2)
                PROVIDER="pinggy"
                break
            fi
        fi
    done
fi

if [ -z "$SSH_HOST" ]; then
    echo "ERROR: Failed to establish SSH tunnel."
    echo "=== ngrok log ==="
    cat /tmp/ngrok.log 2>/dev/null || true
    echo "=== pinggy log ==="
    cat /tmp/pinggy.log 2>/dev/null || true
    exit 1
fi

echo ""
echo "================================================================="
echo " 🎉 SSH SERVER IS READY TO CONNECT ($PROVIDER)!"
echo "================================================================="
echo ""
echo " 🌐 Host:     $SSH_HOST"
echo " 🔌 Port:     $SSH_PORT"
echo " 👤 User:     $SSH_USER"
echo " 🔑 Password: $SSH_PASS"
echo ""
echo " 🚀 Comando SSH directo (Terminal / Antigravity):"
echo "    ssh $SSH_USER@$SSH_HOST -p $SSH_PORT"
echo ""
echo " ⚙️ Configuración ~/.ssh/config:"
echo "    Host github-vm"
echo "        HostName $SSH_HOST"
echo "        Port $SSH_PORT"
echo "        User $SSH_USER"
echo "================================================================="
echo ""

# Write to GitHub Step Summary
if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    cat << EOF >> "$GITHUB_STEP_SUMMARY"
# 🚀 SSH Server Listo ($PROVIDER)

### 📋 Datos de Conexión
- **Host**: \`$SSH_HOST\`
- **Port**: \`$SSH_PORT\`
- **User**: \`$SSH_USER\`
- **Password**: \`$SSH_PASS\`

### 💻 Comando SSH Directo
\`\`\`bash
ssh $SSH_USER@$SSH_HOST -p $SSH_PORT
\`\`\`

### ⚙️ Configuración para Antigravity (\`~/.ssh/config\`)
\`\`\`ssh-config
Host github-vm
    HostName $SSH_HOST
    Port $SSH_PORT
    User $SSH_USER
\`\`\`

*Sesión activa durante ${TIMEOUT_HOURS} horas.*
EOF
fi

# Keep alive loop
TOTAL_SECONDS=$(( TIMEOUT_HOURS * 3600 ))
START_TIME=$(date +%s)
END_TIME=$(( START_TIME + TOTAL_SECONDS ))

echo "SSH Session active. Keeping alive for $TIMEOUT_HOURS hours..."

while [ $(date +%s) -lt $END_TIME ]; do
    REMAINING=$(( (END_TIME - $(date +%s)) / 60 ))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH Session active ($REMAINING min remaining)..."
    sleep 300
done

echo "Session time expired."
