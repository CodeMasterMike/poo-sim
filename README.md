# Poo Sim

A mobile casual comedy game about doing your business under pressure. Each level drops you
onto a toilet in a hostile environment and challenges you to *complete the act* while managing
hazards that are actively trying to embarrass, expose, or defeat you.

- **Engine:** Godot 4.7.x (GDScript, static typing throughout)
- **Platform:** Mobile (iOS + Android), portrait
- **Model:** Premium — one flat purchase, no ads, no IAP

> **Status:** The **Push** prototype (roadmap step 1) is built and is the default run scene —
> press Play to try it. The HUD has had a vector-art pass, and the seated screen is now a scene:
> a tiled cubicle, a man on a toilet, and a bowl that fills with what you produced. Relief is no
> longer an abstract bar — it is mass evacuated into the bowl, which the sim settles as a
> heightfield every tick, so what you produced has a *consistency* and a *shape*. Runny slumps
> into a flat pool; firm holds a mound. The run ends when the pile reaches the goal line, so how
> you played decides how much it takes. Three venues ship (Prototype, Church, Rave) over five
> live hazards. Hazard actors (door, neighbour shadow, phone) are still placeholder shapes. The
> design is fully specced (`docs/specs/`); the next milestone is the Vertical Slice —
> see [docs/specs/poo-sim-spec.md](docs/specs/poo-sim-spec.md) §14/§16.

## Getting started

1. Install **Godot 4.7.x** (standard GDScript build — *not* the .NET/C# build; see the spec's
   "Why GDScript and not C#").
2. Open the Godot project manager → **Import** → select this folder's `project.godot`.
3. Press **Play** (F5) to run the **Push** prototype: hold anywhere to raise the needle, keep it
   in the green Flow Zone to fill the bowl, and press **R** to retry. **H** opens the in-game
   field manual; **1/2/3** switch venue.

## Project layout

The load-bearing split is `scripts/sim/` versus everything else. The sim is engine-pure,
deterministic and seeded — it holds no `Node` references and never reads live input — so the same
core can later drive a ghost replay or a mirrored 1v1 board. The view only ever *reads* `SimState`.
See §17 of the master spec for the five guardrails that keep it that way.

```
project.godot          Godot project config (portrait, mobile renderer)
icon.svg               App/editor icon (placeholder)
scenes/
  sit/                 The Sit — the core game, and the default run scene
  main/                Entry scene (scaffolded, not yet built)
  prep/ getaway/       Bookend scenes (scaffolded, not yet built)
  results/ ui/         Results screen and shared UI (scaffolded, not yet built)
scripts/
  sim/                 THE SIMULATION — deterministic, seeded, engine-pure.
                       Tick order, tuning schema, scoring, the event timeline.
    hazards/           One stateless operator per hazard, over a shared HazardSlot
  content/             Level factories — timelines and per-venue tuning. Content only.
  systems/             The Sit's view + controller (input, fixed-step driver, _draw)
  ui/                  Overlays and the locked palette
  debug/               The auto-player (a scripted "competent human", toggle with B)
  autoload/            Global singletons (scaffolded, not yet built)
tests/                 GDScript suites — run them from the Godot AI dock or MCP
data/
  levels/              base_tuning.tres — the shared tuning every venue is built from
  environments/        Per-environment tuning (scaffolded)
  hazards/             Config-driven hazard parameters (scaffolded)
assets/
  audio/{music,sfx,foley,voice,ambience}/
  fonts/  sprites/
docs/specs/            Full design docs + interactive HTML mockups
```

## Design docs

The design is spread across nine cross-referenced specs, all in [`docs/specs/`](docs/specs/):

| Doc | Covers |
|---|---|
| [poo-sim-spec.md](docs/specs/poo-sim-spec.md) | Master design spec — pillars, loop, meters, roadmap, MVP |
| [poo-sim-ui-spec.md](docs/specs/poo-sim-ui-spec.md) | Seated-screen layout & ergonomics |
| [poo-sim-hazard-catalog.md](docs/specs/poo-sim-hazard-catalog.md) | All 15 hazards, types, and the environment matrix |
| [poo-sim-difficulty-curve.md](docs/specs/poo-sim-difficulty-curve.md) | The 20-level curriculum and star gates |
| [poo-sim-environments.md](docs/specs/poo-sim-environments.md) | Environment backlog — the rule each venue breaks |
| [poo-sim-scoring.md](docs/specs/poo-sim-scoring.md) | Scoring math, star thresholds, results choreography |
| [poo-sim-sound-design.md](docs/specs/poo-sim-sound-design.md) | Full audio spec |
| [poo-sim-style-guide.html](docs/specs/poo-sim-style-guide.html) | Locked palette, type, shape & tone — the art bible |
| [poo-sim-vector-pass.md](docs/specs/poo-sim-vector-pass.md) | The HUD vector-art pass — what shipped, and the `_draw()` techniques behind it |

Interactive mockups (open the `.html` files directly in a browser):
`poo-sim-seated-screen.html`, `poo-sim-results-screen.html`, `poo-sim-sound-demo.html`.
The vector pass's target render is `poo-sim-vector-mockup.svg`.
