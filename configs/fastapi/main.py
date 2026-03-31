"""
FastAPI Application for Zabbix Testing Environment.

This module provides a REST API that simulates periodic queries to Zabbix
servers and logs the results in JSON format.

Author: Andrés M. Correa
Email: korc.dev@gmail.com
"""

import json
import logging
import asyncio
import os
from datetime import datetime
from pathlib import Path
from fastapi import FastAPI, HTTPException
from typing import Any, Dict

LOG_FILE = Path("/app/logs/app.log")
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()],
)

logger = logging.getLogger("fastapi-app")


def log_json(level: str, message: str, **kwargs) -> None:
    """
    Log a message in JSON format.

    Args:
        level: Log level (INFO, WARNING, ERROR, etc.)
        message: Main log message
        **kwargs: Additional fields to include in the log entry
    """
    log_entry: Dict[str, Any] = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "level": level,
        "message": message,
        **kwargs,
    }
    logger.info(json.dumps(log_entry))


app = FastAPI(title="Zabbix Testing API", version="1.0.0")


async def simulate_zabbix_query(version: str) -> Dict[str, Any]:
    """
    Simulate a query to a Zabbix server.

    Args:
        version: Zabbix version to query (e.g., "6.0", "7.0", "7.4")

    Returns:
        Dict containing endpoint, status_code, response_time_ms, version, and optionally error
    """
    import httpx

    start_time = datetime.utcnow()
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"http://nginx:80/api/{version}/status")
            elapsed_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
            return {
                "endpoint": f"/api/{version}/status",
                "status_code": response.status_code,
                "response_time_ms": elapsed_ms,
                "version": version,
            }
    except Exception as e:
        elapsed_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        return {
            "endpoint": f"/api/{version}/status",
            "status_code": 0,
            "response_time_ms": elapsed_ms,
            "version": version,
            "error": str(e),
        }


async def periodic_task():
    """
    Background task that runs every 60 seconds to query all Zabbix versions.

    This task simulates periodic health checks against Zabbix 6.0, 7.0, and 7.4,
    logging the results in JSON format.
    """
    while True:
        log_json("INFO", "Iniciando consulta periódica a Zabbix")
        for version in ["6.0", "7.0", "7.4"]:
            result = await simulate_zabbix_query(version)
            log_json("INFO", "Consulta completada", **result)
        log_json("INFO", "Esperando 60 segundos para la siguiente consulta")
        await asyncio.sleep(60)


@app.on_event("startup")
async def startup_event():
    """
    Event handler for application startup.

    Starts the periodic background task when the application starts.
    """
    log_json("INFO", "Aplicación FastAPI iniciada", port=8000)
    asyncio.create_task(periodic_task())


@app.get("/")
async def root():
    """
    Root endpoint.

    Returns:
        Basic API information
    """
    return {"message": "Zabbix Testing API", "status": "running"}


@app.get("/health")
async def health():
    """
    Health check endpoint.

    Returns:
        Health status of the API
    """
    return {"status": "healthy"}


@app.get("/api/{version}/status")
async def get_status(version: str):
    """
    Get status for a specific Zabbix version.

    Args:
        version: Zabbix version (e.g., "6.0", "7.0", "7.4")

    Returns:
        Status information for the specified Zabbix version
    """
    return {
        "version": version,
        "status": "active",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }
