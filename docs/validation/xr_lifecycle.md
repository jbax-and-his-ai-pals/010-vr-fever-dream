# XR lifecycle validation

Validated with installed Godot 4.7.2 stable on 2026-10-10. Every test command uses `--headless --xr-mode off`; no XR interface is initialized and no headset runtime or device is requested.

```powershell
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --xr-mode off --path . --script tests/test_xr_math.gd
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --xr-mode off --path . --script tests/test_xr_lifecycle.gd
```

The math fixture passed with zero failures. It checks inert interface setup, invalid absent tracking, discontinuity on pause/recovery, bounded floor targets, offset tracked-head teleport placement, height and heading preservation, and twelve 30-degree snaps returning to the original transform. Constructing an `OpenXRActionMap` resource confirms installed default action names for trigger, stick, menu, controller button fallbacks, and grip/aim poses without creating a device session.

The lifecycle fixture passed all 30 checks with an ordinary `Camera3D`, a simulated focus flag, and simulated controller values. It checks partial fade-out, no early relocation, fully opaque relocation even for a large timestep, exactly one teleport signal, physical head offset placement, partial fade-in, post-move quiet interval, queued-move cancellation on focus loss, discontinuity on focus recovery, trigger release required after menu cancellation, invalid aim rejection on release, one snap per stick deflection, and external reset fade gating/release. Synthetic recenter tests additionally verify preserved world head floor position and heading, unchanged tracked camera pose, no added pitch/roll, invalidated motion history, and no compensation for ordinary physical movement.

The navigation API exposes `cancel_navigation()`, `transition_active()`, `set_external_fade(alpha)`, and `reset_session()`. Cancellation clears queued movement and requires a released trigger and centered stick before rearming. Successful movement suppresses pose sampling for 0.25 seconds, and navigation remains gated for a 0.25-second quiet interval after fade-in. Focus recovery invalidates previous pose history. A dedicated aim node is available for each controller; hand interaction uses grip poses.

Recenter timing: the runtime's `pose_recentered` signal captures the most recently sampled valid head world transform and marks compensation pending. The next focused `sample()` applies `apply_recenter_if_pending()` after the engine has updated tracked poses. Compensation changes only the rig root's horizontal placement and yaw, leaving the tracked camera pose, head height, pitch/roll, and world memory intact. Real runtime signal/pose-update timing still requires hardware validation.

Real headset checks remain pending: runtime initialization, device/controller profile bindings, stereo fade coverage, reference-space recenter behavior, tracking loss/recovery, pointer operation, perceived comfort, and headset frame rate. The fixtures do not establish those hardware properties.

Sandbox runs emitted environmental log-directory and root-certificate-store warnings; both scripts completed with exit code 0 and no failed checks.
