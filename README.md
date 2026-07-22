# Poo Sim

A mobile casual comedy game about doing your business under pressure. Each level drops you
onto a toilet in a hostile environment and challenges you to *complete the act* while managing
hazards that are actively trying to embarrass, expose, or defeat you.

- **Engine:** Godot 4.7.x (GDScript, static typing throughout)
- **Platform:** Mobile (iOS + Android), portrait
- **Model:** Premium — one flat purchase, no ads, no IAP

> **Status:** The grey-box **Push** prototype (roadmap step 1) is built and is the default
> run scene — press Play to try it. The design is fully specced (`docs/specs/`); the next
> milestone is the Vertical Slice — see [docs/specs/poo-sim-spec.md](docs/specs/poo-sim-spec.md) §14/§16.

## Getting started

1. Install **Godot 4.7.x** (standard GDScript build — *not* the .NET/C# build; see the spec's
   "Why GDScript and not C#").
2. Open the Godot project manager → **Import** → select this folder's `project.godot`.
3. Press **Play** (F5) to run the **Push** prototype: hold anywhere to raise the needle, keep
   it in the green Flow Zone to fill **Relief** to 100%, and press **R** to retry.

## Project layout

```
project.godot          Godot project config (portrait, mobile renderer)
icon.svg               App/editor icon (placeholder)
scenes/
  main/                Entry scene (placeholder)
  sit/                 The Sit — the core game (Push + four meters + hazards)
  prep/                Prep bookend
  getaway/             The Getaway bookend
  results/             Results / scoring screen
  ui/                  Shared UI (HUD, meters, prompt band, menus)
scripts/
  autoload/            Global singletons (game state, audio, routing, saves)
  systems/             Core systems (Push controller, meters, scoring, hazard scheduler)
  hazards/             One script per hazard over a shared base
data/
  levels/              Config-driven level definitions
  environments/        Per-environment tuning
  hazards/             Config-driven hazard parameters
assets/
  audio/{music,sfx,foley,voice,ambience}/
  fonts/  sprites/
docs/specs/            Full design docs + interactive HTML mockups
```

## Design docs

The design is spread across six cross-referenced specs, all in [`docs/specs/`](docs/specs/):

| Doc | Covers |
|---|---|
| [poo-sim-spec.md](docs/specs/poo-sim-spec.md) | Master design spec — pillars, loop, meters, roadmap, MVP |
| [poo-sim-ui-spec.md](docs/specs/poo-sim-ui-spec.md) | Seated-screen layout & ergonomics |
| [poo-sim-hazard-catalog.md](docs/specs/poo-sim-hazard-catalog.md) | All 14 hazards, types, and the environment matrix |
| [poo-sim-difficulty-curve.md](docs/specs/poo-sim-difficulty-curve.md) | The 20-level curriculum and star gates |
| [poo-sim-scoring.md](docs/specs/poo-sim-scoring.md) | Scoring math, star thresholds, results choreography |
| [poo-sim-sound-design.md](docs/specs/poo-sim-sound-design.md) | Full audio spec |

Interactive mockups (open the `.html` files directly in a browser):
`poo-sim-seated-screen.html`, `poo-sim-results-screen.html`, `poo-sim-sound-demo.html`.
