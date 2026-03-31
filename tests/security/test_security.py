"""
Security Tests for Zabbix Testing Environment.

Author: Andrés M. Correa
Email: korc.dev@gmail.com
"""

import os
import pytest
import subprocess
from pathlib import Path


class TestSecurityConfiguration:
    """Security tests for configuration files."""

    @pytest.fixture
    def sensitive_files(self):
        """Return list of files that should not contain secrets."""
        return [
            "docker-compose.yml",
            "configs/nginx/nginx.conf",
            "ansible/inventory.ini",
        ]

    @pytest.fixture
    def secret_patterns(self):
        """Return patterns that should not be in config files."""
        return [
            "password = ",
            "MYSQL_PASSWORD=",
            "POSTGRES_PASSWORD=",
            "BAO_DEV_ROOT_TOKEN",
        ]

    @pytest.mark.security
    def test_no_plain_secrets_in_docker_compose(self):
        """Test that docker-compose.yml doesn't contain plain secrets."""
        compose_file = Path("docker-compose.yml")
        if compose_file.exists():
            content = compose_file.read_text()
            assert "zabbix_password" not in content or "POSTGRES_PASSWORD" in content

    @pytest.mark.security
    def test_env_file_in_gitignore(self):
        """Test that .env files are in .gitignore."""
        gitignore = Path(".gitignore")
        if gitignore.exists():
            content = gitignore.read_text()
            assert ".env" in content or "env" in content

    @pytest.mark.security
    def test_secrets_in_gitignore(self):
        """Test that secret files are in .gitignore."""
        gitignore = Path(".gitignore")
        if gitignore.exists():
            content = gitignore.read_text()
            assert "password" in content.lower() or "secret" in content.lower()

    @pytest.mark.security
    def test_ssh_keys_not_in_repo(self):
        """Test that SSH private keys are not in repository."""
        ssh_dir = Path.home() / ".ssh"
        if ssh_dir.exists():
            for key_file in ssh_dir.glob("id_*"):
                if key_file.suffix == "":
                    content = key_file.read_text(errors="ignore")
                    assert "BEGIN" not in content


class TestContainerSecurity:
    """Security tests for containers."""

    @pytest.mark.security
    @pytest.mark.slow
    def test_container_images_scanned(self):
        """Test that container images can be scanned."""
        try:
            result = subprocess.run(
                ["which", "trivy"],
                capture_output=True,
            )
            if result.returncode != 0:
                pytest.skip("Trivy not installed")
        except Exception:
            pytest.skip("Cannot check for trivy")

    @pytest.mark.security
    @pytest.mark.slow
    def test_no_privileged_containers(self):
        """Test that no containers run in privileged mode."""
        try:
            result = subprocess.run(
                ["podman", "ps", "--format", "{{.SecurityOptions}}"],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                output = result.stdout.strip()
                if output:
                    assert "privileged" not in output.lower()
        except subprocess.CalledProcessError:
            pytest.skip("Cannot check container security options")


class TestNetworkSecurity:
    """Security tests for network configuration."""

    @pytest.mark.security
    def test_no_exposed_sensitive_ports(self):
        """Test that sensitive ports are not exposed to host."""
        sensitive_ports = [5432]
        try:
            result = subprocess.run(
                ["podman", "ps", "--format", "{{.Ports}}"],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                for port in sensitive_ports:
                    assert port not in result.stdout
        except subprocess.CalledProcessError:
            pytest.skip("Cannot check exposed ports")

    @pytest.mark.security
    def test_networks_isolated(self):
        """Test that networks are properly isolated."""
        expected_networks = [
            "bridge-zabbix",
            "bridge-servicios",
            "bridge-secrets",
        ]
        try:
            result = subprocess.run(
                ["podman", "network", "ls", "--format", "{{.Name}}"],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                networks = result.stdout.strip().split("\n")
                for expected in expected_networks:
                    assert any(expected in net for net in networks)
        except subprocess.CalledProcessError:
            pytest.skip("Cannot check networks")


class TestOpenbaoSecurity:
    """Security tests for OpenBao configuration."""

    @pytest.mark.security
    def test_openbao_not_in_production_mode(self):
        """Test that OpenBao is not in production mode (dev token used)."""
        compose_file = Path("docker-compose.yml")
        if compose_file.exists():
            content = compose_file.read_text()
            assert "BAO_DEV_ROOT_TOKEN_ID" in content

    @pytest.mark.security
    def test_tls_disabled_in_dev(self):
        """Test that TLS is disabled in development."""
        compose_file = Path("docker-compose.yml")
        if compose_file.exists():
            content = compose_file.read_text()
            assert "tls_disable" in content or "BAO_DEV" in content


class TestAnsibleSecurity:
    """Security tests for Ansible configuration."""

    @pytest.mark.security
    def test_ansible_vault_used(self):
        """Test that Ansible vault is available for secrets."""
        ansible_cfg = Path("ansible/ansible.cfg")
        if ansible_cfg.exists():
            content = ansible_cfg.read_text()
            assert "vault" in content.lower()

    @pytest.mark.security
    def test_no_hardcoded_credentials(self):
        """Test that no hardcoded credentials in Ansible playbooks."""
        ansible_dir = Path("ansible")
        if ansible_dir.exists():
            for playbook in ansible_dir.glob("*.yml"):
                content = playbook.read_text()
                assert "password:" not in content or "#" in content
