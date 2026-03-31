#!/bin/bash

# =============================================================================
# Security Scanning Tools Setup
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Installs and configures security scanning tools
# Usage: ./tools/security/setup-security-tools.sh
# =============================================================================

set -e

echo "=== Installing Security Scanning Tools ==="

install_trivy() {
    echo "Installing Trivy..."
    if ! command -v trivy &> /dev/null; then
        TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep -oP '"tag_name": "\K[^"]+')
        curl -L "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-64bit.tar.gz" -o /tmp/trivy.tar.gz
        tar -xzf /tmp/trivy.tar.gz -C /tmp
        sudo mv /tmp/trivy /usr/local/bin/trivy
        rm /tmp/trivy.tar.gz
        echo "[OK] Trivy installed"
    else
        echo "[OK] Trivy already installed: $(trivy version)"
    fi
}

install_bandit() {
    echo "Installing Bandit..."
    if ! command -v bandit &> /dev/null; then
        pip3 install bandit bandit[toml]
        echo "[OK] Bandit installed"
    else
        echo "[OK] Bandit already installed: $(bandit --version)"
    fi
}

install_hadolint() {
    echo "Installing Hadolint..."
    if ! command -v hadolint &> /dev/null; then
        HADOLINT_VERSION=$(curl -s https://api.github.com/repos/hadolint/hadolint/releases/latest | grep -oP '"tag_name": "\K[^"]+')
        curl -L "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION#v}/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
        chmod +x /usr/local/bin/hadolint
        echo "[OK] Hadolint installed"
    else
        echo "[OK] Hadolint already installed: $(hadolint --version)"
    fi
}

install_semgrep() {
    echo "Installing Semgrep..."
    if ! command -v semgrep &> /dev/null; then
        pip3 install semgrep
        echo "[OK] Semgrep installed"
    else
        echo "[OK] Semgrep already installed: $(semgrep --version)"
    fi
}

install_checkov() {
    echo "Installing Checkov..."
    if ! command -v checkov &> /dev/null; then
        pip3 install checkov
        echo "[OK] Checkov installed"
    else
        echo "[OK] Checkov already installed: $(checkov --version)"
    fi
}

install_trivy
install_bandit
install_hadolint
install_semgrep
install_checkov

echo ""
echo "=== Security Tools Setup Complete ==="
