# OpenXR integration validation — October 10, 2026

T08/T09 are integrated into the executable experience. All testing used `--xr-mode off`; no actual OpenXR interface/runtime was initialized and no headset modal was triggered. Hardware acceptance remains pending.

## Startup and launch

The user requested XR enabled by default for Godot Play. `project.godot` now sets `xr/openxr/enabled=true`, and the main scene selects XR without an extra `--vr` argument. `Launch-Desktop.ps1` and every validation process override this using `--xr-mode off -- --desktop`. The optional VR launcher defaults to Mobile/Vulkan; `-Renderer Compatibility` selects OpenGL. Its renderer choice follows [Godot's current XR setup guidance](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html); the project Play renderer remains its existing Compatibility setting.

OpenXR initializes at engine startup from the enabled project setting. `XRStartup` rejects headless, editor, capture, smoke, or retained desktop requests before calling its interface resolver. Godot consumes the engine XR-mode argument, so tests pair engine-level XR off with `--desktop` to suppress scene lookup as well. The composition root looks up the already initialized OpenXR interface once, creates the tracked rig, replaces desktop input, enables XR viewport output, and disables monitor vsync. Unavailable interface/rig setup leaves the desktop scene running. No script repeatedly initializes the interface.

`resources/xr/default_action_map.tres` was generated from the installed Godot 4.7.2 defaults using a resource-only headless/XR-off script. It is configured in project settings; XR shader variants are enabled. No vendor plugin or downloaded bindings are required for this Windows PC VR prototype. Actual interaction profiles still need a device check.

## Experience wiring

- Both tracked grip hands feed the existing bend/memory/bloom contracts. Tracked head movement remains owned by the runtime.
- Right trigger aims at the flat floor and releases to teleport within the garden's 7 m usable radius. Invalid targets cannot commit. Right stick provides discrete 30-degree head-pivot snap turns.
- Navigation applies a 3D camera-attached fade, commits relocation under a fully opaque frame, and suppresses motion/input briefly afterward. Teleport emits one arrival seed; snap and recenter emit none.
- Menus and tracking/focus loss cancel queued movement. Trigger release and stick centering are required before navigation can rearm, preventing a settings click from becoming a teleport.
- Loss of normal tracking or runtime focus pauses simulation/audio. Recovery resets motion samples and preserves memory and menu state.
- Recenter saves the last valid world head pose and compensates horizontal position/yaw through the rig root at the next sample after pose update. It never overwrites tracked camera/controller local poses or clears dream memory.
- Session reset clears memory and state, returns the rig to the start, and fades through a 3D quad rather than a flat desktop overlay.

## In-world settings

`XRPanel` reparents the same DreamUI into a 700 × 760 SubViewport textured on a 1.05 × 1.14 m plane, placed 1.35 m ahead at current head height whenever opened. It removes roll/pitch and stays fixed in the world while open. Seated height is naturally supported. The closed viewport stops rendering.

A right-controller aim ray maps to panel pixels and injects viewport mouse motion/press/release events. The pointer line and cursor show selection position. Volume and intensity sliders, seated toggle, density cycle, resume, reset, and exit are all controller operable. A density cycle replaces the desktop popup menu to keep all interaction in one surface. Tracking/ray loss cancels an active button press/slider drag. Opening/re-entering with trigger held requires release before a new click.

Menu action: left primary-stick click or available menu/left face button. Right trigger selects controls. Keyboard Escape remains a desktop fallback. Real runtime reservations/bindings have not been tested.

## Actual headset-free results

Engine `4.7.2.stable.official.ed1daf0bf`, Windows, NVIDIA RTX 4070 Ti SUPER. The test provider/camera/controller data is synthetic; XR output remains disabled even in the full-composition fixture.

| Fixture | Result |
| --- | --- |
| XR startup | 19 checks, 0 failures after default change; no-argument Play, project/command overrides, retained desktop gate, unavailable/uninitialized providers, loaded action map. |
| XR math | 0 failures; bounded floor rays, physically offset head teleport/snap, height/heading preservation, action names. |
| XR lifecycle | 30 checks, 0 failures; opaque commit, once-only arrival signal, quiet interval, focus/aim loss, trigger/stick latch, reset fade, recenter compensation. |
| XR panel | 0 failures; rotated mapping, finite/bounded rays, slider drags, every action, tracking-loss cancellation, held-trigger protection. |
| Full XR composition, headless | 18 checks, 0 failures; tracked rig replacement, world UI, menu/focus gates, arrival seed, memory preservation, reset fade. |
| Full XR composition, desktop rendered | 19 checks, 0 failures on Compatibility and Mobile/Vulkan; additional screenshot capture. |
| Desktop regression | 19 headless / 22 visible checks, 0 failures. |

`docs/validation/xr_integrated.png` was rendered and inspected using an ordinary Camera3D under Mobile/Vulkan with XR off. It shows the settings plane centered and readable in the actual garden. `xr_panel.png` is an isolated mocked-ray panel capture. These prove mono desktop presentation, not stereo readability or comfort.

See [panel details](xr_panel.md) and [lifecycle details](xr_lifecycle.md). `Validate-Desktop.ps1 -Render` includes the new fixtures and both renderer mock captures, always forcing XR off. The VR launcher has not been executed during testing.

## Pending hardware gates

Verify a named Windows runtime/headset/controller profile: startup, stereo shader/UI rendering, head/controller tracking, focus events, runtime recenter timing, actual menu reservations, trigger release, snap/teleport/fades, reset/exit access, seated use, frame pacing and comfort. The recenter compensation assumes the next sample observes the updated pose; confirm that timing on the target runtime. CPU/GPU refresh-rate budgets and the participant discovery review remain open. Standalone export/distribution is outside this integration.

Default-XR follow-up: the full headless validation suite and visible desktop integration fixture passed with engine XR off and retained desktop flags. Startup: 19 checks; desktop: 19 headless / 22 visible checks; zero failures. No actual XR startup was tested. Results: .runtime/xr-default-validation.log. Repository AGENTS.md preserves the required testing overrides.
