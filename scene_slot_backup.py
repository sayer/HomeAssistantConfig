#!/usr/bin/env python3
"""Backup retained MQTT scene slot payloads to a JSON file."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
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


def mqtt_with_paho(config: dict[str, Any], topics: dict[int, str]) -> dict[int, Optional[str]]:
    try:
        import paho.mqtt.client as mqtt  # type: ignore
    except Exception:  # noqa: BLE001
        return {}

    received: dict[str, Optional[str]] = {}
    expected = set(topics.values())

    def on_message(client, userdata, msg):  # noqa: ANN001
        if msg.topic in expected and msg.topic not in received:
            try:
                payload = msg.payload.decode("utf-8")
            except Exception:  # noqa: BLE001
                payload = msg.payload.decode("utf-8", errors="replace")
            received[msg.topic] = payload

    client = mqtt.Client()
    if config.get("username"):
        client.username_pw_set(config.get("username"), config.get("password"))
    client.on_message = on_message
    client.connect(config["host"], int(config["port"]), 10)

    for topic in expected:
        client.subscribe(topic)

    deadline = time.time() + 2.0
    while time.time() < deadline and len(received) < len(expected):
        client.loop(0.1)

    client.disconnect()

    payloads: dict[int, Optional[str]] = {}
    for slot, topic in topics.items():
        payloads[slot] = received.get(topic)
    return payloads


def mqtt_with_mosquitto(config: dict[str, Any], topics: dict[int, str]) -> dict[int, Optional[str]]:
    payloads: dict[int, Optional[str]] = {}
    for slot, topic in topics.items():
        cmd = [
            "mosquitto_sub",
            "-h",
            str(config["host"]),
            "-p",
            str(config["port"]),
            "-C",
            "1",
            "-W",
            "2",
            "-t",
            topic,
        ]
        if config.get("username"):
            cmd += ["-u", str(config["username"])]
        if config.get("password"):
            cmd += ["-P", str(config["password"])]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=False, timeout=5)
        except Exception:  # noqa: BLE001
            payloads[slot] = None
            continue

        if result.returncode == 0 and result.stdout:
            payloads[slot] = result.stdout.strip()
        else:
            payloads[slot] = None

    return payloads


def main() -> int:
    output_path = sys.argv[1] if len(sys.argv) > 1 else ""
    if not output_path:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        output_path = f"/config/scene_slot_backups/scene_slots_{timestamp}.json"

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    topics = {slot: TOPIC_TEMPLATE.format(slot=slot) for slot in SLOT_RANGE}
    config = load_mqtt_config()

    payloads = mqtt_with_paho(config, topics)
    if not payloads:
        payloads = mqtt_with_mosquitto(config, topics)

    backup: Dict[str, Any] = {
        "version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "mqtt": {
            "host": config.get("host"),
            "port": config.get("port"),
        },
        "slots": {},
    }

    for slot in SLOT_RANGE:
        payload = payloads.get(slot)
        backup["slots"][str(slot)] = {
            "topic": topics[slot],
            "payload": payload,
            "present": payload is not None,
            "bytes": len(payload.encode("utf-8")) if isinstance(payload, str) else 0,
        }

    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(backup, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"Saved scene slot backup to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
