param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$gardenEngine = 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $gardenEngine)) { throw "Godot executable not found: $gardenEngine" }
$gardenArguments = @('--path', $PSScriptRoot, '--xr-mode', 'off')
if ($Editor) { $gardenArguments += '--editor' }
& $gardenEngine @gardenArguments -- --desktop
