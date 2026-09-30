"""Exercise bunk-option persistence with real HA lifecycle and restore storage."""

import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import yaml
from homeassistant import bootstrap, loader
from homeassistant.core import HomeAssistant


ROOT = Path(__file__).resolve().parents[1]
ENTITY_ID = "input_boolean.has_bunk_beds"


class BunkRestoreTests(unittest.IsolatedAsyncioTestCase):
    """Verify the owner's bunk choice survives a real isolated HA restart."""

    async def test_owner_choice_survives_home_assistant_restart(self):
        """Restore OFF and ON without discovering the host's Supervisor."""
        with patch.dict(os.environ):
            for key in ("SUPERVISOR", "SUPERVISOR_TOKEN", "HASSIO", "HASSIO_TOKEN"):
                os.environ.pop(key, None)
            await self.check_restart_choices()

    async def check_restart_choices(self):
        """Save each choice through normal shutdown and reload the disk state."""
        # Other domains contain unrendered model tokens; load the real helper
        # section without modifying its configuration or requiring a coach model.
        source = (ROOT / "configuration.template.yaml").read_text()
        section = re.search(r"^input_boolean:\n(?:[ \t].*\n|\n)*", source, re.MULTILINE)
        self.assertIsNotNone(section)
        configuration = yaml.safe_load(section.group())
        helper = configuration["input_boolean"]["has_bunk_beds"]
        with tempfile.TemporaryDirectory(prefix="ha-bunk-restore-") as directory:
            # Exercise both choices: an OFF-only check could pass by defaulting OFF.
            for choice in ("off", "on"):
                first = await self.start_instance(directory, helper)
                try:
                    await first.services.async_call(
                        "input_boolean", f"turn_{choice}",
                        {"entity_id": ENTITY_ID}, blocking=True,
                    )
                    self.assertEqual(first.states.get(ENTITY_ID).state, choice)
                finally:
                    await first.async_stop(force=True)

                # Assert ordinary shutdown really wrote the RestoreEntity store.
                stored = json.loads(
                    (Path(directory) / ".storage" / "core.restore_state").read_text()
                )
                saved = next(
                    item["state"] for item in stored["data"]
                    if item["state"]["entity_id"] == ENTITY_ID
                )
                self.assertEqual(saved["state"], choice)

                restarted = await self.start_instance(directory, helper)
                try:
                    self.assertEqual(
                        restarted.states.get(ENTITY_ID).state, choice,
                        f"Owner's {choice} choice was lost after HA restart",
                    )
                finally:
                    await restarted.async_stop(force=True)

    async def start_instance(self, directory, helper):
        """Bootstrap only the production helper in an isolated config directory."""
        hass = HomeAssistant(directory)
        try:
            loader.async_setup(hass)
            self.assertIs(await bootstrap.async_from_config_dict(
                {"input_boolean": {"has_bunk_beds": helper}}, hass
            ), hass)
            await hass.async_start()
            await hass.async_block_till_done()
            self.assertIsNotNone(hass.states.get(ENTITY_ID))
            return hass
        except BaseException:
            await hass.async_stop(force=True)
            raise


if __name__ == "__main__":
    unittest.main()
