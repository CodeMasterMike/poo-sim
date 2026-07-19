# Poo Sim — Game Design Spec

*Version 0.1 — living document. Everything here is a starting point meant to be argued with.*

---

## 1. Overview

**Poo Sim** is a mobile casual comedy game about doing your business under pressure. Each level drops the player onto a toilet in a hostile environment — a festival porta-potty, a work bathroom two feet from your boss, an airplane lav in turbulence — and challenges them to *complete the act* while managing hazards that are actively trying to embarrass, expose, or defeat them.

The joke and the game are the same thing: everyone knows the specific dread of a bad bathroom situation, and Poo Sim turns that dread into a tense, funny, 60-second skill test.

| | |
|---|---|
| **Genre** | Casual skill / minigame, comedy |
| **Platform** | Mobile (iOS + Android), portrait orientation |
| **Session length** | 30–90 seconds per level; pick-up-and-play |
| **Tone** | Full gross-out crude, delivered with a completely straight face — "a surprisingly serious bathroom simulator" |
| **Audience** | 16+ comedy-casual players; the "Goat Simulator / I Am Bread / Getting Over It" crowd, but bite-sized |
| **Engine** | Godot 4.7.x, scripted in GDScript (free, strong 2D, no revenue cut) |
| **Business model (proposed)** | Premium — one-time flat purchase, no ads, no IAP |

---

## 2. Design Pillars

1. **The tension is in the sitting.** The drama lives once you're seated. We never make the player hunt for a bathroom — no map, no traversal. Prep and Exit exist only as short bookends that feed the sit.
2. **Gross but readable.** It's crude and loud, but every hazard and meter must be instantly legible at a glance on a phone. Chaos in flavor, clarity in mechanics.
3. **Fail funny.** Losing should be as entertaining as winning. Every failure state is a comedic set-piece, not a dry "Game Over."
4. **One more sit.** Levels are short, restarts are instant, and the star system nags you to come back and clean up that 2-star run.
5. **Depth without homework.** Enough complexity to stay interesting, never enough to feel like work. See the Complexity Budget below — it's a hard filter on every future addition.

### The Complexity Budget

This is a casual mobile comedy game played in short bursts. Cognitive load is a finite resource, and feature creep is the main threat to it. Every addition must pass all five:

1. **Recognition, not calculation.** The player reads the room and reacts. They should never be doing arithmetic or optimizing a build.
2. **One decision at a time.** No phase asks for two simultaneous judgment calls.
3. **No new meters.** The four meters are the whole vocabulary. New content plugs into them or it doesn't ship.
4. **Skippable.** Any layer beyond the core sit can be bypassed with one tap by a player who just wants to play.
5. **Explainable in one sentence.** If a mechanic needs a paragraph, it's cut or simplified.

When in doubt, cut. The core sit is the game; everything else is seasoning.

---

## 3. Core Gameplay Loop

Each level is a single "sitting," bookended by two short beats. **The Sit is 80% of the runtime** — the bookends are seasoning, and the time budget enforces that.

| Phase | Budget | What happens |
|---|---|---|
| **Setup** | 2–3s | Title card: scene + win condition. |
| **① Prep** | 5–8s | Choose up to **2** quick actions to soften the sit — or tap **JUST GO** to skip. |
| **② The Sit** | 45–75s | The core game. Manage **The Push** to fill **Relief** to 100% while handling hazards. |
| **③ The Getaway** | 3–5s | Discretion comes due. One choice: wash or bolt. |
| **Payoff** | — | Star rating, comedic outro, retry or advance. |

Total target: **~60–90 seconds.** If a level regularly runs past 90s, cut something.

### ① Prep — "the time you spend costs you"

The dilemma in one line: **prep time is deducted from your Composure.** Every second spent preparing is a second of clock you won't have during the sit. Prep makes the act easier but starts you tighter.

- Only **2–3 options** are offered per level, and they're always keyed to what's visibly wrong with the room — you're reading the room, not optimizing a loadout.
- Cap of **2 selections.** You can't cover everything; pick your poison.
- **JUST GO** skips the whole phase in one tap and starts you with full Composure.

| Prep action | Effect |
|---|---|
| **Check the paper** | Reveals whether TP is present, defusing (or forewarning) Empty Roll. |
| **Check the lock** | Reduces Broken Latch drift / softens The Knock. |
| **Clean the seat** | Raises starting Cleanliness. |
| **Sound cover** (hand dryer, unspool paper) | Buffers Discretion for part of the sit. |
| **Brace / posture** | Widens the Flow Zone. |

