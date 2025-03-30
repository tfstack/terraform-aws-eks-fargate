#!/bin/bash

set -e

LOG_FILE="/var/log/user-data.log"

# Ensure the log file exists
touch "$LOG_FILE"
chmod 0644 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "==== Starting User Data Script ===="

# Create install-kubectl script
echo "Creating /usr/local/bin/install-kubectl..."
sudo tee /usr/local/bin/install-kubectl >/dev/null <<'EOF'
#!/bin/bash
set -e
INSTALL_SCRIPT="/tmp/install_kubectl.sh"

curl -s -o "$INSTALL_SCRIPT" https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_kubectl.sh
if [ ! -s "$INSTALL_SCRIPT" ]; then
    echo "Failed to download install_kubectl.sh" >&2
    exit 1
fi

bash "$INSTALL_SCRIPT" "$@"
EOF
sudo chmod 0755 /usr/local/bin/install-kubectl

# Create MOTD message
echo "Creating /etc/update-motd.d/99-kubectl-motd..."
sudo tee /etc/update-motd.d/99-kubectl-motd >/dev/null <<'EOF'
#!/bin/bash
echo "kubectl is ready! Use:"
echo ""
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl apply -f my-config.yaml"
echo ""
echo "  install-kubectl  # Install or update kubectl"
echo "  kubectl version --client  # Verify installation"
echo ""
EOF
sudo chmod 0755 /etc/update-motd.d/99-kubectl-motd

# Run kubectl installation
echo "Running install-kubectl..."
if /usr/local/bin/install-kubectl; then
    echo "kubectl installation completed successfully."
else
    echo "kubectl installation failed." >&2
    exit 1
fi

echo "==== User Data Script Completed ===="
