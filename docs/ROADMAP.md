# Roadmap and implementation packets

Work is ordered by gates, not calendar estimates. Each packet should fit one focused implementation session; split it if it becomes a multi-system rewrite.

## Implementation status — October 10, 2026

Current art pass: desktop is now the default. The ribbon field has become 16/10
soft 3D cloud forms; floor/rings and visible trails are removed. Desktop supports
unbounded vertical/horizontal drift, exploration HUD is hidden, and the surrounding
fluid sphere flows six times more slowly. The atmosphere follows the viewer,
distant cloud forms recycle, and approached clouds retreat and change shape/dye.
Review this sparse fluid-space feel before adding entities.
Earlier garden milestone criteria below are historical and subject to this direction.

| Tasks | Status | Evidence / remaining work |
| --- | --- | --- |
| T01 | Passed for desktop | Project import, visible desktop input, shared contract compilation. |
| T02–T03 | Implemented; technical validation passed | Instanced field, rendered palettes/bloom, influence/release fixtures; human discovery pending. |
| T04 | Passed for desktop technical scope | Pool recycling, 90s expiry, curls, resets, discontinuity checks over 600 simulated seconds. |
| T05 | Implemented; automated checks passed | Original ambient synthesis, spectrum option, envelope/mute/pause/reset/clipping and muted WASAPI startup/cleanup checks; listening/live spectrum calibration pending. |
| T06 | Passed for logic scope | 36 state checks covering timing, stillness, invalid poses, resets, and update rates. |
| T07 | Implemented; integration checks passed | 19 headless / 22 visible checks and inspected screenshots; real ten-minute human exploration pending. |
| T08–T09 | Integration implemented; hardware gates pending | Explicit startup, bundled actions, tracked rig, world settings/rays, teleport/snap, fades, focus/tracking recovery, and recenter compensation. Headset-free fixtures and Compatibility/Mobile mock renders pass; no real runtime/headset test was run. |
| T10–T11 | Not started | Hardware profiling and participant discovery review remain pending. |

T01–T07 form a playable desktop prototype; T08–T09 run by default from Godot Play, with an optional VR launcher. M2's human experience acceptance and M3/M4 headset gates remain open. See `docs/validation/desktop.md`, `docs/validation/xr.md`, and module notes. Every agent-run engine command explicitly used `--xr-mode off`, per user direction; the VR launcher was created but never executed during testing.

## Milestones

| Gate | Tasks | Demonstrable result | Exit condition |
| --- | --- | --- | --- |
| M0: Foundation | T01 | Godot project and desktop rig | Project imports and launches; shared contracts compile. |
| M1: Responsive material | T02–T03 | One ribbon field that bends | Immediate, local, reversible hand response in desktop preview. |
| M2: Dream memory | T04–T07 | Ten-minute desktop experience | Traces, bloom, moods, sound, reset, and settings work together. |
| M3: Enter the dream | T08–T09 | Headset experience | Tracking, teleport, snap turn, and discontinuity handling pass on named hardware. |
| M4: Reviewable vertical slice | T10–T11 | Tuned, documented prototype | Hardware budget and experience playtest gates pass; known limits recorded. |

Dependency graph:

```text
T01 -> T02 -> T03 -> T04
T01 -> T05
T01 -> T06
T01 + T03 + T04 + T05 + T06 -> T07
T07 -> T08 -> T09
T09 -> T10 -> T11
```

After T01, T05 and T06 can be assigned independently of visual work because their file ownership is separate. T07 is the sole integration task. The user authorized delegation on October 10; three agents built the visual/audio/state branches and the root integrated the desktop experience. Future assignments still require clear file ownership.

## T01 — Project foundation

**Depends on:** nothing. **Own:** `project.godot`, contracts, desktop input/rig, initial `main.tscn` and `main.gd`, minimal ground, startup documentation.

Create the Compatibility project with typed contract classes from TECHNICAL.md. Add a desktop camera, captured mouse look, WASD, and two simulated hand markers whose active states follow mouse buttons. Bind controls through InputMap. Expose closer/farther hand adjustment and document keys. Spawn facing a placeholder interactive area with stable floor and orientation markers.

