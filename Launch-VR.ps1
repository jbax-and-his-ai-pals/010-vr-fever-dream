param([ValidateSet('Mobile', 'Compatibility')][string]$Renderer = 'Mobile')
$ErrorActionPreference = 'Stop'
$gardenEngine = 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $gardenEngine)) { throw "Godot executable not found: $gardenEngine" }
# Explicit opt-in VR launcher; ordinary Godot Play defaults to desktop.
$gardenArguments = @('--path', $PSScriptRoot, '--xr-mode', 'on')
if ($Renderer -eq 'Mobile') {
    $gardenArguments += @('--rendering-method', 'mobile', '--rendering-driver', 'vulkan')
} else {
    $gardenArguments += @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3')
}
$gardenArguments += @('--', '--vr')
& $gardenEngine @gardenArguments
