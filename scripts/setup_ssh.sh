#!/bin/bash
set -e

SSH_USER="${1:-runner}"
SSH_PASS="${2:-antigravity}"

echo "=========================================="
echo "Configuring SSH Server for user: $SSH_USER"
echo "=========================================="

OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Linux" ]; then
    # Ensure openssh-server is installed
    sudo apt-get update -qq && sudo apt-get install -y -qq openssh-server sshpass

    # Configure user password and unlock account
    echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
    sudo usermod -s /bin/bash "$SSH_USER"
    sudo passwd -u "$SSH_USER" || true
    
    # Ensure sudo permissions
    echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/99-runner-nopasswd > /dev/null
    
    # Clean up any restrictive cloud-init configs in sshd_config.d
    sudo rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf 2>/dev/null || true
    
    # Write custom sshd configuration that forces password authentication
    sudo mkdir -p /etc/ssh/sshd_config.d
    sudo tee /etc/ssh/sshd_config.d/00-antigravity.conf > /dev/null << 'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
ChallengeResponseAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes
UsePAM yes
EOF

    # Also update main sshd_config just in case
    sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
    sudo sed -i 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config || true
    sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
    sudo sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config || true

    # Add public key if provided
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        mkdir -p /home/$SSH_USER/.ssh
        echo "$SSH_PUBLIC_KEY" >> /home/$SSH_USER/.ssh/authorized_keys
        chmod 700 /home/$SSH_USER/.ssh
        chmod 600 /home/$SSH_USER/.ssh/authorized_keys
        chown -R $SSH_USER:$SSH_USER /home/$SSH_USER/.ssh
        echo "Added SSH public key to authorized_keys."
    fi
    
    # Restart SSH service & socket
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl restart ssh.socket ssh.service ssh 2>/dev/null || sudo service ssh restart
    
    # Test local SSH authentication
    echo "Testing local SSH authentication..."
    if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password,keyboard-interactive "$SSH_USER@127.0.0.1" "echo 'Local SSH authentication SUCCESS'" ; then
        echo "✅ OpenSSH Server is working and authenticated on Linux (port 22)."
    else
        echo "⚠️ Warning: Local test did not succeed, checking sshd logs..."
        sudo journalctl -u ssh -n 20 --no-pager || true
    fi

elif [ "$OS_TYPE" = "Darwin" ]; then
    echo "macOS detected: using key-based authentication (password change is restricted on macOS runners)."
    
    # Ensure .ssh dir exists for the runner user
    mkdir -p /Users/$SSH_USER/.ssh
    chmod 700 /Users/$SSH_USER/.ssh

    # Generate a temporary ED25519 key pair for this session
    TEMP_KEY="/tmp/runner_ssh_key_session"
    rm -f "$TEMP_KEY" "${TEMP_KEY}.pub"
    ssh-keygen -t ed25519 -f "$TEMP_KEY" -N "" -C "antigravity-session-$(date +%s)" -q

    # Install the public key
    cat "${TEMP_KEY}.pub" >> /Users/$SSH_USER/.ssh/authorized_keys
    chmod 600 /Users/$SSH_USER/.ssh/authorized_keys
    chown -R $SSH_USER /Users/$SSH_USER/.ssh

    # Also add user-provided public key if provided
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "$SSH_PUBLIC_KEY" >> /Users/$SSH_USER/.ssh/authorized_keys
        echo "Added your SSH_PUBLIC_KEY secret to authorized_keys."
    fi

    # Configure sshd to allow key-based auth
    sudo systemsetup -setremotelogin on 2>/dev/null || true
    sudo sed -i '' 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
    sudo sed -i '' 's/^#\?AuthorizedKeysFile .*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config 2>/dev/null || true

    # Restart sshd
    sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true

    # Export the private key path so start_tunnel.sh can print it
    export RUNNER_SSH_PRIVATE_KEY_FILE="$TEMP_KEY"
    export RUNNER_SSH_PRIVATE_KEY="$(cat $TEMP_KEY)"

    echo "✅ OpenSSH Server is active on macOS (port 22) with key-based authentication."
    echo ""
    echo "=== SESSION PRIVATE KEY (copy this to connect) ==="
    cat "$TEMP_KEY"
    echo "=== END OF PRIVATE KEY ==="

    # Write private key to GitHub Step Summary
    if [ -n "$GITHUB_STEP_SUMMARY" ]; then
        cat << 'KEYSUMMARY' >> "$GITHUB_STEP_SUMMARY"
## 🔑 Clave Privada SSH para macOS

Guarda esto en un archivo (ej: `C:\Users\Ivo\.ssh\github-vm-mac`) y dale permisos:

```
KEYSUMMARY
        cat "$TEMP_KEY" >> "$GITHUB_STEP_SUMMARY"
        cat << 'KEYSUMMARY' >> "$GITHUB_STEP_SUMMARY"
```

Luego conecta con:
```bash
ssh -i C:\Users\Ivo\.ssh\github-vm-mac runner@<HOST> -p <PUERTO>
```

O en `~/.ssh/config`:
```ssh-config
Host github-vm
    HostName <HOST>
    Port <PUERTO>
    User runner
    IdentityFile ~/.ssh/github-vm-mac
```
KEYSUMMARY
    fi
fi
