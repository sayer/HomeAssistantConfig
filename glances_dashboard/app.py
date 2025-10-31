#!/usr/bin/env python3
"""Aggregate Glances REST data from multiple Home Assistant hosts."""


from __future__ import annotations

import asyncio
import json
import re
import shlex
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlparse, urlunparse

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

HOST_METADATA: Dict[str, Dict[str, Any]] = {}


def derive_ha_dashboard_url(host_cfg: Dict[str, Any]) -> Optional[str]:
    """Compute the Home Assistant dashboard URL for a host."""
    if "ha_url" in host_cfg:
        return host_cfg["ha_url"]

    base_url = host_cfg.get("url")
    if not base_url:
        return None

    parsed = urlparse(base_url)
    hostname = parsed.hostname
    if not hostname:
        return None

    try:
        port = int(host_cfg.get("ha_port", 8123))
    except (TypeError, ValueError):
        port = 8123

    scheme = parsed.scheme or "http"
    netloc = f"{hostname}:{port}"
    path = "/dashboard-remote/0"
    return urlunparse((scheme, netloc, path, "", "", ""))


def derive_glances_url(host_cfg: Dict[str, Any]) -> Optional[str]:
    """Compute the Glances web UI URL for a host."""
    base_url = host_cfg.get("url")
    if not base_url:
        return None
    parsed = urlparse(base_url)
    hostname = parsed.hostname
    if not hostname:
        return None
    try:
        port = int(host_cfg.get("glances_port", parsed.port or 61209))
    except (TypeError, ValueError):
        port = parsed.port or 61209
    scheme = parsed.scheme or "http"
    netloc = f"{hostname}:{port}"
    return urlunparse((scheme, netloc, "/", "", "", ""))


def load_config() -> Dict[str, Any]:
    """Load the dashboard configuration from hosts.yaml."""
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle)
    if not config or "hosts" not in config:
        raise ValueError("hosts.yaml must define a 'hosts' list.")
    HOST_METADATA.clear()
    for host_cfg in config["hosts"]:
        metadata: Dict[str, Any] = {}
        ha_url = derive_ha_dashboard_url(host_cfg)
        if ha_url:
            metadata["ha_dashboard_url"] = ha_url
        glances_url = derive_glances_url(host_cfg)
        if glances_url:
            metadata["glances_url"] = glances_url
        host_cfg["__meta"] = metadata
        HOST_METADATA[host_cfg["name"]] = metadata
    return config


CONFIG = load_config()
DEFAULT_API_VERSION = int(CONFIG.get("default_api_version", 3))
REFRESH_SECONDS = int(CONFIG.get("refresh_seconds", 10))
TIMEOUT_SECONDS = float(CONFIG.get("timeout_seconds", 3))
COACH_STATS_CONFIG: Dict[str, Any] = CONFIG.get("coach_stats", {}) or {}
COACH_STATS_DEFAULT_TIMEOUT = float(COACH_STATS_CONFIG.get("timeout_seconds", 5))
COACH_STATS_ENABLED = bool(COACH_STATS_CONFIG.get("enabled", bool(COACH_STATS_CONFIG)))

ENV = Environment(
    loader=FileSystemLoader(str(TEMPLATES_DIR)),
    autoescape=select_autoescape(["html", "xml"])
)

APP = FastAPI(title="Glances Fleet Dashboard")


def build_endpoint(host_cfg: Dict[str, Any]) -> str:
    """Build the base API endpoint for a host."""
    base_url = host_cfg["url"].rstrip("/")
    api_version = host_cfg.get("api_version", DEFAULT_API_VERSION)
    return f"{base_url}/api/{api_version}"


def _coach_stats_allowed(host_cfg: Dict[str, Any]) -> bool:
    if not COACH_STATS_ENABLED:
        return False
    override = host_cfg.get("coach_stats")
    if isinstance(override, dict) and override.get("enabled") is False:
        return False
    return True


def _merge_coach_stats_config(host_cfg: Dict[str, Any]) -> Dict[str, Any]:
    cfg: Dict[str, Any] = {}
    if isinstance(COACH_STATS_CONFIG, dict):
        cfg.update(COACH_STATS_CONFIG)
    override = host_cfg.get("coach_stats")
    if isinstance(override, dict):
        cfg.update(override)
    return cfg


