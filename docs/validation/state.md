# Stillness and mood validation

T06 implemented on 2026-10-10. Pure state behavior is checked; visible bloom and real tracked-pose feel remain integration/manual checks.

## Interfaces and tuning

`MotionSampler` extends `RefCounted`. `update(visitor: VisitorFrame, delta: float, settings: DreamSettings) -> float` returns the normalized **bloom envelope** consumed as `DreamFrame.stillness`. `smoothed_speed` is available for debugging. `reset_session()` clears pose history, filtered speed, delay, and bloom.

Speed combines translation with angular motion expressed at a 0.15 m radius. A 0.25 s exponential filter removes tiny transients. Valid head/left/right pose weights are 0.65/0.175/0.175 normally and 0.85/0.075/0.075 when seated, normalized over available poses. Valid hands contribute even when interaction is inactive. Missing, nonfinite, singular, and mirrored poses do not contribute. Recovery establishes a baseline before speed calculation; no valid tracking clears bloom. Discontinuity clears all sampler state immediately. Zero/negative/invalid delta preserves the envelope and discards previous pose samples for safe resume.

At or below 0.08 m/s, bloom starts after 3 s and reaches 1 at 8 s. Renewed motion closes from 1 to 0 over 2 s after the speed filter crosses the threshold. Brief pauses during closing preserve the surviving bloom while the quiet timer restarts. No headset or camera transform is changed.

`DreamDirector` extends `RefCounted`. `step(delta: float, stillness: float, settings: DreamSettings) -> DreamFrame` advances elapsed time and writes bounded bloom/intensity. `reset_session()` restores elapsed time to zero; the integrator must reset MotionSampler at the same time. Each mood dwells 90 s, blends 30 s, then advances Silk → Coral → Aurora → Silk. Large deltas correctly skip phases. Invalid/nonpositive delta does not advance time.

`resources/moods/{silk,coral,aurora}.tres` are three-point `Gradient` resources for the design palettes. Shape and audio tuning belong to their consuming modules; these palettes do not create another contract or override renderer parameters.

## Actual command and results

Run from the project root in PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.runtime'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --xr-mode off --path . --script tests/test_dream_state.gd
```

Engine: `4.7.2.stable.official.ed1daf0bf`. Result: **36 checks, 0 failures, exit 0**. The process prints `Failed to read the root certificate store`, an environment warning unrelated to the state fixture. It performs no network or XR initialization.

Checks cover delayed/half/full bloom, renewed motion decay, resets, invalid and nonfinite tracking, recovery baselines, discontinuity, angular motion, paused position changes, seated weighting, all three palette resource loads, exact dwell/blend/cycle boundaries, bounded outputs, and delta-independent timing.

Synthetic natural motion uses head breathing of 6 mm at 0.3 Hz and hand tremor of 2 mm at 3 Hz. Bloom/decay envelopes at 30/90/120 Hz agree with 60 Hz within 0.025 normalized units. Mood blend at 105 seconds agrees within 0.00001 at 30/60/90/120 Hz. These tolerances and samples demonstrate timer behavior, not hardware comfort or universal tremor tolerance.
