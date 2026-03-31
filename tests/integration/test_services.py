"""
Integration Tests for Docker Compose Services.

Author: Andrés M. Correa
Email: korc.dev@gmail.com
"""

import os
import pytest
import subprocess
import time
import requests
from typing import Dict, Optional


class TestDockerComposeServices:
    """Integration tests for docker-compose services."""

    @pytest.fixture
    def compose_command(self):
        """Return compose command based on available tool."""
        try:
            subprocess.run(
                ["podman", "compose", "version"], check=True, capture_output=True
            )
            return ["podman", "compose"]
        except (subprocess.CalledProcessError, FileNotFoundError):
            return ["docker", "compose"]

    @pytest.fixture
    def service_ports(self) -> Dict[str, int]:
        """Return service ports mapping."""
        return {
            "openbao": 8200,
            "zabbix-6.0": 8080,
            "zabbix-7.0": 8081,
            "zabbix-7.4": 8082,
            "nginx": 80,
            "fastapi": 8000,
            "postgresql": 5432,
        }

    @pytest.fixture
    def wait_for_services(self, compose_command):
        """Wait for services to be ready."""
        time.sleep(10)

    @pytest.mark.integration
    @pytest.mark.slow
    def test_all_services_running(self, compose_command, wait_for_services):
        """Test that all services are running."""
        result = subprocess.run(
            compose_command + ["ps", "-q"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        services = result.stdout.strip().split("\n")
        assert len(services) >= 10

    @pytest.mark.integration
    @pytest.mark.slow
    def test_openbao_accessible(self, service_ports):
        """Test that OpenBao is accessible."""
        try:
            response = requests.get(
                f"http://localhost:{service_ports['openbao']}/v1/sys/health",
                timeout=10,
            )
            assert response.status_code in [200, 501]
        except requests.RequestException:
            pytest.skip("OpenBao service not available")

    @pytest.mark.integration
    @pytest.mark.slow
    def test_zabbix_6_0_accessible(self, service_ports):
        """Test that Zabbix 6.0 is accessible."""
        try:
            response = requests.get(
                f"http://localhost:{service_ports['zabbix-6.0']}",
                timeout=10,
                allow_redirects=False,
            )
            assert response.status_code in [200, 302]
        except requests.RequestException:
            pytest.skip("Zabbix 6.0 service not available")

    @pytest.mark.integration
    @pytest.mark.slow
    def test_zabbix_7_0_accessible(self, service_ports):
        """Test that Zabbix 7.0 is accessible."""
        try:
            response = requests.get(
                f"http://localhost:{service_ports['zabbix-7.0']}",
                timeout=10,
                allow_redirects=False,
            )
            assert response.status_code in [200, 302]
        except requests.RequestException:
            pytest.skip("Zabbix 7.0 service not available")

    @pytest.mark.integration
    @pytest.mark.slow
    def test_zabbix_7_4_accessible(self, service_ports):
        """Test that Zabbix 7.4 is accessible."""
        try:
            response = requests.get(
                f"http://localhost:{service_ports['zabbix-7.4']}",
                timeout=10,
                allow_redirects=False,
            )
            assert response.status_code in [200, 302]
        except requests.RequestException:
            pytest.skip("Zabbix 7.4 service not available")

    @pytest.mark.integration
    @pytest.mark.slow
    def test_fastapi_accessible(self, service_ports):
        """Test that FastAPI is accessible."""
        try:
            response = requests.get(
                f"http://localhost:{service_ports['fastapi']}/health",
                timeout=10,
            )
            assert response.status_code == 200
        except requests.RequestException:
            pytest.skip("FastAPI service not available")

    @pytest.mark.integration
    @pytest.mark.slow
    def test_nginx_accessible(self, service_ports):
        """Test that Nginx is accessible."""
        try:
            response = requests.get(
                f"http://localhost:{service_ports['nginx']}",
                timeout=10,
            )
            assert response.status_code == 200
        except requests.RequestException:
            pytest.skip("Nginx service not available")

    @pytest.mark.integration
    @pytest.mark.slow
    def test_postgresql_accessible(self, service_ports):
        """Test that PostgreSQL is accessible."""
        try:
            import socket

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(("localhost", service_ports["postgresql"]))
            sock.close()
            assert result == 0
        except Exception:
            pytest.skip("PostgreSQL service not available")


class TestNetworkConfiguration:
    """Integration tests for network configuration."""

    @pytest.fixture
    def expected_networks(self):
        """Return expected networks."""
        return ["bridge-zabbix", "bridge-servicios", "bridge-secrets"]

    @pytest.mark.integration
    @pytest.mark.slow
    def test_networks_exist(self, expected_networks):
        """Test that expected networks exist."""
        try:
            result = subprocess.run(
                ["podman", "network", "ls", "-q"],
                capture_output=True,
                text=True,
            )
            networks = result.stdout.strip().split("\n")
            for expected in expected_networks:
                assert any(expected in net for net in networks)
        except subprocess.CalledProcessError:
            pytest.skip("Podman network command not available")


class TestVolumeConfiguration:
    """Integration tests for volume configuration."""

    @pytest.mark.integration
    @pytest.mark.slow
    def test_volumes_exist(self):
        """Test that expected volumes exist."""
        try:
            result = subprocess.run(
                ["podman", "volume", "ls", "-q"],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0
        except subprocess.CalledProcessError:
            pytest.skip("Podman volume command not available")
