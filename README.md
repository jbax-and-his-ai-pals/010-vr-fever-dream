# VR Fever Dream — Living Feedback Garden

Working prototype: October 10, 2026. Desktop is the default for Godot Play while the visual experience is being tuned. OpenXR remains available through the explicit VR launcher. Tests use desktop/mocked tracking with XR explicitly disabled; real headset performance, comfort, and discovery gates remain pending.

A surreal Godot experience: drift endlessly through a fluid atmosphere where sparse cloud forms emerge, retreat from your approach, and change shape and colour. No combat, score, inventory, world edge, or required destination.

## Read in this order

1. [Experience design](docs/DESIGN.md): what to build and how it should feel.
2. [Technical contracts](docs/TECHNICAL.md): Godot structure, shared interfaces, and constraints.
3. [Roadmap and task packets](docs/ROADMAP.md): dependency order, file ownership, and acceptance checks.
4. [Agent handoff](docs/AGENT_HANDOFF.md): a reusable implementation prompt and reporting format.

## Current decisions

- Engine: installed Godot **4.7.2 stable**, verified using the console executable.
- Language: typed GDScript; Godot shaders for visual deformation.
- Prototype: desktop by default; optional Windows OpenXR and controller-operated world settings.
- Desktop renderer: Compatibility. VR launcher defaults to Mobile/Vulkan, with a Compatibility option. Both renderers passed headset-free mock scene checks.
- Target headset, OpenXR runtime, and distribution destination: not yet selected.
- Standalone headset export: later, only after the target hardware is selected.
- Scope: one continuous fluid space, sparse deforming clouds, free desktop drift, and three visual moods.

## Play the desktop prototype

Run [Launch-Desktop.ps1](Launch-Desktop.ps1) from PowerShell:

```powershell
.\Launch-Desktop.ps1
```

Press Enter or choose **Wander in**. WASD drifts, mouse looks, Space rises, Ctrl sinks, left/right mouse buttons disturb nearby forms, and Q/E adjusts reach. Escape opens settings; M mutes; R resets with a fade; F3 shows diagnostics; F11 toggles fullscreen. Menus pause the dream and release the mouse. Sound volume, visual intensity, seated mode, and 10/16 cloud density are adjustable.

Godot's Play button launches desktop by default: `openxr/enabled=false`. The desktop launcher explicitly passes `--xr-mode off -- --desktop`, so the preview requires no headset or runtime prompt. Every automated test also supplies these overrides.

The ambient loop is original synthesized placeholder audio. The scene uses procedural meshes/shaders and requires no external asset downloads or plugins.

## Open in Godot

Open `project.godot` normally and press **Play (F5)** for desktop. Restart/reopen the editor once if it was already open when XR startup settings changed. If OpenXR is unavailable, the scene falls back to the desktop preview.

For explicit desktop-only editor inspection:

```powershell
.\Launch-Desktop.ps1 -Editor
```

Or use the installed executable directly, explicitly keeping XR off:

```powershell
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --editor --xr-mode off --path .
```

## Optional VR launcher

VR is an explicit opt-in. [Launch-VR.ps1](Launch-VR.ps1) is an optional shortcut with renderer selection:

```powershell
.\Launch-VR.ps1
# Optional OpenGL renderer for a runtime that supports it:
.\Launch-VR.ps1 -Renderer Compatibility
```

This launcher explicitly enables OpenXR (`--xr-mode on`) and may open the runtime/headset prompt. Normal Godot Play stays in desktop. It is never used by automated tests. A Windows OpenXR runtime and controllers are needed for actual play. The scene selects an already initialized OpenXR interface once and falls back to desktop if it is unavailable; it never repeatedly calls initialize.

In VR, point the right controller at the in-world settings and press/release trigger to select. Settings includes volume, intensity, seated stillness, density, resume, reset, and exit. Left stick click (or an available menu/left face button) toggles settings. Outside the menu, hold right trigger to aim at the floor and release to teleport; right stick left/right gives 30-degree snap turns. Tracked hands disturb nearby cloud forms without holding a button. Release trigger after closing a menu before teleporting. Artificial continuous locomotion is not enabled.

Loss of tracking or runtime focus pauses the dream and cancels queued movement. Teleports add one arrival seed without a connecting trail. Recenter compensates horizontal placement/heading through the rig root; it preserves dream memory. Session reset uses a 3D fade visible to both eyes and restores the start.

The VR-only Mobile/Vulkan default follows [Godot's current XR renderer guidance](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html). Stereo rendering, bindings, reference-space behavior, and comfort still require a real headset check. See [VR integration validation](docs/validation/xr.md).

## Validate

```powershell
.\Validate-Desktop.ps1          # import and headless behavior fixtures
.\Validate-Desktop.ps1 -Render  # also checks visible input and saves screenshots
```

All validation processes explicitly disable XR. Screenshot/input checks use Dummy audio and short automatically closing windows; an additional WASAPI startup check runs at exact zero gain. A render input fixture briefly captures/releases the mouse. Tests cover desktop behavior plus VR startup gates, lifecycle/transition math, controller rays and settings, and full integration with a normal Camera3D. Compatibility and Mobile/Vulkan mock scenes are rendered without XR output. See [desktop validation](docs/validation/desktop.md) and [VR validation](docs/validation/xr.md).

## Next work

Review the feel before expanding content. When convenient, select a headset/runtime for manual binding, tracking, stereo, performance, and comfort checks. T08/T09 integration is implemented; hardware acceptance remains pending. No Git repository or exported executable has been created.



