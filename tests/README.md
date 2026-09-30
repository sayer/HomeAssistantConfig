# Offline coach regression tests

In a Python environment that already has Home Assistant installed:

```sh
python -m unittest discover -s tests -v
```

Verified with Home Assistant Core 2026.9.4. Tests create isolated temporary HA objects with fake services; they do not publish MQTT, send CAN frames, call the live HA API, or actuate devices. Script decisions come from production YAML; only waits are shortened. The configuration tests render the 2017, 2020 and 2023 model families into temporary directories.

See [the issue validation record](../docs/coach-issue-validation.md) for evidence boundaries and pending deployment/hardware gates. There is no configured browser/UI test suite. Do not run physical control scripts as tests.