**Why "check the paper" matters most:** it converts Empty Roll from a random gotcha into a self-inflicted mistake. Players forgive a punishment they had the chance to avoid; they resent a random one. Prep exists mostly to make the sit's hazards feel *fair*.

### ③ The Getaway — "Discretion comes due"

The exit is a **reversal, not a chore** — short, and able to move your star rating, so it carries stakes instead of deflating the win.

Its main job: **resolve Discretion.** Everything you did in the stall now determines who's waiting and how they react — a knowing look, a slow clap, a phone already filming. Discretion stops being an abstract score and becomes a punchline.

Then exactly one input: **wash your hands** (costs seconds, protects your rating) or **bolt** (saves time, you get judged). A comedic moral micro-choice, on-brand for the deadpan tone.

Everything else in the exit is watched, not played. No wiping minigame — that's where crude tips from funny into tedious.

---

## 4. Core Mechanic — "The Push"

The single primary control. Everything else is a modifier on top of it.

- A vertical **Force gauge** sits on screen with a moving needle. **Hold anywhere on screen** to push; the needle rises. Release to relax; it falls.
- A green **Flow Zone** occupies a band of the gauge. **Keeping the needle in the Flow Zone fills the Relief Meter** at the ideal rate.
- Push **too hard** (needle in the red): fills Relief faster *but* spikes **Noise** and risks **Splashback** (Cleanliness damage). This is the greedy/risky play.
- Push **too soft** (needle low): Relief barely fills, **Composure** drains, and hazards get more time to escalate.

The Flow Zone can shift, narrow, or split during a level (e.g., a "false alarm" fake-out, or a stubborn stretch that demands a hard push). That's the skill ceiling.

> **See the [UI Spec](poo-sim-ui-spec.md)** for the full seated-screen layout, and the interactive mockup **`poo-sim-seated-screen.html`** to see the gauge, meters, and hazard states in action.

---

## 5. The Meters (Core Systems)

Four meters define every level. Tuning their weights per-environment is how we make a porta-potty feel different from a first-class lounge.

| Meter | What it does | Player wants it… |
|---|---|---|
| **Relief** | Win condition. Fill to 100% to complete the act. | **Full** |
| **Composure** | Time/urgency. Ticks down; empties = you lose it (panic fail). | **High** |
| **Discretion** | Noise + Smell combined. If detected, level-specific consequence fires. | **High** |
| **Cleanliness** | Splashback, clogging, mess. Tanks your star rating; can hard-fail. | **High** |

**Discretion** deserves a note: crossing the detection threshold doesn't always end the run — it triggers the environment's signature consequence (boss recognizes your shoes; the festival line starts filming; the flight attendant knocks). Some are soft penalties, some are instant fails.

---

## 6. Hazards

Hazards are timed interrupt events layered on top of The Push. They demand a quick, distinct reaction so the player can't just zone out on the hold button.

- **The Knock** — someone raps on the door/stall. Release The Push and "hold still" for a beat, or Discretion craters.
- **Jolt** — turbulence, a wobbling porta-potty, a passing truck. The needle gets knocked; re-center fast.
- **Empty Roll** — you discover there's no TP. A mid-level micro-decision (improvise, ration, or ride it out) affecting end Cleanliness.
- **The Buzz** — your phone lights up. Tap to dismiss or get distracted (Composure drain). Doomscrolling is a vice.
- **The Waiter** — a line/person outside grows impatient. A visible external timer separate from Composure.
- **The Neighbor** — an adjacent stall occupant reacts to your Noise in real time. Pure comedic pressure.

Each environment ships with 2–3 signature hazards; difficulty scales by stacking and speeding them up.

> **See the companion [Hazard Catalog](poo-sim-hazard-catalog.md)** for the full set (14 hazards), each with trigger, reaction, meter effects, scaling, and an environment matrix.

---

## 7. Loadout (Pre-Level Consumables)

Before a sitting, the player equips up to N consumables — the light strategy/collection layer and a reward sink for in-game currency.

- **Fiber Gummies** — widen the Flow Zone (more forgiving Push).
- **Noise-Cancelling Headphones** — dampen the Noise contribution to Discretion.
- **Travel Air Freshener** — buffer the Smell contribution to Discretion.
- **Premium 3-Ply** — Cleanliness insurance; softens Splashback.
- **Energy Shot** — slows Composure drain.

