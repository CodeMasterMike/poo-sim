# Poo Sim — Difficulty Curve & Level Progression

*Companion to the main spec (§9 Environments, §10 Progression) and the Hazard Catalog. Version 0.1.*

This doc sequences the 14 hazards across 20 launch levels so the game **teaches itself** — no tutorial wall, no manual. A player who starts at 1-1 and plays in order should never meet a mechanic they weren't gently shown first.

---

## Philosophy

**1. Teach one thing at a time.** Every new hazard debuts *alone*, with a generous reaction window, heavy telegraph, and low stakes — a level you basically can't fail. Only once it's understood does it get combined with what came before.

**2. The four-beat pattern.** Each mechanic moves through:
> **Introduce** (alone, safe) → **Practice** (normal, repeated) → **Combine** (with known hazards) → **Test** (the boss, stacked + sped up).

**3. Difficulty comes from the levers, not just new toys.** You don't need a new hazard every level. The same hazard gets harder by tightening its reaction window, cutting its telegraph, raising failure severity, and overlapping it with others (per the Catalog's fairness rules).

**4. The casual promise.** No hard-fails until World 3. Early worlds only *damage* meters and cost stars — they never boot you out. A new player's first ten minutes should be funny and forgiving, so the difficulty is a curve, not a cliff.

---

## The macro curve — world order

Worlds are ordered by the *kind* of pressure they teach, from most contained to most chaotic:

1. **Work Bathroom** — the fundamentals + quiet play. A calm, enclosed room: the perfect classroom.
2. **Festival Porta-Potty** — multitasking + thumb-time competition. Chaos and heat.
3. **Gas Station Restroom** — cleanliness under low margins + the greed dilemma. Grime and hard choices.
4. **Airplane Lavatory** — control disruption + hard deadlines. The mastery exam.

| | W1 · Work | W2 · Festival | W3 · Gas Station | W4 · Airplane |
|---|---|---|---|---|
| **Teaches** | Push, quiet play | Multitask, thumb-time | Cleanliness margins, the clog dilemma | Control disruption, deadlines |
| **Max simultaneous hazards** | 2 | 2–3 | 3 | 3–4 |
| **Reaction windows** | Generous | Normal | Tighter | Tight |
| **Telegraph** | Heavy | Medium | Medium-low | Minimal |
| **Failure** | Meter damage only | + forced early exit (Waiter) | + first hard-fail (clog overflow) | + hard deadlines, all live |
| **New inputs** | hold, dismiss-tap, ease-to-band, freeze | swipe, periodic-tap, decision-tap, drift-correct | setup-swipe, mash | re-center under sustained disruption |

---

## Phase rollout — how Prep and The Getaway unfold

The bookend phases are themselves content to be taught, and the same rule applies: **one thing at a time.** A new player's first levels are the pure sit and nothing else, so the game never opens with a menu.

| | W1 · Work | W2 · Festival | W3 · Gas Station | W4 · Airplane |
|---|---|---|---|---|
| **Prep** | None — pure sit | Debuts 2-1: **1 option**, pick-or-skip | **2–3 options**, cap of 2 picks | Full menu, tighter Composure cost |
| **Getaway** | Auto-plays as an outro (watch only) | Still watch-only; Discretion consequences start showing | **Wash-or-bolt choice** unlocks | Full stakes; can swing a star |

Rationale: World 1 stays a single-screen game so The Push gets undivided attention. Prep arrives only once the player knows what they'd be preparing *for* — a prep menu is meaningless before you've felt an Empty Roll ruin a run. The Getaway is a cutscene long before it's a decision, so its consequences are learned by watching, not by losing.

**Complexity ceiling:** the full game never exceeds *one* prep decision (two picks from a short list) plus *one* exit decision. That's the cap, permanently. It's the Complexity Budget from the main spec applied to the curve.

---

## The boss motif

**Every world's boss debuts that world's hardest mechanic as its opening phase** — gently and well-telegraphed at first, then ramping. The boss is both the world's final exam *and* the reveal of its signature twist. It's a repeatable, recognizable beat: players learn that a boss will always throw one genuinely new thing at them, eased in over the first few seconds before the gloves come off.

---

## World 1 — Work Bathroom

*Goal: master The Push and learn to play quiet. Nothing here can fail you out.*

| Level | New | Active hazards | Teaching goal |
|---|---|---|---|
| **1-1 Just Breathe** | The Push · Splashback | — | Hold to fill; find the Flow Zone; reach 100% Relief. Splashback taught as the red-zone warning. |
| **1-2 Buzzkill** | The Buzz | Buzz | Things will interrupt you. Tap to dismiss and get back to it. |
| **1-3 Thin Walls** | The Neighbor | Neighbor, Buzz | Ease under the quiet-band cap. Speed for silence is the first real trade-off. |
| **1-4 Dead to the World** | Dead Leg | Neighbor, Dead Leg, Buzz | You can't just stall to stay safe — dawdling has its own cost. Resolves the tension Neighbor creates. |
| **1-5 · BOSS · The Boss** | The Knock | Knock, Neighbor, Dead Leg, Buzz | Your manager is at the door. Freeze on the knock, stay under the cap, don't numb up. Everything at once. |

---

## World 2 — Festival Porta-Potty

*Goal: juggle. This world is about the thumb having too much to do.*

