#!/usr/bin/env python3
"""Aggregate Glances REST data from multiple Home Assistant hosts."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import httpx
import yaml
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from jinja2 import Environment, FileSystemLoader, select_autoescape
from rich import box
from rich.console import Console
from rich.table import Table

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "hosts.yaml"
TEMPLATES_DIR = BASE_DIR / "templates"


def load_config() -> Dict[str, Any]:
    """Load the dashboard configuration from hosts.yaml."""
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle)
    if not config or "hosts" not in config:
        raise ValueError("hosts.yaml must define a 'hosts' list.")
    return config


CONFIG = load_config()
DEFAULT_API_VERSION = int(CONFIG.get("default_api_version", 3))
REFRESH_SECONDS = int(CONFIG.get("refresh_seconds", 10))
TIMEOUT_SECONDS = float(CONFIG.get("timeout_seconds", 3))
# Prefer newer Glances API versions first, while providing sensible fallbacks.
DEFAULT_API_VERSION_CANDIDATES = tuple(
    int(v)
    for v in (
        CONFIG.get("default_api_version", DEFAULT_API_VERSION),
        4,
        3,
        2,
        1,
    )
)

ENV = Environment(
    loader=FileSystemLoader(str(TEMPLATES_DIR)),
    autoescape=select_autoescape(["html", "xml"])
)

APP = FastAPI(title="Glances Fleet Dashboard")


def build_endpoint(base_url: str, api_version: int) -> str:
    """Build the base API endpoint for a host."""
    return f"{base_url}/api/{api_version}"


def collect_api_versions(host_cfg: Dict[str, Any]) -> Iterable[int]:
    """Yield unique API versions to try for a host, honoring overrides."""
    seen = set()
    candidates: Iterable[Any]
    if "api_versions" in host_cfg and isinstance(host_cfg["api_versions"], list):
        candidates = host_cfg["api_versions"]
    else:
        preferred = host_cfg.get("api_version", DEFAULT_API_VERSION)
        candidates = (preferred, *DEFAULT_API_VERSION_CANDIDATES)

    for candidate in candidates:
        try:
            version = int(candidate)
        except (TypeError, ValueError):
            continue
        if version in seen:
            continue
        seen.add(version)
        if version <= 0:
            continue
        yield version


async def fetch_host(
    client: httpx.AsyncClient,
    host_cfg: Dict[str, Any]
) -> Tuple[str, Dict[str, Any]]:
    """Fetch the Glances /all payload for a single host."""
    name = host_cfg["name"]
    auth = None
    if host_cfg.get("username") and host_cfg.get("password"):
        auth = (host_cfg["username"], host_cfg["password"])

    base_url = host_cfg["url"].rstrip("/")
    last_error: Optional[Exception] = None
    attempted: List[str] = []

    for version in collect_api_versions(host_cfg):
        endpoint = f"{build_endpoint(base_url, version)}/all"
        attempted.append(endpoint)
        try:
            response = await client.get(endpoint, auth=auth)
            response.raise_for_status()
            payload = response.json()
            payload["__fetched_at"] = datetime.now(timezone.utc).isoformat()
            payload["__api_version"] = version
            host_cfg["_resolved_api_version"] = version  # cache for debugging
            return name, payload
        except Exception as err:
            last_error = err
            continue

    error_message = str(last_error) if last_error else "Unknown error"
    return name, {
        "__error": error_message,
        "__endpoints_attempted": attempted,
        "__fetched_at": datetime.now(timezone.utc).isoformat()
    }


async def gather_hosts() -> List[Tuple[str, Dict[str, Any]]]:
    """Fetch stats for every configured host."""
    timeout = httpx.Timeout(TIMEOUT_SECONDS)
    limits = httpx.Limits(max_keepalive_connections=5, max_connections=10)
    async with httpx.AsyncClient(timeout=timeout, limits=limits) as client:
        tasks = [fetch_host(client, host_cfg) for host_cfg in CONFIG["hosts"]]
        return await asyncio.gather(*tasks)


def format_bytes(num_bytes: Optional[float]) -> str:
    """Convert bytes to a human-readable string."""
    if num_bytes is None:
        return "-"
    thresholds = (
        (1 << 40, "TiB"),
        (1 << 30, "GiB"),
        (1 << 20, "MiB"),
        (1 << 10, "KiB"),
    )
    for threshold, suffix in thresholds:
        if num_bytes >= threshold:
            value = num_bytes / threshold
            return f"{value:.1f}{suffix}"
    return f"{num_bytes:.0f}B"


def extract_metrics(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Collect derived metrics for dashboard display."""
    if "__error" in payload:
        return {}

    def ensure_list(value: Any) -> List[Dict[str, Any]]:
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
        if isinstance(value, dict):
            return [value]
        return []

    cpu_total = payload.get("cpu", {}).get("total")
    mem_section = payload.get("mem", {}) or {}
    mem_percent = mem_section.get("percent")
    mem_used = mem_section.get("used")
    mem_total = mem_section.get("total")
    load_1m = payload.get("load", {}).get("min1")
    uptime = payload.get("uptime", "n/a")

    ip_raw = payload.get("ip")
    ip_section = ip_raw if isinstance(ip_raw, dict) else {}
    ip_address = ip_section.get("address")
    public_ip = ip_section.get("public_address") or None

    wifi_section = ensure_list(payload.get("wifi"))
    primary_wifi = wifi_section[0] if wifi_section else {}
    wifi_signal = primary_wifi.get("signal") or primary_wifi.get("quality")
    wifi_label = (
        primary_wifi.get("ssid")
        or primary_wifi.get("essid")
        or primary_wifi.get("interface")
        or None
    )

    fs_section = ensure_list(payload.get("fs"))
    disk_percent = None
    if fs_section:
        total_percent = 0.0
        counted = 0
        for fs in fs_section:
            percent = fs.get("percent")
            if isinstance(percent, (int, float)):
                total_percent += float(percent)
                counted += 1
        if counted:
            disk_percent = total_percent / counted

    return {
        "cpu_percent": cpu_total,
        "mem_percent": mem_percent,
        "mem_used": mem_used,
        "mem_total": mem_total,
        "load_1m": load_1m,
        "uptime": uptime,
        "ip_address": ip_address,
        "public_ip": public_ip,
        "wifi_signal": wifi_signal,
        "wifi_label": wifi_label,
        "disk_percent": disk_percent,
    }


