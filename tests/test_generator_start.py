"""Run the real HA script engine with fake services; no MQTT, CAN, or devices.

Run in a Home Assistant Python environment: python -m unittest discover -s tests -v
Only waits are shortened. The production YAML supplies all decisions/actions.
"""
import asyncio
import copy
from pathlib import Path
import tempfile
import unittest

import yaml
from homeassistant.core import Context, HomeAssistant
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers import script, template
from homeassistant.helpers import config_validation as cv
from homeassistant.util import dt as dt_util

ROOT = Path(__file__).resolve().parents[1]


def fast_waits(value):
    if isinstance(value, dict):
        return {
            k: {"milliseconds": 20} if k in ("delay", "timeout")
            else fast_waits(v) for k, v in value.items()
        }
    if isinstance(value, list):
        return [fast_waits(v) for v in value]
    return value


class GeneratorStartTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.hass = HomeAssistant(self.directory.name)
        template.async_setup(self.hass)
        self.calls = []
        self.commands = 0
        self.tasks = []
        self.behavior = "stopped"
        self.set_feedback("stopped")
        self.hass.states.async_set("switch.generator", "off")

        async def record(call):
            self.calls.append((call.domain + "." + call.service, dict(call.data)))
            if call.domain == "input_text":
                # The actual helper has max: 64 and ignores overlength updates.
                if len(call.data["value"]) > 64:
                    return
                self.hass.states.async_set(call.data["entity_id"], call.data["value"])

        async def turn_off(call):
            await record(call)
            self.set_feedback("stopped")
            self.hass.states.async_set("switch.generator", "off")

        async def turn_on(call):
            self.commands += 1
            if self.behavior == "service_error":
                raise HomeAssistantError("Mock transport failure")
            if self.behavior == "running":
                self.set_feedback("running")
                self.hass.states.async_set("switch.generator", "on")
            elif self.behavior == "preheat":
                self.set_feedback("preheat")
            elif self.behavior == "preheat_running":
                self.set_feedback("preheat")
                self.tasks.append(self.hass.loop.call_later(0.005, self.set_feedback, "running"))
            elif self.behavior == "fault":
                self.set_feedback("fault")
            elif self.behavior == "lost":
                self.set_feedback("unavailable")
            elif self.behavior == "stale_running":
                self.set_feedback("running", age=120)
                self.hass.states.async_set("switch.generator", "on")
            elif self.behavior == "retry_running" and self.commands == 2:
                self.set_feedback("running")
                self.hass.states.async_set("switch.generator", "on")
            else:
                self.set_feedback("stopped")

        self.hass.services.async_register("switch", "turn_on", turn_on)
        self.hass.services.async_register("switch", "turn_off", turn_off)
        self.hass.services.async_register("script", "turn_off", record)
        self.hass.services.async_register("input_text", "set_value", record)
        self.hass.services.async_register("persistent_notification", "create", record)
        self.hass.services.async_register("persistent_notification", "dismiss", record)
        self.config = yaml.safe_load((ROOT / "scripts.yaml").read_text())

    def set_feedback(self, state, age=0):
        self.hass.states.async_set("sensor.generator_start_feedback", state, {
            "timestamp": dt_util.utcnow().timestamp() - age,
        }, force_update=True)

    async def asyncTearDown(self):
        for task in self.tasks:
            task.cancel()
        await self.hass.async_stop(force=True)
        self.directory.cleanup()

    async def run_start(self, variables=None):
        sequence = fast_waits(copy.deepcopy(self.config["generator_start_with_verification"]["sequence"]))
        sequence = await script.async_validate_actions_config(self.hass, cv.SCRIPT_SCHEMA(sequence))
        runner = script.Script(self.hass, sequence, "Generator test", "script")
        self.run_error = None
        try:
            await runner.async_run(variables or {}, Context())
        except HomeAssistantError as error:
            self.run_error = error

    def assert_failure_reported(self):
        notices = [data for service, data in self.calls if service == "persistent_notification.create"]
        self.assertTrue(notices, "A failed start must produce a persistent HA error without a mobile notify service")
        status = self.hass.states.get("input_text.generator_start_status").state.lower()
        self.assertIn("failed", status)
        self.assertNotIn("generator started", status)

    async def test_transport_error_is_reported(self):
        self.behavior = "service_error"
        await self.run_start({"delay_minutes": 0})
        self.assert_failure_reported()

    async def test_no_feedback_prevents_start(self):
        self.set_feedback("unavailable")
        await self.run_start({"delay_minutes": 0})
        self.assertEqual(self.commands, 0)
        self.assert_failure_reported()

    async def test_no_arguments_uses_defaults(self):
        self.behavior = "running"
        await self.run_start()
        self.assertIsNone(self.run_error)
        self.assertEqual(self.commands, 1)
        self.assertEqual(self.hass.states.get("input_text.generator_start_status").state, "Generator started")

    async def test_preheat_does_not_reissue_start(self):
        self.behavior = "preheat"
        await self.run_start({"delay_minutes": 0})
        self.assertEqual(self.commands, 1)
        self.assert_failure_reported()

    async def test_bounded_retry_then_failure(self):
        await self.run_start({"delay_minutes": 0})
        self.assertEqual(self.commands, 4)
        self.assert_failure_reported()

    async def test_fault_stops_retrying(self):
        self.behavior = "fault"
        await self.run_start({"delay_minutes": 0})
        self.assertEqual(self.commands, 1)
        self.assert_failure_reported()

    async def test_lost_telemetry_stops_retrying(self):
        self.behavior = "lost"
        await self.run_start({"delay_minutes": 0})
        self.assertEqual(self.commands, 1)
        self.assert_failure_reported()

    async def test_stale_running_is_not_success(self):
        self.behavior = "stale_running"
        await self.run_start({"delay_minutes": 0})
        self.assert_failure_reported()

    async def test_retry_can_succeed(self):
        self.behavior = "retry_running"
        await self.run_start({"delay_minutes": 0})
        self.assertEqual(self.commands, 2)
        self.assertEqual(self.hass.states.get("input_text.generator_start_status").state, "Generator started")

    async def test_preheat_can_finish_without_retry(self):
        self.behavior = "preheat_running"
        await self.run_start()
        self.assertEqual(self.commands, 1)
        self.assertEqual(self.hass.states.get("input_text.generator_start_status").state, "Generator started")

    async def test_stale_initial_state_blocks_start(self):
        self.set_feedback("stopped", age=120)
        await self.run_start()
        self.assertEqual(self.commands, 0)
        self.assert_failure_reported()

    async def test_stop_sends_command_during_preheat_and_before_first_frame(self):
        for feedback in ("preheat", "stopped"):
            self.calls.clear()
            self.set_feedback(feedback)
            self.hass.states.async_set("switch.generator", "off")
            sequence = fast_waits(copy.deepcopy(self.config["generator_shutdown_with_verification"]["sequence"]))
            sequence = await script.async_validate_actions_config(self.hass, cv.SCRIPT_SCHEMA(sequence))
            runner = script.Script(self.hass, sequence, "Stop test", "script")
            await runner.async_run({"delay_minutes": 0}, Context())
            services = [service for service, _ in self.calls]
            self.assertLess(services.index("script.turn_off"), services.index("switch.turn_off"))
            self.assertEqual(self.hass.states.get("input_text.generator_start_status").state, "Generator off")


if __name__ == "__main__":
    unittest.main()
