# Coach issue verification — 2026-09-30

This review covers open issues #1–8, #36 and #49–51. Code fixes have offline and targeted frontend evidence; physical acceptance remains pending where the issue requires it. No generator, shades, lighting, or thermostats were actuated, and neither repository was deployed.

## Disposition

| Issue | Verified finding and change | Remaining acceptance |
| --- | --- | --- |
| #1 | Bridge commands were published as confirmed light telemetry. Bridge PR [rvc2mqtt#2](https://github.com/sayer/rvc2mqtt/pull/2) removes this and rejects unsupported driver status values rather than fabricating OFF. | Panel-to-HA synchronization, startup freshness, latency and source/circuit mapping on the affected coach. Retention alone cannot establish freshness. |
| #2 | Requested front/cockpit, mid/bath, bedroom/rear groups are not defined in tracked YAML. Existing helper references do not establish membership. | Coach year/floor plan and actual circuit membership; inspect existing UI helpers before creating duplicate groups or presets. |
| #3 | Kitchen covers have mappings for 2023+ but lacked individual dashboard controls. Added controls that remain visible when idle/unknown. | Identify affected model and verify RV-C instances; earlier models have no kitchen mapping. A missing UI control does not explain every unresponsive motor. |
| #4 | Motor duty and last direction were treated as position/endpoints; group templates fabricated 50%. Removed these assumptions. | Physical movement and latency. Idle covers/groups now honestly show unknown position because these frames do not measure travel. |
| #5 | False closed/open endpoints can disable a same-direction button after Stop. The #4 correction removes this cause. | Supervised open–stop–open and close–stop–close with bus traces. Bridge toggle command codes remain unchanged pending evidence. |
| #6 | Startup omitted runtime defaults, accepted stale/coarse switch state, repeated starts during preheat, and could fail without a persistent error. Added fresh RV-C feedback, bounded attempts and persistent errors. Stop cancels pending starts and sends an explicit stop even before the first startup frame. | Multiple supervised starts/stops and failure traces on the affected generator/controller. Passive history showed running transitions on a representative host, but cannot attribute them to HA or resolve the original report. |
| #7 | Closed as historically resolved by the owner: merged PRs #23/#29/#32/#34, explicit “Resolved” in the body, and owner resolution on 2025-10-18. Eight current source-template scenarios passed. New missing-data correction maps all four numeric sensors to HA `None`, verified through actual MQTT entity ingestion. | No new independent SilverLeaf comparison is claimed. Outback-specific investigation remains #49. |
| #8 | Runtime mixed timezone-aware and naive dates and startup fabricated five minutes. Use timestamps, preserve known starts on reconnect, exclude the unset sentinel, and show unavailable when start time is unknown. Generator action service used unsupported dashboard templating; Start/Stop now use static services. | Multi-minute UI stability and runtime comparison with SilverLeaf, including restart/reconnection. |
| #36 | Integer Celsius conversion collapsed adjacent Fahrenheit settings. Preserve three decimal places. Earlier ambient-probe mapping fixes remain in place. | Verify +/- and slider against actual zone setpoints and interior probes. |
| #49 | Existing Outback-first normalization and fallback logic found; no affected-coach raw payload was supplied. | Read-only Outback REST payload plus mode and panel comparison before changing mappings. Runtime defect remains unverified. |
| #50 | False dresser 0/50/100% positions share #4's confirmed defect and correction. | Dresser Day availability requires affected coach, registry and bus trace; no speculative address change. |
| #51 | `initial: true` reset the bunk choice on every restart. Removed it. Real HA lifecycle test fails before the fix and passes afterward for both OFF and ON. Actual frontend: OFF hides both controls, ON shows both, OFF survives sandbox restart and remains hidden. | Acceptance met in the isolated HA/frontend; closure follows merge. This visibility issue does not require physical shade movement. |

Issue #7 is closed on historical owner resolution plus retained implementation, not its title alone. Issue #51 has concrete sandbox acceptance. Other issues remain open for the specific evidence listed above.

## Generator behavior

