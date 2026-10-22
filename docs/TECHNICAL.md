# Godot implementation contracts

These contracts are a planning baseline. T01 creates their actual typed definitions; later agents consume those definitions. Any contract change needs a documented integration decision and updated dependent tasks.

Implementation update: T01–T09 modules now exist. The tree is composed programmatically in `main.gd` rather than separate rig/settings `.tscn` files; `scenes/main.tscn` remains the entry point. `GardenStage` owns the environment and `DreamUI` owns the CanvasLayer settings/HUD. In VR, `XRPanel` reparents the same UI into a textured SubViewport and routes controller rays as mouse input. Contract fields use explicit `left_hand_transform` / `right_hand_transform` and corresponding `left_hand_*` / `right_hand_*` flags. `DreamFrame.Mood` and `DreamSettings.Locomotion/Quality` define enums. Audio adds `shutdown()` for cleanup. Desktop is the default for Godot Play; desktop launch and all validation explicitly disable XR per user instruction.

`XRStartup` follows the project XR setting, now disabled by default for Godot Play; the explicit VR launcher pairs engine `--xr-mode on` with user `--vr`. Headless/editor/capture/smoke/`--desktop` requests are rejected before runtime lookup. Every test must force engine XR off via `--xr-mode off` and pass the retained user flag `--desktop`; Godot consumes the engine mode flag before exposing command arguments to scripts. OpenXR initializes at engine startup, and the composition root selects its already initialized interface once. Failed lookup/setup keeps the desktop rig. `XRInput` exposes focus, menu, pointer, trigger, and motion suppression; `XRNavigation` exposes cancellation, transition state, and an external stereo reset fade. The root pauses simulation/audio on tracking loss, cancels queued navigation on menus, connects arrival seeds, and samples poses even while settings are open to maintain recenter anchors.

The VR settings panel waits for a usable tracked head pose before appearing. Opening, resetting, or recovering tracking places it upright at the visitor's current eye height, 1.35 metres ahead; it then stays anchored in the world. Placement uses the runtime's adjusted head pose after recenter compensation, avoiding the camera's initial floor pose.

Renderer decision: desktop remains Compatibility. The VR-only launcher defaults to Mobile/Vulkan following current official XR guidance, with an explicit Compatibility option. Both variants passed a desktop mock render, not stereo/runtime validation. The UI's viewport stops rendering when closed; only one world settings surface is instantiated.

## Platform and renderer

Current spatial model: desktop motion is unbounded in all three axes. Cloud
transforms/custom data have authoritative CPU caches, so the avoidance simulation
also runs under Godot's headless dummy renderer. A fixed pool recycles distant
homes in a 24 m cube; shader distance fade conceals recycling. The rendering sphere
follows the head and uses accumulated periodic travel phase rather than a reachable
world boundary. Main rebases coordinates after 256 m, shifting cloud state and
atmosphere/menu with the rig; it preserves relative placement and visual phase.
Older garden radius/ground assumptions below are superseded by this spatial model.

Use the verified local Godot 4.7.2 stable installation and typed GDScript. Desktop preview is the first executable target. Windows PC VR through OpenXR is the first VR target, pending selection of a headset and working runtime.

The desktop prototype uses Compatibility, where the ribbon treatment is proven. The VR launcher uses Mobile/Vulkan by default following the current official setup guidance, with an explicit Compatibility option. Both paths pass ordinary-camera rendering tests, but T08 must still verify the target OpenXR runtime. Avoid assuming bloom, compute shaders, or advanced postprocessing are available; the shared visual treatment requires none of them.

Godot's official XR setup describes the OpenXR startup configuration and an origin/camera rig. Keep that setup centralized and initialize XR once. See [Setting up XR](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html) and [OpenXR settings](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html). Verify APIs against the installed engine when implementing; online stable documentation may track a different release.

