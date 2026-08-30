#!/bin/bash
set -e

NGROK_TOKEN="$1"
SSH_USER="${2:-runner}"
SSH_PASS="${3:-antigravity}"
TIMEOUT_HOURS="${4:-6}"

if [ -z "$NGROK_TOKEN" ]; then
    echo "ERROR: NGROK_AUTH_TOKEN is required! Please add it to your GitHub Repository Secrets."
    exit 1
fi

echo "=========================================="
echo "Installing and configuring ngrok..."
echo "=========================================="

OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Linux" ]; then
    if ! command -v ngrok &> /dev/null; then
        curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt-get update -qq && sudo apt-get install -y -qq ngrok
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    if ! command -v ngrok &> /dev/null; then
        brew install --cask ngrok || brew install ngrok
    fi
fi

# Configure authtoken
ngrok config add-authtoken "$NGROK_TOKEN"

# Start ngrok in background
echo "Starting ngrok TCP tunnel on port 22..."
ngrok tcp 22 --log=stdout > /tmp/ngrok.log 2>&1 &

# Wait for tunnel to establish
echo "Waiting for ngrok tunnel to be established..."
for i in {1..30}; do
    sleep 2
    TUNNEL_INFO=$(curl -s http://localhost:4040/api/tunnels || true)
    PUBLIC_URL=$(echo "$TUNNEL_INFO" | grep -o '"public_url":"tcp://[^"]*' | sed 's/"public_url":"tcp:\/\///' || true)
    if [ -n "$PUBLIC_URL" ]; then
        break
    fi
done

if [ -z "$PUBLIC_URL" ]; then
    echo "ERROR: Could not establish ngrok tunnel. Log output:"
    cat /tmp/ngrok.log
    exit 1
fi

SSH_HOST=$(echo "$PUBLIC_URL" | cut -d':' -f1)
SSH_PORT=$(echo "$PUBLIC_URL" | cut -d':' -f2)

echo ""
echo "================================================================="
echo " 🎉 SSH SERVER IS READY TO CONNECT!"
echo "================================================================="
echo ""
echo " 🌐 Host:     $SSH_HOST"
echo " 🔌 Port:     $SSH_PORT"
echo " 👤 User:     $SSH_USER"
echo " 🔑 Password: $SSH_PASS"
echo ""
echo " 🚀 Connect via Terminal / Antigravity:"
echo "    ssh $SSH_USER@$SSH_HOST -p $SSH_PORT"
echo ""
echo " ⚙️ VS Code / Antigravity ~/.ssh/config snippet:"
echo "    Host github-vm"
echo "        HostName $SSH_HOST"
echo "        Port $SSH_PORT"
echo "        User $SSH_USER"
echo "================================================================="
echo ""

# Write to GitHub Step Summary if running in GitHub Actions
if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    cat << EOF >> "$GITHUB_STEP_SUMMARY"
# 🚀 SSH Server Ready

### 📋 Connection Details
- **Host**: \`$SSH_HOST\`
- **Port**: \`$SSH_PORT\`
- **User**: \`$SSH_USER\`
- **Password**: \`$SSH_PASS\`

### 💻 Direct SSH Command
\`\`\`bash
ssh $SSH_USER@$SSH_HOST -p $SSH_PORT
\`\`\`

### ⚙️ Antigravity / SSH Config (\`~/.ssh/config\`)
\`\`\`ssh-config
Host github-vm
    HostName $SSH_HOST
    Port $SSH_PORT
    User $SSH_USER
\`\`\`

*Session will remain active for up to ${TIMEOUT_HOURS} hours (or until cancelled).*
EOF
fi

# Calculate sleep time in seconds
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