`GENERATOR_COMMAND` (DGN 1FFDA) contains a command byte: 0 stop, 1 start. The controller owns crank/preheat timing; there is no start-button hold field. The actual bridge encoder was exercised with mocked CAN and produced `19FFDAA0#01FFFFFFFFFFFFFF` for start and `19FFDAA0#00FFFFFFFFFFFFFF` for stop.

The separate `sensor.generator_start_feedback` reads raw status and frame timestamp, expires after 30 seconds and leaves existing entity IDs intact. Start requires feedback no older than 30 seconds (up to five seconds of forward clock skew); success requires running feedback at or after the request. At most four start requests occur, with 60 seconds for each attempt. Retry requires a fresh post-request stopped frame. Preheat, cranking, priming, faults, unknown and stale feedback never trigger another start in that run. A 60-second timeout can report a failure while the controller is still working; check the generator before manually retrying.

Stop first cancels the pending HA start script, always sends Stop, then verifies fresh stopped feedback with at most three further stop requests. Mobile notifications are optional for Start; a persistent notification is the reliable error surface. Load the new MQTT sensor along with the scripts and dashboard before acceptance; reloading only scripts intentionally leaves Start blocked without fresh feedback.

## Automated verification

Run the complete offline suite with Home Assistant's Python environment (verified with Core 2026.9.4):

```sh
python -m unittest discover -s tests -v
```

Result: 24 tests passed, no failures/skips. The suite uses a separate temporary `HomeAssistant` object, real HA templates and script engine, fake services, and shortened waits. It renders every configuration family (2017, 2020, 2023). It covers bounded retries, faults, transport failure, stale/missing telemetry, preheat completion, Stop before running, Fahrenheit precision, runtime timestamps/sentinel, missing power, shade payloads, bunk persistence configuration and dashboard action bindings. The injected transport failure intentionally logs an error while its reporting assertion passes. Additional lifecycle tests prove both bunk choices restore from disk, and actual MQTT numeric entity ingestion proves missing data clears a prior reading without treating real zero as missing. These are offline behavior/configuration tests, separate from the frontend checks below.

The bridge's complete offline suite passed five tests with actual Perl entrypoints/codecs and mocked MQTT/CAN. Both changed Perl scripts passed syntax checks. No pre-existing automated browser suite exists. Targeted actual HA frontend testing now verifies the bunk conditional against the production card/helper, with synthetic cover states and no actuator integrations. Full coach hardware/UI acceptance remains pending for the other issues. Screenshots: [bunks visible](evidence/bunks-on.jpg), [bunks hidden after restart](evidence/bunks-off-after-restart.jpg).

Full isolated HA `check_config --fail-on-warnings` now **passes on Core 2026.9.4** for the generated 2023 candidate. The earlier missing-dependency result was an incomplete test setup: both blueprints are tracked in this repository, and the climate-group component/device registry were available on the existing host. Dependencies were copied into a temporary directory for validation; no production configuration was replaced or restarted.

The same candidate/dependencies on coach host `homeassistant-13` (model year 2023, coach 9180, Core 2026.4.1) hit the existing Core validator defect `KeyError: 'triggers'`, already recognized by the repository's update script. That version-specific result is not recorded as a pass. The original September 2025 feedback contains no coach number/model, so coach 9180 is a known validation environment, not a verified match for those reports. Driver Day's inoperative motor was explicitly noted in that original feedback and must not be mistaken for a software failure.

The frontend sandbox ran in its own temporary configuration and localhost-only port, with Supervisor credentials removed from its process environment. It used the exact production bunk conditional/helper and synthetic shade states. OFF → ON → OFF → process restart → OFF passed, including readback that both synthetic shade entities existed while hidden. No real shade command was sent.

## Supervised acceptance

Identify the affected coach/host, model year, floor plan and generator controller before deployment. On that host, preserve its configuration/registry, render its actual model year, resolve every configuration-check warning, and confirm the new feedback entity receives current frames. With an operator present and safe conditions, compare UI actions and confirmed bus feedback to the physical panel for each issue above. Capture the running commit, timestamps, traces and screenshots; record unavailable tests as pending rather than passing. Do not run live actuator scripts as a substitute for the offline suite.