**Accept:** editor import has no script errors; desktop starts without XR runtime; Escape releases cursor; both hand poses/activation can be inspected; movement is delta-based; the installed console executable can perform a headless import. Record the actual command and result.

**Exclude:** ribbon art, audio, plugins, XR initialization, and Git setup. Freeze concrete contract definitions before passing the task onward.

## T02 — Ribbon material spike

**Depends on:** T01. **Own:** ribbon shader, ribbon mesh generation, `ribbon_field.gd`, optional isolated visual test scene.

Build a 128-instance field using a reusable segmented strip and bounded shader motion. Demonstrate the three palette/shape presets using explicit debug parameters. Keep geometry visible from plausible viewing directions and against the floor. Test opaque or cutout rendering before transparent blending.

**Accept:** screenshots or a short recorded observation show depth and each mood; no shader errors in Compatibility; instance count remains fixed; mesh/deformation bounds prevent visible culling pops; no camera transforms are modified. Report renderer limitations before adopting another renderer.

**Exclude:** real input coupling, mood scheduling, bloom postprocessing requirements, and physics ropes.

## T03 — Hand influence

**Depends on:** T02. **Own:** ribbon input plumbing and shader influence parameters. Do not change the shared contracts or desktop rig.

Consume `VisitorFrame` to apply two independent bounded influence fields. Smooth release, preserve a visible music-independent response, and handle invalid or inactive hands. Expose radius, bend cap, and release time as tuning properties.

**Accept:** each simulated hand visibly affects only nearby ribbons; displacement stays within the configured cap; withdrawing restores the field; invalid tracking removes influence without snapping to the origin. Integration hook is the agreed `apply_frame` method.

**Exclude:** gesture recognition, trails, and XR controller scripts.

## T04 — Bounded living memory

**Depends on:** T03. **Own:** `trace_field.gd`, trace shader/mesh, focused trace fixtures.

Implement floor travel traces and hand gesture traces using preallocated pools. Add aging, a limited subset of matured curls, expiration, oldest-entry replacement, reset, and arrival seeds. Use synthetic VisitorFrames in an isolated test scene until T07 integrates it.

**Accept:** a 20–40-second-old trace is recognizable; all expire by 90 seconds; ten-minute synthetic motion respects both pool caps; teleport/recenter discontinuities do not create connector strokes; reset clears pools and sample history; inactive/invalid hands deposit nothing. Record counters in a debug-only view.

**Exclude:** files saved across sessions, complex flowers, and modifying navigation.

## T05 — Audio envelopes

**Depends on:** T01. **Own:** audio driver, audio bus resource, permitted audio assets/license notes, audio fixtures.

Implement normalized low/mid/high/level output with smoothing. Include a deterministic synthetic mode. Add an approved ambient loop only if available; otherwise produce a simple synthesized placeholder. Volume belongs to settings, not visual intensity.

**Accept:** silence/missing data is handled; outputs stay within 0–1; a synthetic low-band stimulus changes low more than high; volume zero mutes output while the selected silent visual envelope continues; no clipping in the placeholder. Document which behaviors were actually heard versus checked headlessly.

**Exclude:** visuals, streaming, microphone capture, and music import UI.

## T06 — Stillness and mood state

**Depends on:** T01. **Own:** motion sampler, dream director, mood resources, focused state fixtures.

Implement smoothed valid-pose motion, seated weighting, bloom buildup/decay, and Silk → Coral → Aurora dwell/blend timing. Treat discontinuity as sample reset, not a burst of speed. Reset returns to Silk with zero bloom.

**Accept:** synthetic natural small motion can bloom; renewed motion decays it; invalid hand poses are ignored; discontinuity prevents speed spikes and clears the stillness buildup; differing update rates produce equivalent timing within a small documented tolerance; moods advance after 90 seconds and blend for 30 seconds.

**Exclude:** rendering, audio reads, UI, and camera changes.

## T07 — Desktop integration and settings

**Depends on:** T03, T04, T05, T06. **Own:** `main.gd`, `main.tscn`, settings scene/script, settings resources. May make narrowly documented integration fixes in dependencies.

