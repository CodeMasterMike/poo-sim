# Poo Sim — Prototype Vector Pass (DONE)

*Companion to the [UI spec](poo-sim-ui-spec.md) and the [style guide](poo-sim-style-guide.html). Version 1.0 — the pass is built and verified in the running game.*

## Status

- ✅ **Target drafted:** [poo-sim-vector-mockup.svg](poo-sim-vector-mockup.svg) — an SVG mockup of the upgraded seated screen, laid out to mirror `push_prototype.gd`'s exact geometry, in the locked `Palette` colours.
- ✅ **Ported to Godot.** All four scope items landed in `scripts/systems/push_prototype.gd`. Geometry and behaviour are unchanged — only the painting.
- ✅ **Visually verified** against the running game via the Godot MCP (`project_run` → `editor_screenshot source=game`), driving states with `editor_manage game_eval`. Checked: dead / flow / red zones, the flow glow, near-empty meters and a 0.6% relief tube (the degenerate-size guards), the Church cover bar, and the win overlay. No new script warnings.

### Divergences from the mockup, and why

- **The needle stays inside the gauge housing.** The first port let the halo spread to `gw * 0.34` either side; on the real backdrop that read as a green smear rather than a glow. It now matches the mockup, which keeps the needle and its glow within the housing bounds.
- **Recessed surfaces are `PANEL`-derived, not `BG`-derived.** `BG.darkened()` made the relief tube and meter tracks read as holes punched in the screen. The mockup's `#20242d` / `#191d24` are *lighter* than `BG`, so they come from `PANEL.darkened()` instead.
- **The quiet-status bar and prompt band were rounded too.** Not in the original scope list, but they sit in the same HUD layer — leaving two flat rects among rounded ones looked broken.
- **The top-left LEVEL button and the `?` button are untouched.** They're drawn by `LevelPicker` / `ManualOverlay`, not this view. The mockup draws `?` as a circle; in game it's still a rounded square.

### Known issue, not introduced here

On quiet-room levels (Church / Rave) the cover-status bar at `h * 0.165` collides with the `THE PUSH` / `RELIEF` column labels at `gy - h * 0.018`. Pre-existing; a layout fix, not a rendering one.

## Goal

Turn the grey-box procedural rendering in `push_prototype.gd` `_draw()` into **intentional vector art**, now that every colour pulls from `Palette` (`scripts/ui/palette.gd`). **Keep all geometry and behaviour identical** — this is a pure rendering upgrade, so it's low-risk and needs no sim/interaction changes.

## Scope (this pass — the mechanical UI)

1. **Background** — a subtle vertical gradient (lighter navy top → `BG` → darker bottom), a soft vignette, and a faint floor line. No more flat void.
2. **Composure bar + Discretion/Cleanliness pills** — rounded, inset tracks, a gloss highlight on the fill; keep the `_meter_color()` states.
3. **The Force gauge** (the signature, per UI spec) — rounded housing; rounded dead/flow/red zone bands; a soft green glow around the flow band; a **chunky, glowing needle** with a rounded cap.
4. **The Relief tube** — rounded, a green **gradient fill** with a gloss highlight, a clear gold goal marker.

## Out of scope (a later "scene art" pass)

Character / toilet / environment illustration and hazard-actor art (door, neighbour shadow, smell cloud, phone). Those want raster/illustration work and can't be done blind — see the component checklist in the [UI spec](poo-sim-ui-spec.md) §Component/asset checklist. This pass is only the HUD/gauge/meter vector layer.

### Superseded: a first slice of scene art landed anyway

The "can't be done blind" reasoning stopped applying once the Godot MCP was reconnected, so a first pass of scene art followed immediately: a tiled cubicle backdrop and a seated figure on a toilet, both procedural. See **The sitter** below. Hazard-actor art is still untouched.

## The sitter (`_draw_room()` / `_draw_sitter()`)

