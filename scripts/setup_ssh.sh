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
    # macOS SSH setup
    echo "$SSH_PASS" | sudo dscl . -passwd /Users/$SSH_USER 2>/dev/null || true
    sudo systemsetup -setremotelogin on || true
    
    # Add public key if provided
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        mkdir -p /Users/$SSH_USER/.ssh
        echo "$SSH_PUBLIC_KEY" >> /Users/$SSH_USER/.ssh/authorized_keys
        chmod 700 /Users/$SSH_USER/.ssh
        chmod 600 /Users/$SSH_USER/.ssh/authorized_keys
        chown -R $SSH_USER /Users/$SSH_USER/.ssh
        echo "Added SSH public key to authorized_keys."
    fi
    echo "OpenSSH Server is active on macOS (port 22)."
fi
