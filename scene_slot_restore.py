#!/usr/bin/env python3
"""Restore retained MQTT scene slot payloads from a JSON file."""
from __future__ import annotations

import json
import subprocess
import sys
from typing import Any, Dict, Optional

DEFAULT_CONFIG_PATH = "/config/.storage/core.config_entries"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 1883
SLOT_RANGE = range(1, 13)
TOPIC_TEMPLATE = "homeassistant/scenes/scene_{slot}"


def load_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def normalize_entries(data: Any) -> list[dict[str, Any]]:
    if isinstance(data, dict):
        data_value = data.get("data")
        if isinstance(data_value, dict) and isinstance(data_value.get("entries"), list):
            return [entry for entry in data_value["entries"] if isinstance(entry, dict)]
        if isinstance(data_value, list):
            return [entry for entry in data_value if isinstance(entry, dict)]
        if isinstance(data.get("entries"), list):
            return [entry for entry in data["entries"] if isinstance(entry, dict)]
        return []
    if isinstance(data, list):
        return [entry for entry in data if isinstance(entry, dict)]
    return []


def load_mqtt_config() -> dict[str, Any]:
    config = {
        "host": DEFAULT_HOST,
        "port": DEFAULT_PORT,
        "username": None,
        "password": None,
    }

    try:
        raw = load_json(DEFAULT_CONFIG_PATH)
    except FileNotFoundError:
        return config
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to read MQTT config: {exc}")
        return config

    for entry in normalize_entries(raw):
        if entry.get("domain") != "mqtt":
            continue
        data = entry.get("data") or {}
        options = entry.get("options") or {}
        merged = {**data, **options}
        host = merged.get("broker") or merged.get("host") or merged.get("server") or DEFAULT_HOST
        port = merged.get("port") or DEFAULT_PORT
        config.update(
            {
                "host": host,
                "port": int(port),
                "username": merged.get("username"),
                "password": merged.get("password"),
            }
        )
        break

    return config


def publish_with_paho(config: dict[str, Any], payloads: dict[int, Optional[str]], clear_missing: bool) -> bool:
    try:
        import paho.mqtt.client as mqtt  # type: ignore
    except Exception:  # noqa: BLE001
        return False

    client = mqtt.Client()
    if config.get("username"):
        client.username_pw_set(config.get("username"), config.get("password"))
    client.connect(config["host"], int(config["port"]), 10)

    for slot, payload in payloads.items():
        topic = TOPIC_TEMPLATE.format(slot=slot)
        if payload is None and not clear_missing:
            continue
        publish_payload = payload if payload is not None else ""
        client.publish(topic, publish_payload, retain=True)

    client.disconnect()
    return True


def publish_with_mosquitto(config: dict[str, Any], payloads: dict[int, Optional[str]], clear_missing: bool) -> None:
    for slot, payload in payloads.items():
        if payload is None and not clear_missing:
            continue
        topic = TOPIC_TEMPLATE.format(slot=slot)
        publish_payload = payload if payload is not None else ""
        cmd = [
            "mosquitto_pub",
            "-h",
            str(config["host"]),
            "-p",
            str(config["port"]),
            "-t",
            topic,
            "-r",
            "-m",
            publish_payload,
        ]
        if config.get("username"):
            cmd += ["-u", str(config["username"])]
        if config.get("password"):
            cmd += ["-P", str(config["password"])]
        subprocess.run(cmd, check=False, capture_output=True, text=True)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: scene_slot_restore.py <backup_file> [clear_missing]")
        return 2

    backup_path = sys.argv[1]
    clear_missing = False
    if len(sys.argv) >= 3:
        clear_missing = sys.argv[2].lower() in {"1", "true", "yes", "on"}

    backup = load_json(backup_path)
    slots_data = backup.get("slots") if isinstance(backup, dict) else None
    if not isinstance(slots_data, dict):
        print("Backup file missing slots data")
        return 2

    payloads: Dict[int, Optional[str]] = {}
    for slot in SLOT_RANGE:
        slot_key = str(slot)
        payload: Optional[str] = None
        slot_entry = slots_data.get(slot_key)
        if isinstance(slot_entry, dict):
            payload = slot_entry.get("payload")
        payloads[slot] = payload

    config = load_mqtt_config()

    if not publish_with_paho(config, payloads, clear_missing):
        publish_with_mosquitto(config, payloads, clear_missing)

    print(f"Restored scene slots from {backup_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
