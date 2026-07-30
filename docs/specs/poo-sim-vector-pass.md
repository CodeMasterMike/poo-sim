# Poo Sim — Prototype Vector Pass (WORK IN PROGRESS)

*Resume doc. Companion to the [UI spec](poo-sim-ui-spec.md) and the [style guide](poo-sim-style-guide.html). Version 0.1 — the pass is not yet built.*

## Status — where this left off

- ✅ **Target drafted:** [poo-sim-vector-mockup.svg](poo-sim-vector-mockup.svg) — an SVG mockup of the upgraded seated screen, laid out to mirror `push_prototype.gd`'s exact geometry, in the locked `Palette` colours.
- ⚠️ **Not visually verified.** The Godot editor MCP was disconnected this session, so the running game couldn't be screenshotted; the Browser pane also can't screenshot files it renders as static snapshots. The mockup is well-formed SVG but should be eyeballed before porting.
- ❌ **Godot port not started.** No changes made to `push_prototype.gd` for this pass.

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

## Functions to modify in `scripts/systems/push_prototype.gd`

- `_draw()` — add the background gradient/vignette/floor before the existing content.
- `_draw_gauge()` — rounded housing + bands, flow glow, the new needle.
- `_draw_relief()` — rounded tube, gradient fill, gloss, goal marker.
- `_draw_meters_top()` / `_pill()` — rounded bars/pills with gloss.
- Add helpers `_rrect()` and `_vgrad()`.

## Verifying

- **Preferred — with the Godot MCP reconnected** (reconnect via `/mcp` in an interactive `claude`, then `filesystem_manage scan` → `project_run` → `editor_screenshot`): iterate the real render against the mockup.
- **Fallback — headless CLI** (used this session while MCP was down): parse-check with
  `"C:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path C:\Projects\poo-sim-dev --quit-after 3`
  (catches load/parse errors; regenerate the class cache with `--editor --quit` first if a new `class_name` was added). Then have the user F5 to eyeball it.
