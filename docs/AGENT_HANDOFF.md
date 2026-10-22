# Agent handoff guide

Use this file when assigning future implementation work. Each agent gets one task packet, explicit owned paths, and the contracts established by completed dependencies. Do not ask a small agent to interpret the entire roadmap as one coding task.

## Assignment template

```text
Implement task [Txx and title] from docs/ROADMAP.md.

Read README.md, docs/DESIGN.md, docs/TECHNICAL.md, and your task packet.
Inspect applicable repository instructions and existing code before editing.
Dependencies [IDs] have passed; their validation evidence is [paths].
Your owned files are [exact paths]. Other agents may be working elsewhere.

Preserve the experience scope and shared typed interfaces. Implement only
this packet and necessary fixes within its owned files. If an interface
change or another owner's edit is necessary, report it to the integrator
before making that change. Do not overwrite unrelated work.

Use the supplied Godot 4.7.2 console executable for import and meaningful
headless checks. Run the packet's visual/hardware checks where available.
If a check cannot run, explain why and leave it pending. Do not infer a
visual, audio, comfort, or headset pass from a successful headless import.

Deliver: changed files, behavior achieved, actual validation commands and
results, manual observations, remaining limits, and any contract proposals.
Update the assigned task's status and add evidence under docs/validation/.
Do not install dependencies, export for another platform, publish, or expand
the mechanics as a substitute for completing this packet.
```

## Integrator responsibilities

- Own shared project settings, root scene, contract changes, and gate decisions.
- Confirm dependency evidence before dispatching a packet.
- Freeze shared interfaces before independent audio/state/visual work.
- Prevent concurrent agents from editing the same scene, resource, or script.
- Integrate narrow changes sequentially and rerun checks affected by them.
- Preserve the user-selected engine and the one-garden prototype scope.
- Escalate hardware/platform decisions only when they become blocking.

Godot scene/resource files can create broad diffs. Give one agent ownership of each `.tscn` or shared `.tres`; do not assume separate child nodes make concurrent edits safe. Keep generated `.godot/` cache out of handoff artifacts and version control if Git is later initialized.

## Evidence format

```text
Task:
Status: not started / in progress / ready for integration / passed / blocked
Source snapshot or commit:
Engine and launch mode:
Changed files:
Checks run and exact outcomes:
Manual observations:
Hardware/runtime/renderer, if relevant:
Checks pending and reason:
Contract changes proposed:
Next dependent task:
```

“Passed” means packet acceptance is satisfied and the integrator has accepted it. “Blocked” describes a concrete missing dependency, device, or decision; it does not hide unfinished ordinary implementation work.

## Suggested first assignment

T01–T09 are implemented; review current ROADMAP.md status and validation before assigning anything. Next useful work is feel review, then T10 hardware profiling and T11 human discovery review when arranged. Reuse the connected XR startup, rig, navigation, and world settings. **Desktop is now the default for the user's Godot Play button; preserve `openxr/enabled=false`. Every agent-run Godot command, including editor import, must explicitly pass `--xr-mode off`, and runnable tests must append `-- --desktop` (or add `--desktop` after an existing user-argument separator).** Prefer Validate-Desktop.ps1, which supplies both. Do not execute Launch-VR.ps1 or initialize XR during testing: headset startup causes a modal the user may be unable to dismiss. Use the explicit VR launcher only for user-arranged hardware runs. Headset-free fixtures use injected providers, synthetic poses, and ordinary Camera3D rendering. Keep hardware checks pending until the user explicitly arranges them.

