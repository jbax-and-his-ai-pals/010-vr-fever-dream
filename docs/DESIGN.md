# Experience design: Living Feedback Garden

Status: current direction is ethereal drift. Earlier garden interaction notes below are archived concepts; they must not reintroduce tendrils, flowers, floor grids, or visible trails. Numeric values remain tuning values.

## Intent

The visitor drifts through a bizarre fluid atmosphere: mostly empty space, with soft cloud shapes appearing at scattered locations. They are translucent three-dimensional masses that distort, dissolve as the visitor approaches, and quietly change their internal colours. The enclosing sphere carries slowly mixing swirls. There is no visible floor or destination.

Desktop is the default during visual tuning. WASD drifts horizontally, mouse looks,
Space rises, Ctrl sinks, and held mouse buttons disturb nearby shapes. Exploration
has no HUD; Escape opens controls. VR remains available through the explicit launcher.

The experience should feel like stepping inside an old music visualizer that has developed a memory. Its weirdness comes from continuous transformation and impossible materials. The visitor's viewpoint remains physically dependable.

Art direction update, October 10: this is a surreal fever dream, not a relaxation
experience. Surround the garden with an enclosing spherical skin of mixing dyes,
folded fluid currents, and subtly shifting colour. Aim for restless, uncanny
material behaviour while keeping the visitor's viewpoint dependable. Stillness
is a way to reveal a transformation, not a meditation objective.

**Promise:** “The dream notices you, and what you do becomes part of it.”

## Core experience loop

Observe a pattern → approach or gesture → notice a local response → follow the response → rediscover an earlier trace in a changed form.

There is no task checklist inside the experience. Exploration should work seated or standing, in small physical spaces, and without artificial locomotion. Traversal expands the experience but must not be required to discover all three interactions.

## First ten minutes

| Approximate time | Intended experience | What enables it |
| --- | --- | --- |
| 0:00–0:30 | A stable ground and one luminous ribbon invite inspection. | Slow fade-in; a small nearby field; optional one-line hint. |
| 0:30–2:00 | The visitor discovers that their hands bend ribbons. | A clear local displacement and gentle tone modulation. |
| 2:00–4:00 | Movement leaves a colored memory. | Traces are visible behind or beside the visitor; hand gestures also create traces. |
| 4:00–6:00 | Pausing reveals flowers emerging from the field. | A gradual stillness response, reachable from a seated position. |
| 6:00–10:00 | The palette and forms change; earlier traces become growth. | Slow mood transition and bounded trace maturation. |

These are intentions for discovery, not timed instructions or a required sequence. All interactions are available after the initial fade. Staying longer continues the dream; there is no ending gate.

## Space and visual language

- An endless navigable volume with no horizontal or vertical movement limit. Recycle sparse forms beyond their visibility range and rebase coordinates during long journeys. No visible ground grid or trail geometry.
- Sparse cloud forms: 16 at default density, 10 at low density, dispersed above and around the route with an open centre. Use softly deformed sphere geometry rather than strips or billboards.
- A 14 m radius enclosing rendering sphere follows the visitor without rotating. It is an atmosphere, never a reachable border. Its inside carries seamless fluid swirls, petrol teal, bruised magenta, and amber dye. Movement warps the surrounding flow and colour while its base animation remains slow.
- The sphere flows at approximately one sixth the earlier speed. The visitor's view stays physically dependable; free drift provides parallax through the scattered forms.
- Clouds have broad folds, feathered edges, slow dye mixing, and no detailed texture or hard glowing rim. Dissolve near the visitor rather than revealing a solid surface when passing through.
- Favour ambiguous patches of density inside the marbled surroundings. Empty space is the dominant material.
- Approach pushes cloud forms out of a personal-space envelope, changes their broad shape/dye mixing, and leaves a temporary disturbance that slowly recovers. No button is required for this response.
- Keep most movement in the middle distance; avoid sweeping geometry through the head or filling the entire view with high contrast motion.
- No photographic assets, narrative characters, legible walls of text, or menus floating throughout the garden.

## Archived garden interaction baseline

The following notes describe the earlier ribbon prototype. Current implementation
retains its typed contracts and bounded memory logic for compatibility, but replaces
the ribbon mesh/shader with cloud forms and hides trace geometry. The current direction
above takes precedence; flower and trail objectives are not current acceptance criteria.

### 1. Bend: the garden follows your hands

Each valid hand position exerts influence within 1.25 m. Nearby ribbons bend toward the hand and shift slightly toward its assigned color. Influence falls smoothly to zero at the radius edge. Release or withdrawal returns the ribbon to its resting shape over approximately 1.5 seconds.

Hand speed may add small traveling ripples, but never unbounded displacement. Cap bending at 0.6 m. A missing controller has zero influence. Ribbons are visual forms, not simulated ropes or collision obstacles.

**Discovery criterion:** an untutored visitor can identify the connection between their hand and a nearby ribbon within one minute.

### 2. Remember: movement leaves living traces

Walking and hand gestures deposit short luminous strokes in world space. Travel traces lie close to the floor; hand traces follow the gesture. Strokes soften after 20 seconds, then a selected subset sprouts a small ribbon curl around 35 seconds. All memory fades by 90 seconds.

