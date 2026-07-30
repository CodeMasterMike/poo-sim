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
