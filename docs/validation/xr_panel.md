# XR world settings panel validation

Validated on 2026-10-10 with Godot 4.7.2 stable. Every invocation used
`--xr-mode off`. The fixture creates an ordinary `Camera3D`, a world panel,
and mocked controller rays. No XR interface is created or initialized.

## Integration API

Create `XRPanel`, add it to the world, then call
`setup(existing_ui: DreamUI, camera: Camera3D, wait_for_tracking: bool = false)`.
The main VR scene passes `true` and calls `update_head_pose(world_head, tracked)`
after sampling. The menu stays hidden until a valid head pose arrives, then
places at eye height; tracking recovery repeats placement. An open panel stays
anchored during ordinary head movement. The already-ready DreamUI is
reparented into a 700 × 760 SubViewport; its settings, signals, and status API
remain intact. The `ui` property aliases that existing UI. The desktop header
and footer are hidden, and density uses a cycle button rather than a popup.

Call `update_pointer(origin, direction, trigger_pressed, valid)` with the
selected controller's global aim pose. A miss, closed menu, or invalid tracking
cancels any pending press. After a canceled held press, the trigger must be
released before another click. Every menu open also requires trigger release,
so opening with a held trigger cannot activate a control. Canceling a slider
drag preserves its last value. Menu reopening places the 1.05 × 1.14 metre
panel 1.35 metres ahead at the tracked head height, with no roll or pitch.
It stays fixed in world space while open. `release_pointer()` is also available
for explicit controller switching or pause/lifecycle cancellation.

The panel owns the reparented UI and its SubViewport, meshes, and materials.
Freeing the panel recursively frees these resources and disconnects signals.
Reparent the UI out first only if deliberately reusing it after panel removal.

## Checks

`tests/test_xr_panel.gd` passes with zero failures in headless mode and in an
ordinary rendered desktop window. It verifies:

- Seated head height and level panel orientation.
- Center mapping, rotated panels, parallel/backward/missing/out-of-range rays,
  and non-finite coordinates.
- Controller clicks on density, seated mode, Reset, Leave, and Wander.
- Controller dragging of ambient sound and visual intensity sliders.
- Tracking loss cancels a press without activating Reset, and held trigger
  cannot activate a new press after tracking returns or on menu reopening.
- Canceled slider drag preserves the last value.
- Closing hides the surface and releases input; reopening restores it.

After the floor-height placement fix, the full desktop validation suite passed.
`test_xr_tracking.gd` passed 19 checks using synthetic tracker poses. The integrated
scene fixture passed 23 headless checks and 24 rendered checks, including delayed
startup, a valid runtime pose while the camera node is still at floor height,
world anchoring, and standing-to-seated tracking recovery. The updated integrated
screenshot was inspected: the upright menu is centred in the view and all controls
fit. All processes explicitly disabled XR; hardware verification remains pending.

Run from the project directory, using the user's console executable:

```powershell
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --xr-mode off --path . --log-file 'C:\jbax-and-his-ai-pals\010-vr-fever-dream\docs\validation\xr_panel.log' --script tests/test_xr_panel.gd -- --desktop
```

Omit `--headless` and append `--capture` after `--desktop` to generate the rendered desktop
proof [xr_panel.png](xr_panel.png). The screenshot was inspected: the plane
faces the camera, text is upright, all controls fit, and both slider values
reflect the mocked interactions. Sandbox certificate-store and shader-cache
warnings are unrelated to the panel fixture.

Actual headset legibility, stereo depth, controller runtime mappings, and
comfort remain manual hardware checks; they were intentionally not required.
