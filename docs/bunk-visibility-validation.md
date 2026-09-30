# Bunk visibility acceptance (#51)

The existing dashboard conditional from PR #60 hides Top/Bottom Bunk Night Shades whenever `input_boolean.has_bunk_beds` is OFF. Removing `initial: true` prevents that saved choice from being reset to ON after restart. Historical entity spelling is preserved.

Verified on September 30, 2026, with actual Home Assistant Core 2026.9.4:

- Real input_boolean lifecycle test fails against main (`off` restarts as `on`). With this change it passes both OFF and ON restoration, using shutdown, persisted `core.restore_state`, and a fresh HA instance.
- Actual HA frontend, using the exact production helper/conditional card and synthetic top/bottom shade states: OFF hides both rows; ON displays both rows; OFF → isolated HA process restart → OFF keeps both rows hidden. Both synthetic shade entities were present after restart, verified separately.
- [Visible with bunks enabled](evidence/bunks-on.jpg); [hidden after restart without bunks](evidence/bunks-off-after-restart.jpg).

The frontend ran in a separate temporary configuration on a localhost-only port with Supervisor credentials removed. No real shade commands were sent. This issue concerns conditional visibility, so physical movement on the original unidentified coach is not an acceptance prerequisite.

Run the regression in Home Assistant's Python environment:

```sh
python -m unittest discover -s tests -p test_bunk_restore.py -v
```

The test clears Supervisor/HASSIO environment variables for its lifecycle and restores the caller environment afterward. Broader generator, lighting, power and thermostat work remains in PR #181 and separate issues.