This is the game's only representational art, and it is deliberately in the **other register** — style guide §1 splits the game into *A · Chunky Cartoon* for the world and *B · Deadpan Technical* for the framing. So the sitter follows §5 strictly: flat fills, exactly one shadow tone, thick ink outlines at ~0.5% of screen width, and **no gradients** — the opposite of the glossy HUD it sits behind. That contrast is the joke, not an inconsistency.

Three constraints drove the design, and they're worth knowing before anyone "improves" it:

- **He is a silhouette, not a coloured character.** §6 forbids repurposing the semantic colours as decoration, and every warm hue in the palette (`AMBER`, `ORANGE`, `RED`, `GOAL`) already means something load-bearing. Skin tones would either steal a semantic colour or introduce an off-palette one, so he is built from the neutral surface tones and reads as a shape.
- **He is front-on, not in profile.** He lives in the gap between the gauge and the relief tube, which is only about `w * 0.166` wide. A side view needs room for knees and a cistern in a line and was unreadable at that width; front-on he is barely wider than his own shoulders and the columns frame him instead of burying him.
- **The bowl is wider than his hips and the cistern wider than his shoulders.** That overhang is the entire reason the pose reads as *on a toilet* rather than *standing about*. The first attempt hid the toilet completely behind him and read as a man in front of a grey box.

The room is at the edge of legibility on purpose — pillar 2 and §6 both say the meters win every contrast fight, so the tiling is `BORDER` at `a = 0.16`.

`FLOOR_Y` (0.69) is the shared ground plane, set level with the bottom of the two columns so the whole HUD stands on the same floor. It replaced the earlier decorative floor line at 0.80, which sat below the columns and grounded nothing. Everything under `FLOOR_Y` is HUD apron: column values, prompt band, footers.

### Poses

Three, all view-only — read off the input buffer and the phase, never fed back into the sim:

| State | Pose |
|---|---|
| Idle | a slow breathing bob |
| `_holding_now()` | hunched forward, head down |
| `Phase.LOST` | slumped — head dropped furthest and lolled off-centre, shoulders less, hips not at all, arms off the knees and hanging |

The slump curves rather than translates on purpose: dropping every joint by the same amount just reads as a shorter man. Beaten posture is a curve.

On the fail screen he is **re-drawn on top of the scrim**. Behind an `a = 0.80` wash of black the slump is invisible, and the beat is worth more than the dimming. The "tap · press R to retry" line moved from `h * 0.55` to `h * 0.76` to clear his head — at 0.55 it ran straight through it.

### The bowl is the Relief meter (`_draw_bowl()` / `_draw_deposits()`)

The abstract green Relief tube is gone. The bowl replaced it, and the layout moved to make room: **THE PUSH** went hard against the left edge (it's only ever read for the needle's *height*, so it gives up width cheaply) and the man and bowl took the rest.

What's in the bowl is what you produced. One layer per `100/DEPOSITS` of Relief, each layer as wide as the needle was **at the moment it came out** — so a clean run builds an even column and a run spent bouncing off the red zone builds a lumpy mess. The bowl is the meter and the record of the run at the same time.

**Nothing here calls `randf()`, and that's load-bearing.** Every value is a pure function of `(layer index, match_seed)` or of the width sampled when the layer was laid down. Two independent reasons:

- `_draw()` re-runs every frame. Live randomness would make the whole pile crawl and shimmer instead of sitting there.
- A seeded replay — and the ghost/1v1 architecture the sim is built to allow — has to redraw the identical pile. Live randomness breaks that.

The sampling happens in `_process()`, not `_draw()`, because the needle has to be read at the instant the layer is produced and `_draw()` must stay a pure function of state. `_deposits` is view state, but it's still deterministic, because Relief is.

`DEPOSITS` is deliberately low (30). Finer layers are a truer record but render as thin stacked planks; the chunkier the layer, the more it reads as a lump.

Four colours were added to `Palette` — `MATTER`, `MATTER_DARK`, `MATTER_LIT`, `WATER` — rather than inlined as `Color()` literals, per the palette's own no-drift rule. They're documented in the style guide under a new *Representational* heading: they depict a thing rather than signal a state, and sit outside the §3 colour grammar entirely.

