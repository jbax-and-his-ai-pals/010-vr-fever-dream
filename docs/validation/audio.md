# T05 audio validation

Implemented `scripts/audio/audio_driver.gd`: `AudioDriver extends Node`, with `sample(delta) -> AudioFrame`, `reset_session()`, `set_volume(value)`, and `set_paused(value)`. An idempotent `shutdown()` releases playback, stream, analyzer, and the owned bus. The composition root should call it before quitting and allow audio-server stop processing; `_exit_tree` calls it as a safeguard.

## Behavior and provenance

The default envelope mode is deterministic synthetic low/mid/high/level modulation on a 16-second cycle. Exponential smoothing uses a 0.32-second time constant. Values remain normalized. Volume controls playback independently of visual envelopes. Pause freezes envelopes and pauses playback; reset clears smoothing/time and restarts playback while preserving pause and volume.

The ambient placeholder is original synthesized audio generated entirely by this repository's code. No downloaded recording, external music, sample library, or third-party audio license is involved. It combines sine tones at 110, 220, 330, 880, and 2640 Hz with periodic amplitude modulation. A 16-second mono 22050 Hz / 16-bit PCM loop is allocated once at startup, approximately 706 KB. The frequencies and modulation periods have integer cycle counts across the loop. Default volume is 0.5; measured PCM peak is 0.15834 full scale, giving approximately 0.0792 full scale at default volume. This is a placeholder for later listening and tuning.

One `DreamAmbient` bus is created at runtime, routed to Master, and given a spectrum analyzer. The driver releases its owned bus on exit. No project bus-layout changes are needed. The optional `EnvelopeMode.SPECTRUM` path queries peak magnitude in 40–250, 250–2000, and 2000–8000 Hz bands and normalizes against the placeholder's expected levels. Missing analyzer and mute use the synthetic envelope. Real spectrum data of actual silence produces zero targets and decays through smoothing.

Headless execution and the Dummy audio backend skip audio player, bus, and PCM startup allocations. Synthetic envelopes continue, and `source_available` is false. In visible execution with a real audio backend `source_available` reports a playing source, independently of volume; it does not claim that a user heard it. Volume zero sets exact zero linear playback gain. The composition root should own the one driver and call `sample()` once each update tick.

API details for later agents: `playback_enabled = false` opts out of player/bus creation; `envelope_mode` defaults to `SYNTHETIC`; `volume` defaults to 0.5. Set volume through `set_volume()` after initialization. Changing envelope mode needs no scene changes. `sample()` does not advance itself through `_process`.

## Actual checks — 2026-10-10

Run from the repository root in PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.runtime'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --xr-mode off --path . --script tests/audio_driver_test.gd
```

Godot `4.7.2.stable.official.ed1daf0bf` exited 0. Fixture result: **0 failures**, measured PCM peak **0.15833002716147**. Checks cover:

- Ten minutes of synthetic sampling with every band finite and within 0–1.
- No available player in headless mode, missing-analyzer fallback, and continued visual envelopes at volume zero.
- Pause, reset, invalid delta handling, and idempotent shutdown.
- A synthetic low-only envelope stimulus changes low with zero high response.
- 30 Hz versus 120 Hz sampling over ten seconds differs by less than 0.003 in low output.
- Complete generated PCM buffer has no clipping and valid loop endpoints.

An environment warning, `Failed to read the root certificate store`, precedes the successful fixture and is unrelated to audio execution. No OpenXR initialization or headset access occurred.

`tests/test_audio_playback.gd` adds a muted real-backend startup fixture. Run visibly with `--xr-mode off --script tests/test_audio_playback.gd` and the normal Windows audio driver; it skips safely under headless/Dummy. It starts at exact zero gain before creating the player, checks player/source availability, bus/analyzer construction, mute fallback, pause/reset/resume, and idempotent shutdown. It allows real-time timer ticks for the audio thread to finish. A successful run checks muted startup and cleanup, not listening or spectral calibration; record the actual result before claiming this branch passed.

**Pending:** actual listening, audible loop seam assessment, output-device listening, and live spectrum calibration. Headless checks prove code/math and generated PCM bounds, not that playback was heard. Initial fixed-FPS Dummy rendered captures exposed retained WAV/playback references at engine shutdown; Dummy mode now avoids creating inaudible playback entirely. Real audio uses graceful shutdown before tree quit.

Root ran the muted visible fixture on WASAPI with `--xr-mode off`: exit 0, failures=0, no leaked-object warnings. Player/analyzer startup, zero gain, pause/reset/resume, and shutdown passed. Listening remains pending.

Official API references used: [AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html), [AudioEffectSpectrumAnalyzerInstance](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzerinstance.html). The installed engine compiled and ran the fixture.
