# Fluid border sphere — October 10, 2026

GardenStage now owns an opaque, inward-visible 14 m radius sphere at (0, 3, 0),
outside the navigable 7 m radius garden. It replaces the distant star specks.
The atmosphere shader uses object-space directions, three nested vortex warps,
mixing dye pools, folded filaments, and slow colour drift. There is no UV seam,
screen-space feedback buffer, or per-frame geometry allocation. Pixel derivatives
fade fine detail to reduce aliasing. Visual intensity controls its brightness;
the shared dream clock drives flow, pauses with the dream, and resets with it.

The art direction is surreal and restless rather than relaxing. UI invitation
copy now refers to distortion and disturbing the pattern; existing mechanics
and seated access remain available.

Validated with Godot 4.7.2, every process using `--xr-mode off` and `--desktop`:

- Full Validate-Desktop.ps1 suite passed.
- Compatibility/OpenGL and Mobile/Vulkan renders saved successfully with no
  shader errors. Compatibility screenshot inspected after detail filtering.
- Preview: [fluid_atmosphere.png](fluid_atmosphere.png).
- Mobile render: [fluid_atmosphere_vulkan.png](fluid_atmosphere_vulkan.png).

Real headset stereo and GPU frame time remain unmeasured. Normal Godot Play
continues to enable XR by default.
