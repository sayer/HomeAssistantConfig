# Offline coach regression tests

In a Python environment that already has Home Assistant installed:

```sh
python -m unittest discover -s tests -v
```

Verified with Home Assistant Core 2026.9.4. Tests create isolated temporary HA objects with fake services; they do not publish MQTT, send CAN frames, call the live HA API, or actuate devices. Script decisions come from production YAML; only waits are shortened. The configuration tests render the 2017, 2020 and 2023 model families into temporary directories.

See [the issue validation record](../docs/coach-issue-validation.md) for evidence boundaries and pending deployment/hardware gates. `test_bunk_restore.py` uses actual bootstrap, shutdown, restore-state storage and a fresh HA instance; `test_power_entities.py` uses actual MQTT ingestion/numeric-state validation. Remove `SUPERVISOR`, `SUPERVISOR_TOKEN`, `HASSIO` and `HASSIO_TOKEN` from a container test process environment so it cannot discover production Supervisor access.

For targeted frontend acceptance, use a separate HA configuration bound to localhost, the production `has_bunk_beds` helper and its exact conditional glance card, plus synthetic top/bottom cover states. Confirm OFF hides the card, ON shows both rows, and OFF remains hidden after restarting only that sandbox. Screenshots and the recorded outcome are in the validation record. No pre-existing automated browser/UI suite is configured. Do not run physical control scripts as tests.
