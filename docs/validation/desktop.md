# Desktop prototype validation — October 10, 2026

Source snapshot: current workspace files; no Git repository is initialized. Engine: `4.7.2.stable.official.ed1daf0bf`. Windows desktop, Compatibility/OpenGL3, NVIDIA GeForce RTX 4070 Ti SUPER (driver reported 591.86). All runs explicitly use `--xr-mode off`; the project now defaults XR on, overridden by test flags. No XR interface was initialized and no headset test was run.

## Implemented

One procedural garden with a stable ground and distant canopy, 128/64 instanced ribbons, two simulated hand influences, music envelopes, three mood transitions, stillness blooms, floor/hand traces, mature curls, session reset with fade, pause/menu, mute, intensity, seated stillness, density, fullscreen, and diagnostics. Original synthesized ambient audio requires no downloaded assets.

The default desktop menu begins paused and releases the cursor. Enter or Wander in resumes and captures the mouse. The OpenXR path is now integrated through the separate manual VR launcher; Godot Play defaults to VR while desktop launch and all tests force XR off. See `xr.md` for world settings, lifecycle, and mocked integration results.

## Commands and results

The runnable script is `Validate-Desktop.ps1`; `-Render` also opens short automatically closing desktop windows with Dummy audio. It uses the supplied console executable and redirects Godot's per-user data into the ignored workspace `.runtime/` folder during checks.

| Check | Actual result |
| --- | --- |
| Headless editor import | Exit 0; all project scripts register and load. |
| Dream state fixture | 36 checks, 0 failures: bloom timing, valid tracking, seated weighting, discontinuity, reset, delta-rate equivalence, and mood cycle. |
| Audio fixture | 0 failures: 600 simulated seconds of bounded envelopes, mute independence, pause/reset, fallback, low-only stimulus, update-rate equivalence, and generated PCM peak 0.15833. |
| Muted real-backend audio fixture | WASAPI, exit 0, 0 failures: player/source/analyzer startup, exact zero gain, pause/reset/resume, idempotent shutdown and bus release. No listening test claimed. |
| Ribbon fixture | Pass: 128/64 instances, activation, invalid pose retention, release, and reset. |
| Trace fixture | 9 checks, 0 failures: deposit, discontinuity, maturation, lifetime, arrival seed, reset, pool recycling/caps over 600 simulated seconds, inactive/invalid sources. |
| Integrated headless fixture | 19 checks, 0 failures; movement/mouse/reach tests explicitly skipped because headless mouse capture is unavailable. |
| Integrated visible fixture | 22 checks, 0 failures, including injected WASD, mouse look, reach adjustment, keyboard menu/mute, reset, low density, bloom, node-count stability, and a 600-second simulated sequence. |
| XR math fixture with XR off | 0 failures: inert rig, tracking absent, continuity flags, floor/radius rejection, physically offset head teleport/snap math, and installed action-map resource names. No headset/device behavior asserted. |

The integration simulation uses 6000 updates of 0.1 seconds. It exercises three movement sources and pool replacement, verifies no node accumulation, and checks reset produces no connector stroke. This is ten minutes of **simulated experience time**, not ten minutes of human exploration or a real-time GPU benchmark.

## Actual rendered inspection

The main experience captures at 1280 × 800 after 120 fixed updates at 60 Hz, with deterministic simulated hands. Mood/bloom overrides apply only to the capture fixture; the playable experience uses ordinary 90-second dwell / 30-second transition timing.

- `garden_mood_0.png`: Silk cyan/lilac field, dark floor rings, stable horizon, readable HUD, reachable hand markers and local traces.
- `garden_mood_1.png`: Coral amber/peach palette and curls.
- `garden_mood_2.png`: Aurora teal/rose palette and taller streams.
- `garden_bloom.png`: nearby forms unfold into warm folded petals while distant strands remain narrow.
- `garden_menu.png`: centered settings panel; sliders, seated mode, density, resume, reset, and exit fit the viewport without clipping.

The first integrated capture revealed oversized nearby ribbons. Their width/height was reduced, their positions opened the center view, and their upper portions now taper into curled tips. The final integrated images show that correction. Earlier isolated `ribbon_mood_*.png` images predate this polish.

## Environment and cleanup

The sandbox emits `Failed to read the root certificate store` at startup. It does not prevent local import, rendering, or fixture execution; no network resources are required. The validation script rejects script/shader/assertion errors and nonzero exits separately.

Final full `Validate-Desktop.ps1 -Render` run exited 0 with all fixtures/captures passed and no ObjectDB leak warnings. The script now rejects leaked-object warnings as failures. The additional muted WASAPI fixture was then run separately and exited 0 with no leak warnings. A summary of the full run is in `.runtime/validation-final.log` (local ignored runtime evidence).

Initial Dummy-audio captures exposed two WAV/playback references retained at shutdown. Audio now has an idempotent shutdown API, and the root shuts down before quitting. Dummy/headless validation skips inaudible playback allocation while retaining synthetic visual envelopes. Real playback assessment is separate from screenshot validation.

## Still pending

- Human discovery review and a real ten-minute desktop exploration session.
- Listening to the ambient sound, its loop seam, and live spectrum calibration.
- GPU/CPU profiling on selected target hardware; no FPS/headroom claim is made from the screenshots.
- Real-device verification of the integrated XR startup, world settings, action bindings, tracking, stereo, recenter behavior, teleport/fade, and comfort on a named headset/runtime.
- Standalone export, export templates, packaged executable, and distribution.

High activity can replace oldest memories before their 90-second lifetime, by design of the fixed pool. Visuals are procedural prototype art, intended for a feel review before adding more environments.

VR integration follow-up: full `Validate-Desktop.ps1 -Render` passed again after integration, including new startup/lifecycle/panel/composition tests and mock captures in Compatibility and Mobile/Vulkan. Results are recorded in `.runtime/vr-integration-final.log`. The VR launcher was never executed; every test used XR off.