Consumables are single-use and earned through play. They tune difficulty *and* give players a way to brute-force a tough level. Since there's no store, the earn/spend economy is a self-contained crafting or reward loop we'll design in the content phase.

---

## 8. Scoring & Star Rating

At resolution, score a weighted blend:

- **Relief** — did you finish, and how efficiently (overshoot wastes nothing but overtime hurts)?
- **Discretion** — peak stealth; were you ever detected?
- **Cleanliness** — end-state mess; any clogs or splashback?
- **Speed bonus** — Composure remaining at completion.

→ **1–3 stars.** Three stars requires a clean, quiet, efficient run — the replay hook. Optional per-level **Achievements** ("No-TP Victory," "Silent But Deadly," "Zero Splashback") drive collection.

> **See [Results & Scoring](poo-sim-scoring.md)** for the full point model, star thresholds, rank titles, and the reveal choreography — and the mockup **`poo-sim-results-screen.html`** to watch it animate.

---

## 9. Environments (Levels)

Each environment is a themed world with 3–5 levels of escalating difficulty. Launch target: **4 environments** (see MVP). Signature hazards in parentheses.

1. **Festival Porta-Potty** — heat, wobble, a growing line, notoriously no TP. *(Jolt/wobble, The Waiter, Empty Roll.)*
2. **The Work Bathroom** — your boss is in the next stall; be silent, be quick, and for God's sake don't get recognized. *(The Neighbor, The Knock, Discretion-heavy.)*
3. **Airplane Lavatory** — claustrophobic, turbulent, a queue in the aisle, the seatbelt sign. *(Jolt/turbulence, The Waiter, The Knock.)*
4. **Gas Station Restroom** — apocalyptic filth; Cleanliness starts compromised and the key is on a giant spoon. *(Cleanliness-heavy, Empty Roll.)*

**Backlog environments:** fancy restaurant (tipping attendant), camping/woods (nature hazards, exposure), haunted house (comedic spooky), stadium at halftime (crush of people), first date's apartment (thin walls — max Discretion), moving train, hospital, cruise ship, **medieval castle** (a garderobe — no flush, no plumbing, a very long drop), **space station** (zero-G changes the physics of everything; suction instead of gravity).

**Selection principle:** the best new environments **change a rule**, they don't just change the wallpaper. Medieval castle and space station earn their place because they break assumptions the player has internalized about how a toilet works — that's a fresh hazard set, not a reskin. An environment that only swaps the background art is a cosmetic, not a level.

---

## 10. Progression & Meta

- **World Map** — environments unlock sequentially; a "boss sitting" caps each world with a stacked-hazard gauntlet.
- **Star gates** — need X total stars to unlock the next world, so 1-star clears aren't enough forever.
- **Daily Sit** — one rotating daily challenge with a modifier for retention and a bonus reward.
- **Cosmetics** — characters, toilet skins, bathroom decor, victory animations, all unlocked through play (stars, achievements, currency). Pure reward for mastery.
- **Collection** — Achievement gallery + a comedic "Bathroom Log" that stamps each conquered location.

> **See the [Difficulty Curve](poo-sim-difficulty-curve.md)** for the full 20-level curriculum — which hazard each level teaches, the boss structure, star-gate values, and the assist system.

---

## 11. Art & Audio Direction