### How gross, exactly

The product is the **one sanctioned carve-out** from §6's "sell the gross-out with comedy & audio, not the visuals" and from the two-tone rule, recorded as such in the style guide. It earns a third tone because the wet sheen is the whole difference between something that reads as fresh and a brown shape.

What makes it read as matter rather than as a stack of planks:

- **Two or three overlapping lobes per layer**, not one capsule. The irregular silhouette does most of the work.
- **Sheen on roughly half the lobes only, and small.** A highlight on every lobe at a consistent size stripes the pile and it starts to read as flaky pastry — that was the first attempt.
- **Tone varies per lobe** between `MATTER` and `MATTER_DARK`.
- **The water goes off as the bowl fills**, lerping toward `MATTER_DARK` with Relief.
- **Skid marks down the porcelain, driven by Cleanliness.** No new state: Cleanliness already tracks how much you splashed, so the bowl simply wears it. The mess *is* the score, drawn.
- **Splatter on the rim during a splash**, the transient moment whose permanent record is those streaks.

Lobes are drawn with `_limb()`, not `_rrect()` — it round-caps a bar in three primitive draws with no `StyleBoxFlat` allocation, which matters at ~90 lobes a frame. Measured at 59 FPS / 763 draw calls with a full bowl.

The carve-out buys no licence toward photorealism: the shapes stay flat-filled, thickly outlined cartoon lobes. Everything around them stays in register — a flat, earnest instrument panel reporting on something horrible is the §1 joke, and it only works if the panel keeps a straight face.

### The HUD went back to flat

The meters, gauge bands, needle highlight and prompt band briefly carried gradient fills and gloss slivers. That was a deviation from §5 — which is explicit that gradients are juice only and never structural — and it has been reverted.

Rounded corners stay; §5 sets a radius scale and puts meters at `height/2`. What went is the emboss: an embossed bar reads as a glossy app widget, which is register A's job to be fun and register B's job to refuse. Glow survives only where §5 permits it as juice — the flow-zone pulse, the milestone flash, the needle's halo. `_lit_band()` was deleted outright; it existed only to add the gradient and gloss.

### What the man's pose had to give up

The bowl is drawn as a cutaway across his lap, so it honestly occludes his legs — and the legs kept fighting it:

- **Thighs spread over the rim** read as a shelf he was sitting behind, and covered the gold goal line.
- **Knees as discs beside the basin** read as wheels.
- **Knees hung off the hands** merged hand and knee into one lump and made the whole arm read as a scarecrow's.

Torso, head, arms, hands resting on the rim. That's it. The bowl is doing the work of saying "seated".

### Shading him: a rim, not a blob (`_shade_limbs()`)

The §5 "one shadow tone" is applied by painting the **whole** figure in the shadow tone and then putting the lit colour back on top, shrunk and shifted up-and-right. That leaves a shadow rim thickest on the lower-left of every limb.

The first attempt hand-placed two shadow blobs, offset inside the torso and the head. On a torso only `w * 0.144` wide the strip covered half of it and read as a panel down his front rather than as light coming from anywhere.

Both the shrink and the offset are **proportional to each limb's own radius**. A fixed offset is fine on the torso and pushes the lit core straight out through the outline on something as thin as a forearm.

### The toilet needs a neck

The cistern and the bowl were originally positioned independently — the cistern sized to frame his head, the bowl to fit the layout — and nothing joined them, so the tank floated with roughly `h * 0.16` of empty background between it and the bowl.

`_draw_sitter()` now draws a narrower back column from under the cistern down past the bowl's top edge. It runs behind his torso, which is where the back of a toilet actually is, and it has to overlap the bowl rather than just meet it, or the seam shows.

### Stink lines (`_draw_stink()`)

§5 names the squiggle as the sanctioned comedic flourish, so the Smell hazard gets one: three wavering lines rising out of the sitter through the clear gap above him, faint and slow while the cloud is drifting in, bright and fast once it's on you — the same telegraph → active read the prompt band and the gauge already use.