Wire the update order from TECHNICAL.md. Apply audio bands, mood blending, and stillness to the ribbon field. Make blooms a clear extension of the existing ribbon material. Add the compact settings surface, pause behavior, reset/fade, exit, and a debug-only overlay of frame time, pools, mood, and stillness.

**Accept:** a ten-minute desktop session demonstrates all interactions and a mood transition; silent mode remains responsive; Escape opens settings without dragging the camera; intensity scales ambient and interactive visual amplitude within caps; reset produces no old/new connecting trace. Record the manual check in `docs/validation/desktop.md`.

**Exclude:** additional biomes and unreviewed contract rewrites. This is the first complete desktop vertical slice, not XR completion.

## T08 — OpenXR rig and tracking

**Depends on:** T07. **Own:** XR rig/input, OpenXR action map, explicit startup mode selection and necessary project settings. Coordinate `main` edits with the integrator.

First identify the intended headset, active Windows OpenXR runtime, and controller bindings. Add centralized XR startup and a tracked origin/camera/controller rig. Feed the existing VisitorFrame contract. Add a readable desktop fallback if initialization fails. Handle tracking loss, pause/resume, and recenter by resetting motion samples.

**Accept:** named headset/runtime receives correct stereo head tracking and both controllers; simulated input is absent in XR mode; hand influence and seated bloom work; startup failure returns to desktop clearly; tracking recovery produces no long trace. Record hardware and bindings in `docs/validation/xr.md`.

**Blocked portion:** hardware tracking validation cannot pass without access to a working headset/runtime. Build and headless import can proceed; leave the hardware gate explicitly pending.

**Exclude:** Android/vendor export tooling and hand tracking.

## T09 — VR traversal

**Depends on:** T08. **Own:** XR navigation script and target marker scene; integrate signals into `main` through a small coordinated change.

Implement teleport aiming, valid floor destinations, edge rejection, fade, 30-degree snap turn, and seated interaction access. Emit arrival seed/discontinuity signals as specified. Continuous locomotion is optional and only follows passing teleport behavior.

**Accept:** valid teleport lands on floor within bounds; invalid destinations cannot be committed; snap turn pivots around the current tracked head floor projection; no camera roll/bob; arrival creates one seed without a connecting stroke; recenter changes tracking reference without clearing the dream or adding a seed. Verify with physical head offset from the rig origin.

**Exclude:** automatic travel, fly mode, procedural level generation, and moving the tracked camera directly.

## T10 — Performance and visual tuning

**Depends on:** T09. **Own:** tuning resources, profiler evidence, targeted optimization fixes with file ownership coordination.

Profile default and low tiers on the target hardware. Reduce overdraw, excessive subdivision, instance counts, or expensive shader work based on evidence. Tune brightness and movement while preserving legible hand response and stable landmarks.

**Accept:** representative ten-minute headset run meets the selected refresh-rate target and headroom, or records the specific failing measurements and leaves M4 open; memory remains bounded; no obvious culling pops, accumulating nodes, or uncontrolled flashes. Add `docs/validation/performance.md` with settings and measurements.

**Exclude:** speculative rewrites, quality-tier proliferation, and claiming desktop measurements as headset results.

## T11 — Experience review and handoff

**Depends on:** T10. **Own:** playtest notes, updated README, known limits, final tuning changes coordinated with relevant owners.

Run the DESIGN.md discovery playtest, ideally with three participants. Record what was discovered, time to discovery, retention of interest, and comfort feedback. Address the largest interaction clarity problem before expanding scope. Document launch controls and the exact supported device/runtime configuration.

**Accept:** at least two of three discover bend, recognize memory, and notice bloom; hardware gate passes; settings/reset/exit remain accessible; all claimed checks have evidence. If participants or hardware are unavailable, label those checks pending and deliver an explicitly unvalidated build rather than marking the milestone complete.

**Exclude:** new mechanics and publishing/distribution work. A vertical slice is ready for review; it is not automatically a standalone headset release.

## Change policy

If a packet cannot meet its goal inside its owned module, report the specific dependency or interface problem. The integrator updates the contracts and affected packets together. Keep task status and validation evidence current. Adding more effects cannot substitute for passing the three-interaction gate.

