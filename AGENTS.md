# Godot launch and testing

- The user now wants **desktop by default** while tuning the experience. Preserve `xr/openxr/enabled=false`. VR remains available through Launch-VR.ps1 with engine `--xr-mode on` and retained user `--vr`.
- Every agent-run Godot command, including imports/editor checks, MUST pass `--xr-mode off`. Never run the VR launcher or initialize a headset runtime during testing; it triggers a modal the user may be unable to dismiss.
- For runnable tests/previews, also pass `--desktop` after Godot's `--` user-argument separator. Godot consumes `--xr-mode` before scripts can inspect it; this retained flag prevents scene runtime lookup too.
- Prefer `Validate-Desktop.ps1` or `Launch-Desktop.ps1`, which apply these overrides. Existing user arguments go after the same separator.
- Use mocked tracking and ordinary Camera3D renders to validate XR code. Keep real headset tracking, stereo, performance, and comfort checks explicitly pending until arranged by the user.
