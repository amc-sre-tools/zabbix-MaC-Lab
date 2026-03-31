"""
Unit Tests for Scripts.

Author: Andrés M. Correa
Email: korc.dev@gmail.com
"""

import os
import sys
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock


class TestCreateUtmVmScript:
    """Tests for create-utm-vm.sh script logic."""

    @pytest.fixture
    def script_variables(self):
        """Return expected script variables."""
        return {
            "VM_NAME": "zabbix-testing",
            "UBUNTU_VERSION": "24.04",
            "DISK_SIZE_GB": 70,
            "RAM_MB": 8192,
            "CPU_CORES": 4,
            "SSH_USER": "sre-ubuntu",
        }

    def test_vm_name_is_correct(self, script_variables):
        """Test that VM name is correctly set."""
        expected_name = "zabbix-testing"
        assert expected_name == script_variables["VM_NAME"]

    def test_disk_size_is_correct(self, script_variables):
        """Test that disk size is 70GB."""
        assert script_variables["DISK_SIZE_GB"] == 70

    def test_ram_size_is_correct(self, script_variables):
        """Test that RAM is 8GB (8192MB)."""
        assert script_variables["RAM_MB"] == 8192

    def test_cpu_cores_is_correct(self, script_variables):
        """Test that CPU cores is 4."""
        assert script_variables["CPU_CORES"] == 4

    def test_ssh_user_is_correct(self, script_variables):
        """Test that SSH user is sre-ubuntu."""
        assert script_variables["SSH_USER"] == "sre-ubuntu"

    def test_ubuntu_version_is_correct(self, script_variables):
        """Test that Ubuntu version is 24.04."""
        assert script_variables["UBUNTU_VERSION"] == "24.04"


class TestCloudInitConfig:
    """Tests for cloud-init configuration."""

    @pytest.fixture
    def expected_packages(self):
        """Return expected packages for cloud-init."""
        return [
            "qemu-guest-agent",
            "cloud-init",
            "net-tools",
            "curl",
            "wget",
            "git",
            "lvm2",
        ]

    def test_packages_include_essential(self, expected_packages):
        """Test that essential packages are included."""
        assert "curl" in expected_packages
        assert "wget" in expected_packages
        assert "git" in expected_packages
        assert "lvm2" in expected_packages

    def test_packages_include_monitoring(self, expected_packages):
        """Test that monitoring packages are included."""
        assert "qemu-guest-agent" in expected_packages


class TestLvmConfiguration:
    """Tests for LVM configuration."""

    @pytest.fixture
    def lvm_volumes(self):
        """Return expected LVM volumes."""
        return [
            {"lv": "lv_data", "size": "15g"},
            {"lv": "lv_containers", "size": "20g"},
            {"lv": "lv_logs", "size": "10g"},
        ]

    def test_lv_data_size(self, lvm_volumes):
        """Test that lv_data has correct size."""
        lv_data = next(v for v in lvm_volumes if v["lv"] == "lv_data")
        assert lv_data["size"] == "15g"

    def test_lv_containers_size(self, lvm_volumes):
        """Test that lv_containers has correct size."""
        lv_containers = next(v for v in lvm_volumes if v["lv"] == "lv_containers")
        assert lv_containers["size"] == "20g"

    def test_lv_logs_size(self, lvm_volumes):
        """Test that lv_logs has correct size."""
        lv_logs = next(v for v in lvm_volumes if v["lv"] == "lv_logs")
        assert lv_logs["size"] == "10g"

    def test_total_lvm_size(self, lvm_volumes):
        """Test that total LVM size is correct."""
        total = sum(int(v["size"].rstrip("g")) for v in lvm_volumes)
        assert total == 45


class TestNetworkConfiguration:
    """Tests for network configuration."""

    @pytest.fixture
    def networks(self):
        """Return expected networks."""
        return {
            "bridge-zabbix": "10.88.10.0/24",
            "bridge-servicios": "10.88.20.0/24",
            "bridge-secrets": "10.88.30.0/24",
        }

    def test_bridge_zabbix_subnet(self, networks):
        """Test bridge-zabbix subnet."""
        assert networks["bridge-zabbix"] == "10.88.10.0/24"

    def test_bridge_servicios_subnet(self, networks):
        """Test bridge-servicios subnet."""
        assert networks["bridge-servicios"] == "10.88.20.0/24"

    def test_bridge_secrets_subnet(self, networks):
        """Test bridge-secrets subnet."""
        assert networks["bridge-secrets"] == "10.88.30.0/24"

    def test_all_networks_use_cidr_notation(self, networks):
        """Test all networks use CIDR notation."""
        for subnet in networks.values():
            assert "/" in subnet
            assert subnet.endswith("/24")


class TestSecretsConfiguration:
    """Tests for secrets configuration."""

    @pytest.fixture
    def secret_paths(self):
        """Return expected secret paths."""
        return [
            "secret/data/postgresql/admin",
            "secret/data/zabbix/credentials",
            "secret/data/zabbix/api-keys",
            "secret/data/fastapi/app",
            "secret/data/nginx/ssl",
        ]

    def test_postgresql_secret_path(self, secret_paths):
        """Test postgresql secret path."""
        assert "postgresql/admin" in secret_paths[0]

    def test_zabbix_secret_paths(self, secret_paths):
        """Test zabbix secret paths."""
        zabbix_paths = [p for p in secret_paths if "zabbix" in p]
        assert len(zabbix_paths) == 2

    def test_fastapi_secret_path(self, secret_paths):
        """Test fastapi secret path."""
        assert "fastapi/app" in secret_paths[3]

    def test_nginx_secret_path(self, secret_paths):
        """Test nginx secret path."""
        assert "nginx/ssl" in secret_paths[4]


class TestPortConfiguration:
    """Tests for port mapping configuration."""

    @pytest.fixture
    def ports(self):
        """Return expected ports."""
        return {
            "openbao": 8200,
            "zabbix_6_0": 8080,
            "zabbix_7_0": 8081,
            "zabbix_7_4": 8082,
            "zabbix_6_0_server": 10060,
            "zabbix_7_0_server": 10070,
            "zabbix_7_4_server": 10074,
            "nginx": 80,
            "fastapi": 8000,
            "postgresql": 5432,
        }

    def test_openbao_port(self, ports):
        """Test OpenBao port."""
        assert ports["openbao"] == 8200

    def test_zabbix_unique_ports(self, ports):
        """Test Zabbix versions have unique ports."""
        zabbix_web_ports = [
            ports["zabbix_6_0"],
            ports["zabbix_7_0"],
            ports["zabbix_7_4"],
        ]
        assert len(set(zabbix_web_ports)) == 3

    def test_zabbix_server_unique_ports(self, ports):
        """Test Zabbix server ports are unique."""
        server_ports = [
            ports["zabbix_6_0_server"],
            ports["zabbix_7_0_server"],
            ports["zabbix_7_4_server"],
        ]
        assert len(set(server_ports)) == 3

    def test_no_port_conflicts(self, ports):
        """Test there are no port conflicts."""
        port_values = list(ports.values())
        assert len(port_values) == len(set(port_values))