async def fetch_coach_stats(host_cfg: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Fetch supplemental coach stats (owner, coach info) via SSH."""
    if not _coach_stats_allowed(host_cfg):
        return None

    stats_cfg = _merge_coach_stats_config(host_cfg)
    if stats_cfg.get("enabled") is False:
        return None

    command = stats_cfg.get("command") or stats_cfg.get("remote_command")
    if not command:
        return None

    parsed = urlparse(host_cfg.get("url", ""))
    remote_host = stats_cfg.get("host") or parsed.hostname or host_cfg.get("name")
    if not remote_host:
        return None

    ssh_user = stats_cfg.get("ssh_user", "hassio")
    ssh_port = int(stats_cfg.get("ssh_port", 2222))
    timeout_seconds = float(stats_cfg.get("timeout_seconds", COACH_STATS_DEFAULT_TIMEOUT))
    connect_timeout = int(stats_cfg.get("connect_timeout", max(3, int(timeout_seconds))))
    extra_options = stats_cfg.get("ssh_options")
    if isinstance(extra_options, str):
        extra_options = [extra_options]
    extra_options = extra_options or []

    remote_shell = stats_cfg.get("shell", "bash -l -c")
    if remote_shell:
        remote_command = f"{remote_shell} {shlex.quote(command)}"
    else:
        remote_command = command

    ssh_cmd = [
        "ssh",
        "-p",
        str(ssh_port),
        "-o",
        f"ConnectTimeout={connect_timeout}",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=no",
    ]
    ssh_cmd.extend(extra_options)
    ssh_cmd.append(f"{ssh_user}@{remote_host}")
    ssh_cmd.append(remote_command)

    try:
        process = await asyncio.create_subprocess_exec(
            *ssh_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError as err:
        return {"__error": f"ssh not available: {err}"}
    except Exception as err:  # pragma: no cover - defensive guard
        return {"__error": f"unable to spawn ssh: {err}"}

    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout_seconds)
    except asyncio.TimeoutError:
        process.kill()
        return {"__error": f"timeout after {timeout_seconds:.1f}s"}

    raw_stdout = stdout.decode().strip()
    raw_stderr = stderr.decode().strip()
    if process.returncode != 0 and not raw_stdout:
        return {
            "__error": f"exit {process.returncode}",
            "__stderr": raw_stderr or None,
        }

    # Attempt to parse JSON from stdout; fall back to scanning line-by-line.
    def _parse_output(payload: str) -> Optional[Dict[str, Any]]:
        candidate = payload.strip()
        if not candidate:
            return None
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            return None

    parsed_json = _parse_output(raw_stdout)
    if parsed_json is None:
        for line in reversed(raw_stdout.splitlines()):
            parsed_json = _parse_output(line)
            if parsed_json is not None:
                break

    if parsed_json is None:
        return {
            "__error": "invalid JSON",
            "__stdout": raw_stdout or None,
            "__stderr": raw_stderr or None,
        }

    return parsed_json


async def fetch_host(
    client: httpx.AsyncClient,
    host_cfg: Dict[str, Any]
) -> Tuple[str, Dict[str, Any]]:
    """Fetch the Glances /all payload for a single host."""
    name = host_cfg["name"]
    auth = None
    if host_cfg.get("username") and host_cfg.get("password"):
        auth = (host_cfg["username"], host_cfg["password"])

    endpoint = f"{build_endpoint(host_cfg)}/all"
    stats_task: Optional[asyncio.Task] = None
    if _coach_stats_allowed(host_cfg):
        stats_task = asyncio.create_task(fetch_coach_stats(host_cfg))
    try:
        response = await client.get(endpoint, auth=auth)
        response.raise_for_status()
        payload = response.json()
        payload["__fetched_at"] = current_timestamp()
    except Exception as err:
        error_message = f"{type(err).__name__}: {err}"
        stats_payload = await stats_task if stats_task else None
        error_response = {
            "__error": error_message,
            "__endpoint": endpoint,
            "__fetched_at": current_timestamp()
        }
        if isinstance(stats_payload, dict):
            error_response["__coach_stats"] = stats_payload
        return name, error_response

    stats_payload = await stats_task if stats_task else None
    if isinstance(stats_payload, dict):
        payload["__coach_stats"] = stats_payload
    return name, payload


async def gather_hosts() -> List[Tuple[str, Dict[str, Any]]]:
    """Fetch stats for every configured host."""
    host_count = len(CONFIG["hosts"])
    timeout = httpx.Timeout(
        connect=TIMEOUT_SECONDS,
        read=TIMEOUT_SECONDS,
        write=TIMEOUT_SECONDS,
        pool=TIMEOUT_SECONDS
    )
    limits = httpx.Limits(
        max_keepalive_connections=max(10, host_count),
        max_connections=max(10, host_count)
    )
    async with httpx.AsyncClient(timeout=timeout, limits=limits) as client:
        tasks = [fetch_host(client, host_cfg) for host_cfg in CONFIG["hosts"]]
        return await asyncio.gather(*tasks)


def local_tz():
    """Return the local timezone object."""
    return datetime.now().astimezone().tzinfo


def current_timestamp() -> str:
    """Return the current time formatted in the local timezone."""
    return datetime.now(local_tz()).strftime("%Y-%m-%d %H:%M:%S %Z")


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
    coach_stats = payload.get("__coach_stats") if isinstance(payload, dict) else None
    coach_owner = None
    coach_number = None
    coach_year = None
    if isinstance(coach_stats, dict):
        coach_section = coach_stats.get("coach")
        if isinstance(coach_section, dict):
            coach_owner = coach_section.get("owner") or None
            coach_number = coach_section.get("number")
            coach_year = coach_section.get("year")

    if "__error" in payload:
        return {
            "coach_owner": coach_owner,
            "coach_number": coach_number,
            "coach_year": coach_year,
        }

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
        "coach_owner": coach_owner,
        "coach_number": coach_number,
        "coach_year": coach_year,
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
            owner = metrics.get("coach_owner") if isinstance(metrics, dict) else None
            host_display = f"{host_name} ({owner})" if owner else host_name
            table.add_row(
                host_display,
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
        coach_owner = metrics.get("coach_owner")

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

        host_display = f"{host_name} ({coach_owner})" if coach_owner else host_name

        table.add_row(
            host_display,
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
    stats = sorted(
        stats,
        key=lambda item: (
            1 if "__error" in item[1] else 0,
            _host_number(item[0]),
            item[0].lower(),
        ),
    )
    template = ENV.get_template("dashboard.html")
    now_local = datetime.now(local_tz())
    html = template.render(
        stats=stats,
        updated=now_local.strftime("%Y-%m-%d %H:%M:%S %Z"),
        refresh_seconds=REFRESH_SECONDS,
        format_bytes=format_bytes,
        host_meta=HOST_METADATA
    )
    return HTMLResponse(content=html)


@APP.get("/status", response_class=JSONResponse)
async def status() -> JSONResponse:
    """Expose the raw JSON data for other consumers."""
    raw_stats = await gather_hosts()
    return JSONResponse(content={
        "updated": datetime.now(local_tz()).strftime("%Y-%m-%d %H:%M:%S %Z"),
        "hosts": {
            name: {
                "payload": payload,
                "metrics": extract_metrics(payload),
            }
            for name, payload in raw_stats
        }
    })


def _host_number(host_name: str) -> int:
    """Extract a numeric suffix from host name for sorting, defaults high."""
    match = re.search(r"(\d+)", host_name)
    if match:
        try:
            return int(match.group(1))
        except ValueError:
            return 9999
    return 9999


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
            "ha_dashboard_url": HOST_METADATA.get(host_cfg["name"], {}).get("ha_dashboard_url"),
        })
    return JSONResponse(content={
        "default_api_version": DEFAULT_API_VERSION,
        "refresh_seconds": REFRESH_SECONDS,
        "timeout_seconds": TIMEOUT_SECONDS,
        "hosts": sanitized_hosts
    })