**Tone — the straight face.** The framing device is that everything is treated with the gravity of a professional simulator: solemn tutorial narration, technical cutaway diagrams, clinical posture analysis, earnest gauges. **Crude content delivered with a straight face is far funnier than crude delivered crudely** — the gap between the subject and the seriousness *is* the joke. It also costs almost nothing (it's mostly copy and a few diagram assets) and it fits the gauge-heavy UI already designed. Treat this as a comedy multiplier applied across the whole game: tutorial voice, loading tips, results breakdowns, achievement names.

**Art:** Bold, chunky, cel-shaded 2D cartoon. Bright, saturated, exaggerated. Gross-out via *comedy* — think exaggerated cartoon grime and squiggle-stink lines, not realistic repulsion. Photorealism is explicitly off the table; it kills the joke and the appeal. Readability first: meters and hazards pop against busy backgrounds. The deadpan diagrams are the one place a cleaner, technical-manual style is welcome — the contrast sells it.

**Audio:** The comedy engine. Wet squelches, dramatic orchestral stingers for tiny victories, a nervous ticking bassline as Composure drains, muffled-panic reactions from neighbors, and a triumphant fanfare on a 3-star flush. Sound sells the gross-out far more than visuals do — this is a priority budget line, not an afterthought.

> **See [Sound Design](poo-sim-sound-design.md)** for the full audio spec — the sound of The Push, per-hazard audio tells, adaptive music, the mix, and the SFX inventory — plus the playable sound board **`poo-sim-sound-demo.html`**.

---

## 12. Pricing

**Premium — a single flat purchase. No ads, no in-app purchases, no in-game store.** The player buys the game once and gets the whole thing.

This shapes design in a few good ways:
- **All content is earned, not bought.** Cosmetics, consumables, and unlocks come purely from play. The reward economy is self-contained and can be tuned for fun instead of conversion.
- **No engagement-farming pressure.** We don't need retention hooks that exist only to serve ads. The Daily Sit stays because it's fun, not because it drives impressions.
- **Simpler build.** No ad SDKs, mediation, or IAP/receipt-validation plumbing to integrate and maintain.

*Open decision: the price point. A crude, focused comedy game like this typically lands in the low-premium range; we'll settle on a number closer to launch based on final content volume.*

---

## 13. Technical Notes

- **Engine: Godot 4.7.x** *(locked)* — free, open source, excellent 2D pipeline, no per-title fee or revenue cut, one-click mobile export.
- **Language: GDScript** *(locked)* — reasoning below.
- **Orientation:** Portrait, single-thumb play. All core interaction must work with one hand.
- **Input:** Hold-to-push + tap/swipe reactions. No precision multi-touch required.
- **Target platforms:** Android **and** iOS. Both are required at launch, which drives the language decision below.
- **Target devices:** Mid-range Android and 2-generations-back iPhone; keep it light.
- **Storefronts:** Standard paid listing on the App Store and Google Play; no ad or IAP integration needed.
- **Content updates:** Daily Sit and cosmetic unlocks should be config-driven so new content can ship in updates without reworking core code.

### Why GDScript and not C#

Godot supports C# as an alternative scripting language, which is tempting given the developer's .NET background. It's still the wrong call here, for one decisive reason: **C# export to Android and iOS remains marked experimental** — and those are the only two platforms this game ships to. The limitations are concrete, not theoretical: the Android build runs on a Mono runtime that lacks Android bindings (some APIs, including SSL, will crash), and iOS runs on NativeAOT, whose trimming can break code paths that rely on reflection.

There's also no upside to weigh against that risk. C#'s real advantage over GDScript is raw execution speed, and this game is four meters, a needle on a gauge, and some timed events — nothing computationally demanding. GDScript meanwhile has no compile step, which directly serves the tuning loop the vertical slice depends on (§14): The Push has to *feel* right, and that's found by nudging values and replaying, not by writing more code.

**Use static typing annotations throughout** (`var force: float = 0.0`). They're optional in GDScript but recover much of the type safety a C# developer expects, and they run faster besides.

*Revisit only if* a future feature turns out to be genuinely compute-bound, or Godot drops the experimental label on C# mobile export.

### Development environment

- **Primary:** a desktop machine running the Godot editor. The editor is a dense multi-pane GUI built for a mouse; it isn't practical to drive from a phone, and the official Android editor is GDScript-only anyway.
- **iOS builds require macOS.** Exporting for iOS must be done from a Mac with Xcode installed — a Mac mini, a rented cloud Mac, or macOS CI runners. This is a hard platform requirement independent of the language choice, and it's the least obvious cost in the whole pipeline. Budget for it early.
- **Source control:** git.

---

## 14. MVP / Vertical Slice

Prove the fun before building content. Target for a first playable:

- **1 environment** (Work Bathroom — Discretion-forward, showcases the tension) with **3 difficulty levels**.
- **The Push** fully tuned and juicy — this is the whole game; it has to feel good in isolation.
- **All four meters** live.
- **2–3 hazards** (The Neighbor, The Knock, The Buzz).
- **Star rating + instant retry.**
- Placeholder art/audio is fine — *but* one hazard and the win fanfare should be near-final to confirm the comedy lands.

**Explicitly NOT in the slice: Prep and The Getaway.** The bookends are only worth building once the sit is proven fun. Building them early risks propping up a weak core with surrounding structure — and if The Push isn't fun on its own, no amount of prep menu will save it.

**Success test:** hand it to someone cold. If they laugh once *and* immediately hit retry after a 2-star run, the core loop works. If not, fix The Push before adding anything.

---

## 15. Open Questions / Decisions to Make

- [ ] **Price point:** what flat price does the launch content justify? (§12)
- [ ] **Player character:** silent avatar, or a named recurring character with personality/story?
- [ ] **Meta-narrative:** any framing (a "world tour of toilets," a bucket list) or purely arcade?
- [ ] **Push control feel:** hold-to-push (proposed) vs. rhythm-tap vs. drag-a-slider — needs prototyping to decide.
- [ ] **Failure severity:** how punishing? Instant fail on detection, or a strike system?
- [ ] **Multiplayer/social:** single-player at launch — but see §17 for the 1v1 potential the architecture is being kept open for.

---

## 16. Rough Roadmap

1. **Prototype** — The Push mechanic only, grey-box. Answer: is holding-and-releasing to fill a meter fun on its own?
2. **Vertical Slice** — the §14 MVP. Prove the loop + comedy.
3. **Content Build** — remaining 3 launch environments, loadout, star gates, meta.
4. **Juice & Polish** — art pass, audio pass, failure set-pieces, game feel.
5. **Meta & Extras** — Daily Sit, cosmetic unlocks, achievements, store listing prep.
6. **Soft launch** — limited region, tune difficulty and pacing.
7. **Launch.**

---

## 17. Future Direction — Multiplayer (post-launch; not in launch scope)

Launch is single-player. But The Push is, underneath, a **race** — "first to fill Relief to 100%" is a 1v1 win condition with no contortion, and the 30–90s session length is ideal match pacing. We are **not** building multiplayer for launch. We *are* building so we don't foreclose it — the distinction below is between a mode we could later add and one we'd have to rebuild the core to support.

### The two models being kept open

- **Async ghost race (cheap, on-model).** Race a recorded run — a "ghost" replayed from a stored input/meter timeline. No servers, no matchmaking; fits the premium/no-server model (§12) cleanly. This is the likely first competitive hook if we ever want one.
- **Real-time 1v1 (feasible, but a business decision).** Because each player drives their *own* gauge, competition is **indirect** — so sync is latency-tolerant: exchange Relief progress plus discrete events, never frame-perfect state. The netcode is the *easy* part. The cost is everything around it — matchmaking, relay servers, anti-cheat, live-ops — a **recurring server cost against no recurring revenue**, which directly tensions §12. Only take it on if the game earns it (and likely a monetization rethink with it).

### Hazards as sabotage

The [Hazard Catalog](poo-sim-hazard-catalog.md) is designed to double as a **1v1 attack deck**: land a clean stretch of Push and you *send* a hazard — a Knock, a Jolt, a Smell Cloud — to your rival's gauge. Fourteen solo annoyances become a combat system for near-free. Still bound by the Complexity Budget: **one decision at a time** — sabotage garnishes the race, it doesn't turn it into a management sim.

### Fairness by construction

Any competitive mode requires both players get the *identical* board — same Flow-Zone script and hazard sequence, from one **shared per-match seed**. Cheap if designed in from the start; a rewrite if bolted on.

### Architectural guardrails — cheap now, a rewrite later

To keep the door open **without building any multiplayer yet**, the vertical slice should already:

1. **Keep the sim deterministic and seeded.** All hazard timing, Flow-Zone changes, and any randomness pull from a single per-match seed — never wall-clock time or global `randf()` in gameplay logic. This buys fair mirrored boards *and* reproducible ghost replays for free.
2. **Fire hazards from an event stream, not hardcoded timers.** A scheduler consumes typed hazard events; an event may originate from the level, a recorded ghost, or an opponent's sabotage — the same code path resolves all three.
3. **Separate simulation state from the UI.** The four meters, the needle, and Relief live in a plain data model the UI *reads* — never stored canonically inside Control nodes. That model is what you would snapshot and sync.
4. **Funnel input through one intent layer,** so a push/reaction can be recorded (ghost) and, later, a remote player's intents slot in identically.
5. **Make "a match" a small config object** (players, seed, level) so it can be one local player, one player + ghost, or two networked players without restructuring the flow.

None of the above is multiplayer code. It is simply *not single-player-only* code — and that is the whole point of writing it down before the core is built.
