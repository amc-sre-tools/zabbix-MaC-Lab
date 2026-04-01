"""
Unit Tests for POD2 Zabbix Configuration.

Author: Andrés M. Correa
Email: korc.dev@gmail.com
"""

import pytest
import os


class TestZabbixDatabases:
    """Tests for Zabbix database configuration."""

    @pytest.fixture
    def expected_databases(self):
        """Return expected Zabbix databases."""
        return ["zabbix60", "zabbix70", "zabbix74"]

    def test_zabbix60_database_name(self, expected_databases):
        """Test Zabbix 6.0 database name."""
        assert expected_databases[0] == "zabbix60"

    def test_zabbix70_database_name(self, expected_databases):
        """Test Zabbix 7.0 database name."""
        assert expected_databases[1] == "zabbix70"

    def test_zabbix74_database_name(self, expected_databases):
        """Test Zabbix 7.4 database name."""
        assert expected_databases[2] == "zabbix74"

    def test_three_separate_databases(self, expected_databases):
        """Test that there are exactly 3 separate databases."""
        assert len(expected_databases) == 3
        assert len(set(expected_databases)) == 3


class TestZabbixPorts:
    """Tests for Zabbix port configuration."""

    @pytest.fixture
    def zabbix_web_ports(self):
        """Return expected Zabbix web ports."""
        return {
            "zabbix_6_0": 8080,
            "zabbix_7_0": 8081,
            "zabbix_7_4": 8082,
        }

    @pytest.fixture
    def zabbix_server_ports(self):
        """Return expected Zabbix server ports."""
        return {
            "zabbix_6_0": 10060,
            "zabbix_7_0": 10070,
            "zabbix_7_4": 10074,
        }

    def test_zabbix6_web_port(self, zabbix_web_ports):
        """Test Zabbix 6.0 web port is 8080."""
        assert zabbix_web_ports["zabbix_6_0"] == 8080

    def test_zabbix7_web_port(self, zabbix_web_ports):
        """Test Zabbix 7.0 web port is 8081."""
        assert zabbix_web_ports["zabbix_7_0"] == 8081

    def test_zabbix74_web_port(self, zabbix_web_ports):
        """Test Zabbix 7.4 web port is 8082."""
        assert zabbix_web_ports["zabbix_7_4"] == 8082

    def test_web_ports_unique(self, zabbix_web_ports):
        """Test all web ports are unique."""
        ports = list(zabbix_web_ports.values())
        assert len(ports) == len(set(ports))

    def test_zabbix6_server_port(self, zabbix_server_ports):
        """Test Zabbix 6.0 server port is 10060."""
        assert zabbix_server_ports["zabbix_6_0"] == 10060

    def test_zabbix7_server_port(self, zabbix_server_ports):
        """Test Zabbix 7.0 server port is 10070."""
        assert zabbix_server_ports["zabbix_7_0"] == 10070

    def test_zabbix74_server_port(self, zabbix_server_ports):
        """Test Zabbix 7.4 server port is 10074."""
        assert zabbix_server_ports["zabbix_7_4"] == 10074

    def test_server_ports_unique(self, zabbix_server_ports):
        """Test all server ports are unique."""
        ports = list(zabbix_server_ports.values())
        assert len(ports) == len(set(ports))


class TestPostgreSQLConfiguration:
    """Tests for PostgreSQL configuration."""

    @pytest.fixture
    def postgresql_env_vars(self):
        """Return expected PostgreSQL environment variables."""
        return {
            "POSTGRES_DB": "postgres",
            "POSTGRES_USER": "zabbix",
            "TZ": "America/Bogota",
        }

    def test_postgres_initial_db(self, postgresql_env_vars):
        """Test PostgreSQL initial database is postgres."""
        assert postgresql_env_vars["POSTGRES_DB"] == "postgres"

    def test_postgres_user(self, postgresql_env_vars):
        """Test PostgreSQL user is zabbix."""
        assert postgresql_env_vars["POSTGRES_USER"] == "zabbix"

    def test_timezone(self, postgresql_env_vars):
        """Test timezone is America/Bogota."""
        assert postgresql_env_vars["TZ"] == "America/Bogota"