Android export is outside v0. Once hardware is selected, consult [Godot's Android XR deployment guide](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html) for its current export/plugin requirements rather than preinstalling vendor dependencies.

## Proposed source layout

```text
project.godot
scenes/main.tscn
scripts/main.gd
scripts/contracts/{visitor_frame,audio_frame,dream_frame,dream_settings}.gd
scripts/input/desktop_input.gd
scripts/input/xr_input.gd
scripts/input/visitor_input.gd
scenes/rigs/{desktop_rig,xr_rig}.tscn
scripts/dream/{dream_director,motion_sampler}.gd
scripts/visuals/{ribbon_field,trace_field}.gd
shaders/{ribbon,trace}.gdshader
scripts/audio/audio_driver.gd
scripts/navigation/xr_navigation.gd
scripts/ui/settings_panel.gd
scenes/ui/settings_panel.tscn
resources/{moods,settings}/
assets/audio/
tests/
docs/validation/
```

Suggested main scene children: `VisitorRig`, `DreamDirector`, `RibbonField`, `TraceField`, `AudioDriver`, `Ground`, and `SettingsPanel`. Keep desktop and XR rig scenes separate. The composition root chooses the mode explicitly; an unavailable runtime produces a clear desktop fallback. Desktop launch should not require a headset.

## Shared interfaces

Distances use meters; velocities use m/s; time and delta use seconds. Positions and velocities are world-space. Energy and intensity values use the closed range 0–1. Contract frames use typed fields, not string-keyed dictionaries.

| Contract | Required fields |
| --- | --- |
| `VisitorFrame` | `head_transform: Transform3D`; left/right `hand_transform: Transform3D`; left/right `hand_valid: bool`; left/right `hand_active: bool`; `head_valid: bool`; `motion_discontinuity: bool` |
| `AudioFrame` | `low: float`; `mid: float`; `high: float`; `level: float`; `source_available: bool` |
| `DreamFrame` | `elapsed_seconds: float`; `mood_from: int`; `mood_to: int`; `mood_blend: float`; `stillness: float`; `visual_intensity: float` |
| `DreamSettings` | `volume: float`; `visual_intensity: float`; `seated_mode: bool`; `locomotion_mode: int`; `quality_tier: int` |

Enums are defined once in contracts: moods `SILK/CORAL/AURORA`; locomotion `TELEPORT/CONTINUOUS`; quality `LOW/DEFAULT`. Defaults: volume 0.5, intensity 0.5, seated false, teleport, default quality. Settings are session-local in v0.

`hand_valid` means usable tracking or an available desktop simulated pose. `hand_active` means interaction influence is enabled; desktop mouse buttons enable it, while tracked VR hands are active by default. Invalid tracking never generates traces or speed spikes. Physical headset motion remains independent of interaction activation.

Required module methods:

```text
VisitorInput.sample() -> VisitorFrame
AudioDriver.sample(delta: float) -> AudioFrame
MotionSampler.update(visitor: VisitorFrame, delta: float, settings: DreamSettings) -> float
DreamDirector.step(delta: float, stillness: float, settings: DreamSettings) -> DreamFrame
RibbonField.apply_frame(visitor: VisitorFrame, dream: DreamFrame, audio: AudioFrame) -> void
TraceField.update_frame(visitor: VisitorFrame, dream: DreamFrame, delta: float) -> void
TraceField.add_arrival_seed(position: Vector3) -> void
reset_session() -> void  # each stateful dream module
```

`MotionSampler.update` returns normalized stillness. It derives speed from successive valid transforms, resets samples on discontinuity, and handles paused/near-zero delta. `TraceField` owns its own previous-position sampling. `VisitorInput` is a common base script with desktop and XR implementations, not an autoload singleton.

`XRNavigation` emits `teleported(position: Vector3)` and marks the next input sample discontinuous. Recenter, runtime pause/resume, and tracking recovery also mark discontinuity; only teleport emits an arrival seed. The integrator connects signals to avoid navigation depending on trace visuals.

## Update ownership

`main.gd` owns the order: apply navigation → sample input → sample audio → calculate stillness → advance dream → update visuals and traces. Navigation and sampling happen on one consistent update tick; shader interpolation handles presentation. Use delta, not frame counts, for decay and mood transitions.

Only the composition root changes the active rig or resets the complete experience. Only `DreamDirector` advances moods. Visual modules never move the camera or read controller inputs directly. No visual shader performs audio analysis.

UI emits setting changes, reset requests, and exit requests; `main.gd` handles them. It pauses discovery timers and audio while settings are open. Reset clears previous pose samples as well as memory to prevent a line connecting old and new positions.

## Rendering and bounded resources

- Prototype default: 128 ribbon instances; low tier: 64. Start with a reusable segmented strip mesh and instanced rendering where supported.
- Shader deformation uses rest geometry, a small set of time/mood parameters, and two hand influence positions. No per-ribbon scene script or rigid-body chain.
- Trace pool: at most 256 stroke instances and 64 matured curl instances. Reuse oldest slots; no node creation every frame.
- Deposit a stroke only after 0.12 m movement and at least 0.1 seconds since the last deposit for that source. Limit each stroke to 0.35 m; discard discontinuous samples instead of drawing long connectors.
- Head travel strokes use the floor projection. Use speed/position of the head in world space, with discontinuity suppression, so artificial and physical walking work consistently.
- Cap total mature curl count separately; a curl does not extend its parent's 90-second lifetime.
- Favor opaque/alpha-cutout forms first. Transparent layers require an overdraw check in stereo.
- Keep distant canopy inexpensive and stationary in world space. Do not implement an enormous physical world.

These are initial budgets. Agents may expose them as resource parameters but must not silently raise the maximums to hide visual problems.

## Audio implementation

T05 owns one named audio bus and a spectrum-analysis path if supported by the selected engine configuration. It outputs smoothed normalized bands and never mutates visual nodes. Use a synthetic envelope fixture for repeatable tests and silent mode. Missing audio assets or analyzer data must not crash or freeze the dream.

Document the license and origin of any bundled loop. If no approved asset exists, use a deterministic synthesized ambient placeholder and label it as such. Do not download commercial music or add audio services.

## Validation and performance

Meaningful automated checks: delta-independent mood timing, reset behavior, trace pool limits and expiry, no trails on teleport/recenter, invalid tracking handling, and normalized audio bounds. Pure logic fixtures should run headlessly where possible. Rendering and tracking require visible/manual checks.

For each hardware run record engine version, commit or source snapshot, device, runtime, renderer, refresh rate, quality tier, duration, and profiler observations. Measure CPU/GPU frame time separately when tooling supports it. Ten-minute idle and interaction runs must keep memory counts bounded.

VR target: sustain the selected device's refresh rate with approximately 20% frame-time headroom in the representative scene. At 72 Hz that means a 13.9 ms frame budget and roughly 11.1 ms target CPU/GPU frame time; at 90 Hz, 11.1 ms and roughly 8.9 ms. These are targets, not current performance claims. A desktop FPS result cannot pass the headset gate.

## Unknowns that do not block desktop work

Headset/runtime; controller bindings and menu button availability; seated height conventions; target GPU; renderer behavior in that runtime; approved ambient loop; final distribution mode. T08 resolves device-specific questions before declaring XR complete. Standalone support requires a separate scoped decision.


