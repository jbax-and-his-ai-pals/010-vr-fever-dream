# Ethereal drift pass — October 10, 2026

Desktop is the default (`openxr/enabled=false`). Explicit VR launcher supplies
both `--xr-mode on` and retained `--vr`; automated checks always force XR off.
Startup mock fixture: 22 checks, zero failures, including desktop skipping an
already initialized provider and explicit opt-in selection.

Flat strips are replaced with 16/10 instanced, deformed sphere shapes, broad
translucent colour mixing, feathered silhouettes, and proximity dissolve. Floor
and border-ring meshes are removed. Trace logic remains bounded but its geometry
is hidden. Desktop proxy hands and exploration HUD are hidden. WASD/mouse and
Space/Ctrl allow horizontal and vertical drift within a bounded volume. The
enclosing shader time rate changed from 0.075 to 0.012 (about six times slower).

Full Validate-Desktop.ps1 suite passed. Desktop integration passed 20 headless
and 25 visible checks; visible checks include rise/sink and captured mouse input.
Cloud activation/release/reset/count fixture passes. Cloud shaders rendered in
Compatibility and Mobile/Vulkan without errors; no headset/runtime initialized.

Final desktop preview: [ethereal_drift.png](ethereal_drift.png).
Actual hardware performance and participant feel review remain pending.