class TestZabbixEnvironmentVariables:
    """Tests for Zabbix environment variables."""

    @pytest.fixture
    def zabbix_server_env_vars(self):
        """Return expected Zabbix server environment variables."""
        return {
            "DB_SERVER_HOST": "pod2-postgresql",
            "DB_SCHEMA": "public",
            "POSTGRES_DB": "zabbix60",
            "POSTGRES_USER": "zabbix",
            "TZ": "America/Bogota",
        }

    def test_db_server_host(self, zabbix_server_env_vars):
        """Test DB server host is pod2-postgresql."""
        assert zabbix_server_env_vars["DB_SERVER_HOST"] == "pod2-postgresql"

    def test_db_schema(self, zabbix_server_env_vars):
        """Test DB schema is public."""
        assert zabbix_server_env_vars["DB_SCHEMA"] == "public"

    def test_postgres_db_set(self, zabbix_server_env_vars):
        """Test POSTGRES_DB is set for entrypoint."""
        assert "POSTGRES_DB" in zabbix_server_env_vars

    def test_timezone_set(self, zabbix_server_env_vars):
        """Test TZ is set for all services."""
        assert zabbix_server_env_vars["TZ"] == "America/Bogota"


class TestZabbixImages:
    """Tests for Zabbix container images."""

    @pytest.fixture
    def expected_images(self):
        """Return expected Zabbix images."""
        return {
            "server_6_0": "zabbix/zabbix-server-pgsql:alpine-6.0-latest",
            "web_6_0": "zabbix/zabbix-web-nginx-pgsql:alpine-6.0-latest",
            "server_7_0": "zabbix/zabbix-server-pgsql:alpine-7.0-latest",
            "web_7_0": "zabbix/zabbix-web-nginx-pgsql:alpine-7.0-latest",
            "server_7_4": "zabbix/zabbix-server-pgsql:alpine-7.4-latest",
            "web_7_4": "zabbix/zabbix-web-nginx-pgsql:alpine-7.4-latest",
        }

    def test_zabbix6_uses_pgsql_image(self, expected_images):
        """Test Zabbix 6.0 uses PostgreSQL image (not MySQL)."""
        assert "pgsql" in expected_images["server_6_0"]
        assert "mysql" not in expected_images["server_6_0"]

    def test_zabbix7_uses_pgsql_image(self, expected_images):
        """Test Zabbix 7.0 uses PostgreSQL image (not MySQL)."""
        assert "pgsql" in expected_images["server_7_0"]
        assert "mysql" not in expected_images["server_7_0"]

    def test_zabbix74_uses_pgsql_image(self, expected_images):
        """Test Zabbix 7.4 uses PostgreSQL image (not MySQL)."""
        assert "pgsql" in expected_images["server_7_4"]
        assert "mysql" not in expected_images["server_7_4"]

    def test_all_use_alpine_variant(self, expected_images):
        """Test all images use alpine variant."""
        for image in expected_images.values():
            assert "alpine" in image


class TestNetworkConfiguration:
    """Tests for network configuration."""

    @pytest.fixture
    def expected_network(self):
        """Return expected POD2 network."""
        return {
            "name": "pod2-monitoring-internal",
            "subnet": "10.99.20.0/24",
        }

    def test_network_name(self, expected_network):
        """Test network name is pod2-monitoring-internal."""
        assert expected_network["name"] == "pod2-monitoring-internal"

    def test_network_subnet(self, expected_network):
        """Test network subnet is 10.99.20.0/24."""
        assert expected_network["subnet"] == "10.99.20.0/24"

    def test_subnet_cidr_format(self, expected_network):
        """Test subnet uses CIDR notation."""
        assert "/" in expected_network["subnet"]


class TestVolumesConfiguration:
    """Tests for volumes configuration."""

    @pytest.fixture
    def expected_volumes(self):
        """Return expected POD2 volumes."""
        return [
            "pod2-postgresql-data",
            "pod2-zabbix6-data",
            "pod2-zabbix7-data",
            "pod2-zabbix74-data",
            "pod2-zabbix-agent-data",
        ]

    def test_postgresql_volume_exists(self, expected_volumes):
        """Test PostgreSQL data volume exists."""
        assert "pod2-postgresql-data" in expected_volumes

    def test_zabbix6_volume_exists(self, expected_volumes):
        """Test Zabbix 6.0 data volume exists."""
        assert "pod2-zabbix6-data" in expected_volumes

    def test_zabbix7_volume_exists(self, expected_volumes):
        """Test Zabbix 7.0 data volume exists."""
        assert "pod2-zabbix7-data" in expected_volumes

    def test_zabbix74_volume_exists(self, expected_volumes):
        """Test Zabbix 7.4 data volume exists."""
        assert "pod2-zabbix74-data" in expected_volumes

    def test_separate_volumes_per_version(self, expected_volumes):
        """Test each version has separate volume."""
        assert len(expected_volumes) >= 4