| Level | New | Active hazards | Teaching goal |
|---|---|---|---|
| **2-1 Fresh Meat** | The Waiter | Waiter | A line is forming. Learn to feel an external clock pushing you to rush (and to resist over-rushing). |
| **2-2 Something's Off** | Smell Cloud | Smell, Waiter | New gesture: swipe to waft the cloud before it's noticed. |
| **2-3 Busted Lock** | The Broken Latch | Latch, Smell, Waiter | The signature skill: periodic taps to hold the door steal thumb-time from The Push. Peak multitask. |
| **2-4 Out of Paper** | Empty Roll | Empty Roll, Latch, Smell | A one-time decision under pressure. Very on-brand for a festival. |
| **2-5 · BOSS · Peak Hours** | Slippery Grip | Slippery Grip, Latch, Smell, Empty Roll, Waiter, Jolt (bumps) | Heat makes the needle drift all fight long while everything else piles on. |

---

## World 3 — Gas Station Restroom

*Goal: survive filth and greed. Margins are thin and the clog dilemma punishes over-pushing. First hard-fails appear.*

| Level | New | Active hazards | Teaching goal |
|---|---|---|---|
| **3-1 Grim** | Questionable Seat | Questionable Seat (setup) | Pre-act swipe-to-clean sets your starting Cleanliness. This world begins compromised. |
| **3-2 Low Flow** | Clog Risk | Clog, Splashback | The signature dilemma: over-push and the bowl fills — mash to clear or ease off and stall. Generous at first. |
| **3-3 No Margin** | — (hard-fail on) | Clog, Splashback (heavy), Questionable Seat, Empty Roll | Overflow now hard-fails. Cleanliness headroom is tight; greed gets punished. |
| **3-4 Rush Hour** | — | Clog, Smell, Waiter, Splashback | Someone needs the key. Multitask on top of the clog management. |
| **3-5 · BOSS · The Aftermath** | Weak Flush *(Clog variant)* | Weak Flush + Clog, Splashback, Questionable Seat, Empty Roll, Smell | The flush barely works, so the clog builds faster than ever. The cleanliness gauntlet. |

---

## World 4 — Airplane Lavatory

*Goal: mastery. Tight windows, minimal telegraph, control disruption and deadlines combined.*

| Level | New | Active hazards | Teaching goal |
|---|---|---|---|
| **4-1 Fasten Seatbelts** | Jolt / Turbulence | Turbulence (light) | New skill: swipe to re-center the knocked needle. Introduced in light chop. |
| **4-2 Final Boarding** | The Announcement | Announcement, Turbulence | A hard deadline drops. Learn the end-game scramble to finish *now*. |
| **4-3 Occupied** | — | Turbulence, Waiter (aisle queue), Knock (attendant), Buzz | Multitask everything you know, under constant jostling. |
| **4-4 Clear Air… Not** | — | Sustained Turbulence, Announcement, Waiter, Empty Roll | Tight windows, low telegraph. Near-mastery check. |
| **4-5 · BOSS · The Descent** | Sustained heavy turbulence + landing countdown | Turbulence, Announcement, Waiter, Knock, Buzz, Empty Roll | Everything, fast, barely telegraphed, against an unpausable countdown to landing. The final exam. |

---

## The micro-curve (difficulty *within* a single sit)

Each 60–90s level has its own three-act shape, not a flat hazard drizzle:

- **Open (calm):** a few seconds of pure Push to settle in and read the Flow Zone.
- **Middle (escalation):** hazards fire at the world's normal cadence.
- **The Final Push (spike):** as Relief nears ~85%, a deliberate burst — the classic "so close" pinch that makes clutch finishes feel earned and 3-stars feel hard-won.

The spike is where most of the drama and most of the failures live. Tune it hard.

---

## Star gates & progression

Stars gate the worlds so you can't 1-star-rush to the end — you have to circle back and clean up. Values are starting points to tune (max 60★ across 20 levels):

| To unlock | Stars needed | ≈ Avg per prior level |
|---|---|---|
| World 1 | 0 (open at start) | — |
| World 2 | 8 ★ | ~1.6 |
| World 3 | 20 ★ | ~2.0 |
| World 4 | 34 ★ | ~2.3 |
| (Full clear) | 60 ★ | 3.0 |

The required average climbs gently — later worlds ask for cleaner play to enter, which naturally pulls skilled players back to perfect earlier levels.

---

## Assists & accessibility (the no-paywall ramp)

Because there's no store (§12 of the main spec), a stuck casual player is helped, never upsold. After repeated fails on a level, offer **opt-in assists**:

- Widen the Flow Zone.
- Slow the Composure drain.
- Add extra telegraph time to hazards.

Assists are free, toggleable, and carry no penalty beyond a small star cap (e.g., assisted clears max at 2★), so mastery still means something. This keeps the curve honest for skilled players while making sure a casual player is never hard-walled behind a difficulty spike.

---

## Daily Sit

The Daily Sit pulls only from **already-cleared** hazards (never something the player hasn't been taught) and remixes them with a modifier: a tighter Flow Zone, doubled hazard frequency, a permanent quiet-band, one-life, etc. It's a mastery playground for returning players, tuned to their furthest-cleared world.

---

## Open questions

- [ ] **World count vs. depth:** 5 levels/world (current) or 4 with denser levels? Affects total runtime and star-gate math.
- [ ] **Boss-debut motif:** is introducing a brand-new mechanic *in* the boss too harsh for a casual audience, even with a gentle phase 1? Playtest whether it delights or frustrates.
- [ ] **Hard-fail timing:** is World 3 the right place for the first fail-out, or should it come later/never for the most casual tier?
- [ ] **Assist star cap:** does capping assisted runs at 2★ feel fair, or punitive? Consider no cap but a separate "clean clear" badge instead.
- [ ] **Difficulty pacing between worlds:** should there be a short "victory lap" easy level after each boss to reset tension before the next ramp?