def render_rich_table(
    stats: Iterable[Tuple[str, Dict[str, Any], Dict[str, Any]]]
) -> str:
    """Render a plaintext summary table using Rich."""
    console = Console(record=True, width=140)
    table = Table(title="Glances Fleet", box=box.SIMPLE)
    table.add_column("Host")
    table.add_column("CPU %", justify="right")
    table.add_column("RAM %", justify="right")
    table.add_column("Load 1m", justify="right")
    table.add_column("Uptime", justify="left")
    table.add_column("WiFi", justify="left")
    table.add_column("IP", justify="left")
    table.add_column("Disk %", justify="right")
    table.add_column("Status", justify="left")

    for host_name, payload, metrics in stats:
        if "__error" in payload:
            table.add_row(
                host_name,
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                f"ERROR: {payload['__error']}"
            )
            continue

        cpu_total = metrics.get("cpu_percent")
        mem_percent = metrics.get("mem_percent")
        load_1m = metrics.get("load_1m")
        uptime = metrics.get("uptime")
        wifi_signal = metrics.get("wifi_signal")
        wifi_label = metrics.get("wifi_label")
        ip_address = metrics.get("ip_address") or "-"
        public_ip = metrics.get("public_ip")
        disk_percent = metrics.get("disk_percent")

        wifi_display = "-"
        if wifi_signal is not None:
            wifi_display = f"{wifi_signal} dBm"
            if wifi_label:
                wifi_display = f"{wifi_display} ({wifi_label})"
        elif wifi_label:
            wifi_display = wifi_label

        ip_display = ip_address
        if public_ip:
            ip_display = f"{ip_address} / {public_ip}" if ip_address else public_ip

        table.add_row(
            host_name,
            f"{cpu_total:.1f}" if cpu_total is not None else "-",
            f"{mem_percent:.1f}" if mem_percent is not None else "-",
            f"{load_1m:.2f}" if load_1m is not None else "-",
            str(uptime),
            wifi_display,
            ip_display or "-",
            f"{disk_percent:.1f}" if disk_percent is not None else "-",
            "OK"
        )

    console.print(table)
    return console.export_text()


@APP.get("/", response_class=HTMLResponse)
async def dashboard() -> HTMLResponse:
    """Render the HTML dashboard."""
    raw_stats = await gather_hosts()
    stats = [(name, payload, extract_metrics(payload)) for name, payload in raw_stats]
    template = ENV.get_template("dashboard.html")
    now_utc = datetime.now(timezone.utc)
    html = template.render(
        stats=stats,
        updated=now_utc.isoformat(timespec="seconds"),
        refresh_seconds=REFRESH_SECONDS,
        format_bytes=format_bytes
    )
    return HTMLResponse(content=html)


@APP.get("/status", response_class=JSONResponse)
async def status() -> JSONResponse:
    """Expose the raw JSON data for other consumers."""
    raw_stats = await gather_hosts()
    return JSONResponse(content={
        "updated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "hosts": {
            name: {
                "payload": payload,
                "metrics": extract_metrics(payload),
            }
            for name, payload in raw_stats
        }
    })


@APP.get("/text", response_class=PlainTextResponse)
async def text_summary() -> PlainTextResponse:
    """Return a text summary for quick terminal checks."""
    raw_stats = await gather_hosts()
    stats = [(name, payload, extract_metrics(payload)) for name, payload in raw_stats]
    return PlainTextResponse(content=render_rich_table(stats))


@APP.get("/config", response_class=JSONResponse)
async def config_dump() -> JSONResponse:
    """Return sanitized configuration details."""
    sanitized_hosts = []
    for host_cfg in CONFIG["hosts"]:
        sanitized_hosts.append({
            "name": host_cfg["name"],
            "url": host_cfg["url"],
            "api_version": host_cfg.get("api_version", DEFAULT_API_VERSION),
        })
    return JSONResponse(content={
        "default_api_version": DEFAULT_API_VERSION,
        "refresh_seconds": REFRESH_SECONDS,
        "timeout_seconds": TIMEOUT_SECONDS,
        "hosts": sanitized_hosts
    })
