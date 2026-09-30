"""Exercise numeric MQTT entity ingestion without a broker or live services."""
import json
from pathlib import Path
import re
import tempfile
import unittest

import yaml
from homeassistant.core import HomeAssistant
from homeassistant.components.mqtt.models import ReceiveMessage
from homeassistant.components.mqtt.sensor import MqttSensor, PLATFORM_SCHEMA_MODERN
from homeassistant.helpers import template

ROOT = Path(__file__).resolve().parents[1]


class PowerEntityTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.hass = HomeAssistant(self.directory.name)
        template.async_setup(self.hass)
        source = (ROOT / "configuration.template.yaml").read_text()
        self.configs = [
            yaml.safe_load(block)[0]
            for block in re.findall(
                r'^    - name: "AC Line [12] (?:Voltage|Current)"\n.*?(?=^    - name:)',
                source, re.MULTILINE | re.DOTALL,
            )
        ]
        self.assertEqual(len(self.configs), 4)

    async def asyncTearDown(self):
        await self.hass.async_stop(force=True)
        self.directory.cleanup()

    def sensor(self, config):
        # Avoid registry/subscriptions; retain the real entity's payload and
        # numeric-state validation, which template-only tests do not exercise.
        sensor = MqttSensor.__new__(MqttSensor)
        sensor.hass = self.hass
        sensor.entity_id = "sensor." + config["unique_id"]
        sensor._setup_from_config(PLATFORM_SCHEMA_MODERN(config))
        return sensor

    def ingest(self, sensor, config, payload):
        sensor._update_state(ReceiveMessage(
            topic=config["state_topic"], payload=json.dumps(payload), qos=0,
            retain=False, subscribed_topic=config["state_topic"], timestamp=0,
        ))
        return sensor.state

    def test_missing_payload_clears_previous_numeric_state(self):
        for config in self.configs:
            for missing in ({}, {"rms voltage": None, "rms current": None},
                            {"rms voltage": "n/a", "rms current": "n/a"},
                            {"rms voltage": "unknown", "rms current": "unknown"},
                            {"rms voltage": "unavailable", "rms current": "unavailable"}):
                with self.subTest(sensor=config["name"], payload=missing):
                    sensor = self.sensor(config)
                    self.assertEqual(float(self.ingest(sensor, config, {
                        "rms voltage": 120, "rms current": 12,
                    })), 120 if "Voltage" in config["name"] else 12)
                    self.assertIsNone(self.ingest(sensor, config, missing))
                    self.assertEqual(float(self.ingest(sensor, config, {
                        "rms voltage": 0, "rms current": 0,
                    })), 0)


if __name__ == "__main__":
    unittest.main()
