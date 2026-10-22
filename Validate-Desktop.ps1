param([switch]$Render)
$ErrorActionPreference = 'Stop'
$gardenConsole = 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$gardenPreviousAppData = $env:APPDATA
$gardenPreviousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $PSScriptRoot '.runtime'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    $env:LOCALAPPDATA = Join-Path $PSScriptRoot '.runtime/local'
    New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
    function Invoke-GardenCheck([string[]]$CheckArguments) {
        # Godot consumes --xr-mode before OS.get_cmdline_args(). Pair engine
        # XR-off with a retained user flag so scene startup skips lookup too.
        if ('--' -notin $CheckArguments) { $CheckArguments += '--' }
        $CheckArguments += '--desktop'
        $gardenOutput = & $gardenConsole --path $PSScriptRoot --xr-mode off @CheckArguments 2>&1
        $gardenExit = $LASTEXITCODE
        $gardenOutput | ForEach-Object { Write-Output "$_" }
        $gardenText = $gardenOutput -join "`n"
        if ($gardenExit -ne 0 -or $gardenText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|ObjectDB instances were leaked|ERROR: (?!Failed to read the root certificate store)') {
            throw "Godot validation failed (exit $gardenExit): $($CheckArguments -join ' ')"
        }
    }
    Invoke-GardenCheck @('--headless', '--editor', '--import', '--quit')
    foreach ($gardenFixture in @('test_dream_state.gd', 'audio_driver_test.gd', 'ribbon_validation.gd', 'test_endless_space.gd', 'test_traces.gd', 'test_integration.gd', 'test_xr_math.gd', 'test_xr_startup.gd', 'test_xr_tracking.gd', 'test_xr_lifecycle.gd', 'test_xr_panel.gd', 'test_xr_integration.gd')) {
        Invoke-GardenCheck @('--headless', '--script', "res://tests/$gardenFixture")
    }
    if ($Render) {
        Invoke-GardenCheck @('--audio-driver', 'Dummy', '--script', 'res://tests/test_integration.gd')
        Invoke-GardenCheck @('--audio-driver', 'Dummy', '--script', 'res://tests/test_endless_space.gd')
        Invoke-GardenCheck @('--audio-driver', 'WASAPI', '--script', 'res://tests/test_audio_playback.gd')
        Invoke-GardenCheck @('--audio-driver', 'Dummy', '--script', 'res://tests/test_xr_integration.gd', '--', '--render-xr-mock')
        Invoke-GardenCheck @('--audio-driver', 'Dummy', '--rendering-method', 'mobile', '--rendering-driver', 'vulkan', '--script', 'res://tests/test_xr_integration.gd', '--', '--render-xr-mock')
        foreach ($gardenMood in 0..2) {
            Invoke-GardenCheck @('--audio-driver', 'Dummy', '--resolution', '1280x800', '--fixed-fps', '60', '--', "--capture=res://docs/validation/garden_mood_$gardenMood.png", "--capture-mood=$gardenMood", '--capture-bloom=0')
        }
        Invoke-GardenCheck @('--audio-driver', 'Dummy', '--resolution', '1280x800', '--fixed-fps', '60', '--', '--capture=res://docs/validation/garden_bloom.png', '--capture-mood=1', '--capture-bloom=1')
        Invoke-GardenCheck @('--audio-driver', 'Dummy', '--resolution', '1280x800', '--fixed-fps', '60', '--', '--capture=res://docs/validation/garden_menu.png', '--capture-menu')
    }
    Write-Output 'DESKTOP VALIDATION PASSED. XR was explicitly disabled for every process.'
} finally {
    $env:APPDATA = $gardenPreviousAppData
    $env:LOCALAPPDATA = $gardenPreviousLocalAppData
}
