#!/bin/bash

# =============================================================================
# Linting Tools Setup
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Installs and configures linting tools
# Usage: ./tools/linters/setup-linters.sh
# =============================================================================

set -e

echo "=== Installing Linting Tools ==="

install_ruff() {
    echo "Installing Ruff (Python linter)..."
    if ! command -v ruff &> /dev/null; then
        pip3 install ruff
        echo "[OK] Ruff installed"
    else
        echo "[OK] Ruff already installed: $(ruff --version)"
    fi
}

install_shellcheck() {
    echo "Installing ShellCheck..."
    if ! command -v shellcheck &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y shellcheck
        fi
        echo "[OK] ShellCheck installed"
    else
        echo "[OK] ShellCheck already installed: $(shellcheck --version)"
    fi
}

install_yaml_lint() {
    echo "Installing YAML Lint..."
    if ! command -v yamllint &> /dev/null; then
        pip3 install yamllint
        echo "[OK] yamllint installed"
    else
        echo "[OK] yamllint already installed: $(yamllint --version)"
    fi
}

install_ansible_lint() {
    echo "Installing Ansible Lint..."
    if ! command -v ansible-lint &> /dev/null; then
        pip3 install ansible-lint
        echo "[OK] ansible-lint installed"
    else
        echo "[OK] ansible-lint already installed: $(ansible-lint --version)"
    fi
}

install_ruff
install_shellcheck
install_yaml_lint
install_ansible_lint

echo ""
echo "=== Linting Tools Setup Complete ==="