Memory is session-local, finite, and subtle. It must never obscure the current interaction or grow infinitely. A fixed pool replaces the oldest entries when full. A seated visitor can make the same kind of persistent change using their hands.

Physical walking and optional continuous locomotion generate travel traces. Teleportation creates one arrival seed, with no connecting line. Recenter and tracking recovery create no trace. Revisited memories keep their world positions as the palette changes.

**Discovery criterion:** visitors can point to something they made, leave it, and recognize it after returning 20–40 seconds later.

### 3. Bloom: stillness changes what becomes visible

Stillness gradually opens nearby ribbon curls into abstract flowers. Use smoothed head and hand speed; ignore invalid hand poses and tracking discontinuities. Begin after approximately 3 seconds below the motion threshold, reach a full bloom around 8 seconds, and close over 2 seconds after renewed motion.

Start with a 0.08 m/s threshold and tune for natural breathing and hand tremor. Seated mode can weight head motion more heavily than hands. The effect is local to the visitor, not a camera or global world transform.

**Discovery criterion:** natural pauses produce a noticeable effect without requiring rigid stillness.

## Three moods, one material

| Mood | Palette | Shape and motion | Sound tendency |
| --- | --- | --- | --- |
| Silk | Indigo, cyan, pale lilac | Long arcs; slow, broad waves | Spacious sustained tones |
| Coral | Violet, peach, amber | Curls and branching accents | Gentle rhythmic pulses |
| Aurora | Teal, rose, warm white | Taller streams and fine ripples | Airy upper textures |

Start in Silk. After a 90-second dwell, blend toward the next mood over 30 seconds. Repeat the cycle without scene cuts or relocations. Audio can animate each mood but does not control the progression. Memories retain their geometry and interpolate their colors.

Mood changes alter deformation, palette, and ambient sound parameters. They do not replace the whole scene, reposition the camera, or rebuild all geometry every frame.

## Sound and music response

Use one original or appropriately licensed ambient loop for the prototype. No microphone, streaming-service connection, or audio import interface in v0.

- Low-band energy gently swells ribbon width, at most about 15%.
- Mid-band energy adds traveling ripples.
- High-band energy raises small accent brightness; no flashes or strobes.
- Apply smoothing so isolated transients do not jerk the field.
- Keep hand response immediate enough to distinguish it from music response.
- Sound is optional: silent mode retains all three interactions and a subtle synthetic ambient rhythm.

Audio modulation and interaction displacement have separate bounded contributions. Loud music cannot eliminate the visitor's influence.

## Navigation and controls

Desktop preview: WASD movement, mouse look while captured, mouse buttons for simulated hands, and keys for moving the simulated hands closer/farther. Escape releases the cursor and opens settings. The preview demonstrates behavior; it is not evidence of VR comfort.

VR: tracked head and controllers, physical movement, teleport by default, and discrete 30-degree snap turn. Continuous movement is an optional later setting with a starting speed cap of 1 m/s. No automatic forward motion, forced camera bob, camera roll, or camera shake.

Teleport destinations must remain on the garden floor and inside its usable boundary. A visible target marker communicates validity. Leave a short quiet interval after arriving before sampling motion again. Always preserve tracked head movement; move or rotate the player origin for artificial locomotion.

Provide a compact settings surface for sound volume, visual intensity, seated mode, locomotion, reset dream, and exit. Default visual intensity is moderate. “Reset dream” clears traces, restores Silk, and returns to the start through a fade; it must not reinterpret ordinary headset recentering as a reset.

## Prototype scope

**Required:** one garden; bend/remember/bloom; three moods; desktop preview; OpenXR rig; teleport/snap turn; ambient sound response; session reset; intensity settings; bounded resources; hardware playtest.

**Deferred:** standalone export, custom music files, complex hand gestures, hand tracking, room scanning, multiplayer, persistent save files, generative AI, procedural worlds, objectives, achievements, editor tooling, and additional biomes.

## Experience acceptance

For the vertical slice, playtest with three people if available. Record observations rather than inventing results. The prototype succeeds if at least two discover hand bending without coaching, recognize a trace they made, and notice bloom during a natural pause in a ten-minute session.

Ask afterward: “What did you feel you could change?”, “What made you want to stay?”, and “Was any motion or brightness unpleasant?” If the interactions are unclear, improve their local feedback before adding content. A hardware release gate separately verifies frame pacing, tracking, and navigation on the selected headset.

## Design risks and responses

| Risk | First response |
| --- | --- |
| Everything looks busy, so nothing feels caused by the visitor. | Reduce ambient motion and increase local interaction contrast. |
| It looks like a screensaver mapped onto an empty room. | Add nearby forms, depth layers, and persistent visitor traces. |
| Stillness feels like a chore. | Relax thresholds and let ordinary pauses trigger a partial bloom. |
| Memory overwhelms the field. | Shorten retention or lower the pool cap; do not add cleanup tasks for the visitor. |
| Performance limits spoil the experience. | Reduce overlapping transparent surfaces and field density before adding effects. |
| Traversal dominates the design. | Make every core interaction available from spawn before expanding the garden. |