Two details that make them work: the wobble is scaled by height so the lines stay anchored at the base and only writhe as they rise, and they fade out toward the tip via `draw_polyline_colors` — a squiggle that simply stops looks cut off. Four lines, two either side of him: he's centred now, so a centre squiggle would just run up his chest.

## Godot `_draw()` techniques for the port

The view draws procedurally, so translate the mockup with these:

- **Rounded rects** → `StyleBoxFlat` + `draw_style_box(sb, rect)`. Create a **fresh** `StyleBoxFlat` per element (don't reuse+mutate one — draw commands may resolve it late). Set `bg_color`, `set_corner_radius_all()`, and `border_color`/`set_border_width_all()` for outlines. Add a helper `_rrect(rect, color, radius, border_col, border_w)`.
- **Vertical gradients** (relief fill, background, gloss) → `draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))` (per-vertex colours; sharp corners, so inset it inside a rounded housing). Add a helper `_vgrad(rect, top, bottom)`.
- **Glows / gloss** → layered translucent rects/circles (no blur exists in draw calls). A wide low-alpha `FLOW` rect behind the needle/flow band; a thin bright highlight rect near the top edge of a fill for gloss.
- **Needle** → glow rect (alpha `FLOW`) + white rounded body (`_rrect` in `NEEDLE`) + a bright highlight line + a `draw_circle` cap outlined in `FLOW`.
- **Colours** → all from the aliased `Palette` tokens already in the view (`BG`, `PANEL`, `DEAD`, `FLOW`, `FLOW_DIM`, `RED`, `RED_DIM`, `AMBER`, `GOAL`, `NEEDLE`, `TEXT`, `TEXT_DIM`, `BORDER` via `Palette.BORDER`).

Keep the existing geometry constants (`gx/gw/gy/gh`, relief `rx/rw`, meter positions) **unchanged** — only the *painting* changes.

## What changed in `scripts/systems/push_prototype.gd`

- `_draw()` — now opens with `_draw_backdrop()` instead of a flat `draw_rect`.
- `_draw_backdrop()` *(new)* — vertical wash, stacked-frame vignette, two-pass floor line.
- `_draw_gauge()` — rounded housing + track, lit bands, two-pass flow glow, the new needle.
- `_draw_relief()` — rounded tube, gradient fill, gloss, gold goal capsule with a halo.
- `_draw_meters_top()` / `_pill()` — both delegate to the new `_track()`.
- `_track()` *(new)* — the shared inset/rounded/glossy meter, still coloured by `_meter_color()`.
- `_draw_quiet_status()` / `_draw_prompt()` — rounded with a gloss sliver.
- Primitives *(new)*: `_rrect()`, `_vgrad()`, `_lit_band()`; `_band()` gained a `radius`.

Two things bit during the port and are worth remembering:

- **`_vgrad()` corners are sharp.** Always inset it inside a rounded housing, far enough that the inset corner falls within the housing's corner circle, or you get visible square shoulders.
- **Glows need ≥ 4 passes.** With hard-edged rects, two translucent layers read as stacked lozenges, not a falloff. Keep the glow inside its housing, too — spilling onto the backdrop reads as a smear.

## Verifying

- **Preferred — via the Godot MCP:** `filesystem_manage scan` → `project_run` → `editor_screenshot source=game max_resolution=0`. Drive states with `editor_manage game_eval`; the view lives at `/root/PushPrototype`. To freeze a frame for inspection: set the fields, `await get_tree().process_frame`, then `get_tree().paused = true`.
  - Setting `relief` directly re-triggers the milestone flash, which paints the whole tube white — set `_next_milestone = 100` and `_milestone_flash = 0.0` alongside it.
- **Fallback — headless CLI** (if the MCP is down): parse-check with
  `"C:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path C:\Projects\poo-sim-dev --quit-after 3`
  (catches load/parse errors; regenerate the class cache with `--editor --quit` first if a new `class_name` was added). Then have the user F5 to eyeball it.
