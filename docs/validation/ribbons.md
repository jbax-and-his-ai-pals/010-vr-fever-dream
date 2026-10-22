# Ribbon material and interaction module

Implemented 2026-10-10 with Godot 4.7.2 stable (`ed1daf0bf`). Renderer: Compatibility / OpenGL 3.3, NVIDIA driver 591.86, NVIDIA GeForce RTX 4070 Ti SUPER. This is desktop material evidence; no headset or OpenXR initialization was used.

## Reproduction

Run from the project directory in PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.runtime'
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --xr-mode off --audio-driver Dummy --rendering-method gl_compatibility --script tests/ribbon_validation.gd -- --ribbon-render
```

Omit `-- --ribbon-render` and add `--headless` for the logic-only fixture. Visible fixture auto-exits and writes four PNGs in this directory. The isolated scene intentionally contains no floor, UI, sound, or stars; those belong to the integration scene.

## Observed and checked

- Visible render exited 0. No shader or GDScript errors. The environment emits `Failed to read the root certificate store`; it does not prevent these local rendering checks.
- Viewed `ribbon_mood_0.png`, `ribbon_mood_1.png`, and `ribbon_mood_2.png`: Silk cyan/lilac long arcs, Coral peach/amber curls, and Aurora teal/rose streams render as opaque double-sided ribbons with depth and varied orientation.
- Viewed `ribbon_bloom.png`: nearby upper ribbons spread and curl into abstract folded petals. Distant strands retain their shape, since bloom influence fades with visitor distance.
- Automated fixture checks 128 default / 64 low visible instances, activation ramp, invalid hand position retention, release below 1% after two seconds, and reset of both strengths and time history. Prints `RIBBON CHECKS PASS`.
- All 128 instances share one 40-segment strip mesh and one material. No per-frame node, mesh, or instance allocation. Low tier changes visible instance count.
- Shader hand contributions are evaluated independently, added, and clamped to a combined 0.6 m maximum (configurable downward). Root anchoring and intensity multiply by factors no greater than one. Support radius is 1.25 m by default; outside it the influence is zero.
- Mesh bounds include deformations; the field has a conservative 20 × 9 × 20 m custom AABB. Ribbon transforms remain fixed, and the camera is never modified.
- Screenshot inspection caught a global/local basis scaling issue that made rotated strands too wide; corrected by multiplying rotation by local scale. A spawn exclusion radius also avoids accidental near-camera obstruction, with four explicit reachable strands in front.

## Integration API

`RibbonField` extends `Node3D`. Add it to the tree before calling `apply_frame(visitor: VisitorFrame, dream: DreamFrame, audio: AudioFrame)`. It exposes `reset_session()`, `set_quality(tier: int)`, and `get_instance_count()`.

Time comes exclusively from `DreamFrame.elapsed_seconds`; opening settings can freeze animation by freezing that clock. It consumes palettes and shape parameters from `mood_from`, `mood_to`, and `mood_blend`. All input poses and shader deformation are world-space. Invalid/inactive hands fade at their last valid position rather than snapping toward the origin. A discontinuity clears hand strengths immediately.

## Pending checks

After inspecting the integrated `garden_silk.png`, reduced the four nearby strand widths by 40%, lowered their heights to 1.62–1.80 m, and moved their roots to either side of the centre view. Added a rounded taper over the upper 28% and a restrained tip curl in all moods. The integrator rendered and inspected the final `garden_mood_0.png`, `garden_mood_1.png`, `garden_mood_2.png`, and `garden_bloom.png`; the isolated mood PNGs above show earlier geometry. The final fixture was rerun after this polish.

Interactive mouse-hand discovery and actual withdrawal should be checked in the integrated desktop scene. The fixture verifies influence plumbing and shader bounds, but does not replace a human interaction observation. No ten-minute performance claim, stereo check, or headset gate is asserted here. Opaque emissive-looking colors suggest glow without requiring unsupported Compatibility bloom or transparent overdraw.
