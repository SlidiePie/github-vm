#!/bin/bash
set -e

SSH_USER="${1:-runner}"
SSH_PASS="${2:-antigravity}"

echo "=========================================="
echo "Configuring SSH Server for user: $SSH_USER"
echo "=========================================="

OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Linux" ]; then
    # Ensure openssh-server is installed and running
    sudo apt-get update -qq && sudo apt-get install -y -qq openssh-server
    
    # Configure SSH password
    echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
    
    # Ensure sudo permissions
    echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/99-runner-nopasswd > /dev/null
    
    # Configure sshd
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config || true
    
    # Add public key if provided
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        mkdir -p ~/.ssh
        echo "$SSH_PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys
        echo "Added SSH public key to authorized_keys."
    fi
    
    # Restart SSH service
    sudo service ssh restart || sudo systemctl restart ssh
    echo "OpenSSH Server is active on Linux (port 22)."

elif [ "$OS_TYPE" = "Darwin" ]; then
    # macOS SSH setup
    echo "$SSH_PASS" | sudo dscl . -passwd /Users/$SSH_USER 2>/dev/null || true
    sudo systemsetup -setremotelogin on || true
    
    # Add public key if provided
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        mkdir -p ~/.ssh
        echo "$SSH_PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys
        echo "Added SSH public key to authorized_keys."
    fi
    echo "OpenSSH Server is active on macOS (port 22)."
fi
