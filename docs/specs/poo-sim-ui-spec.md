# Poo Sim — Seated Screen UI Spec

*Companion to the main spec (§4 The Push, §5 Meters) and the Hazard Catalog. Pairs with the interactive mockup `poo-sim-seated-screen.html`. Version 0.1.*

The seated screen is the whole game. There is no world map moment-to-moment, no inventory rummaging mid-act — just this one screen, played one-handed, under pressure. Every decision here optimizes for **glanceability** and **thumb reach.**

---

## The five zones (top → bottom)

The screen is a vertical stack. Heights are proportional targets on a standard phone; tune per device.

| # | Zone | ~Height | Job |
|---|---|---|---|
| 1 | **HUD** | 6% | Pause, environment/level label, mute. Static, forgettable, out of the way. |
| 2 | **Composure bar** | 4% | The master clock. Full-width, always draining, shifts green→amber→red. The one meter you can't ignore. |
| 3 | **Scene** | 42% | The environment, the character, and where hazards visually play out. Houses the Relief meter (right) and the Discretion/Cleanliness pills (top-left). |
| 4 | **Prompt band** | 8% | Reserved strip for the current hazard's call-to-action. Calm = a faint hint; hazard = a loud, unmistakable instruction. |
| 5 | **Push control** | 40% | The Force gauge + the hold pad. The thumb lives here. This is the signature. |

Why this order: the things you *watch* (Composure, Relief, the scene) sit up top where the thumb won't cover them; the thing you *do* (The Push) sits at the bottom where the thumb rests. The Prompt band is the bridge — it puts the "what do I do right now" message directly above the thumb, not buried in the scene.

---

## The core ergonomic rule: fiction up top, reaction down low

This is the most important principle on the screen, and the easiest to get wrong.

A hazard's **fiction** lives in the scene (upper half): the door rattles, the neighbor's shadow leans in, the smell cloud rises, the bowl fills. But the **reaction target** — the thing the player actually touches — must surface into the **lower thumb zone**, never require reaching up to a tiny spot near the top.

- The Knock rattles the door *up there*, but the instruction ("HOLD STILL") flashes in the Prompt band and the reaction is simply *releasing the pad you're already holding.*
- Smell Cloud rises in the scene, but the swipe to waft it happens as a big gesture across the lower band.
- Splashback originates at the bowl, but the "adjust" tap surfaces as a large target near the thumb.

If a reaction ever demands a precise tap in the top third of the screen, redesign it. One-handed players can't reach there without regripping, and regripping mid-act is a lost run.

---

## Meter language

One consistent color grammar across every meter and the gauge, so a panicked glance is never ambiguous:

- 🟢 **Green** — safe / in the Flow Zone / goal progress.
- 🟡 **Amber** — caution; drifting toward trouble.
- 🔴 **Red** — danger; noise, splash, detection, or imminent fail.
- 🟠 **Orange** — reserved *only* for "a hazard needs your reaction right now." Nothing ambient is ever orange, so orange always means *act.*

Meter directions are all "fuller is better" to avoid inversion confusion:

- **Relief** — fills toward the top = closer to winning. The goal line marks 100%.
- **Composure** — full = calm; empties = you lose it.
- **Discretion** — full = undetected; empties = caught.
- **Cleanliness** — full = spotless; empties = a mess.

Each secondary meter carries an icon (🤫 Discretion, ✨ Cleanliness) so it's identifiable without reading a label.

---

## The Force gauge (signature element)

The gauge is the one component that gets to be loud. It's a tall vertical readout with three marked regions:

- **Dead zone** (bottom) — barely pushing; Relief crawls, Composure bleeds.
- **Flow Zone** (middle, glowing green) — the sweet spot; ideal Relief fill, quiet, clean.
- **Red zone** (top) — over-pushing; fills Relief *faster* but risks Noise, Splashback, and Clog.

The **needle** is the player's avatar on the gauge. It's chunky, high-contrast, and glows so it's trackable in peripheral vision while the eyes are on a hazard. The Flow Zone can shift, narrow, or split between levels — the gauge is the same component; only the green band's behavior changes.

The **hold pad** beside it is the entire push surface. Hold to raise the needle, release to let it fall. During freeze-type hazards (The Knock) the pad's label flips to "RELEASE" to reinforce the required action.

---

## Screen state machine

The screen moves through six states. Crucially, **the scene and meters stay in place across all of them** — Prep and The Getaway reuse the same environment art and meter positions, so nothing reflows and the player's spatial memory holds.

1. **Setup** *(2–3s)* — title card names the scene and win condition. Meters shown at starting values.
2. **Prep** *(5–8s)* — see below.
3. **Act** *(the bulk)* — The Push is live. Prompt band shows the calm hint. Meters update in real time.
4. **Hazard overlay** *(interrupts)* — one or more hazards fire. The Prompt band goes orange with the instruction; the relevant scene actor animates; the offending meter pulses. Overlays sit *on top of* a still-running Act (max tension) — except freeze-types, which pause the Push by design.
5. **The Getaway** *(3–5s)* — see below.
6. **Resolution** — results card shows the star breakdown.

### Prep screen

The design goal is **glance-and-tap, never a menu to study.**

- Same scene, but the **Push control area is replaced** by 2–3 large prep cards — no new screen, no reflow.
- Each card is an **icon + two words** ("Check paper," "Clean seat"). No stat text, no numbers, no percentages. If a player has to read to decide, it's failed.
- The prep targets are also **highlighted in the scene itself** (the roll glows, the latch glows), so the choice is spatial and readable — you're looking at the room, not parsing a list.
- The **Composure bar visibly drains in real time** during Prep. This is the whole dilemma made literal: you can watch your clock being spent. Nothing else communicates the tradeoff as fast.
- A large, always-present **JUST GO** button sits where the hold pad will be — so a player who wants to skip taps in exactly the place their thumb already lives.
- Selected cards stamp with a checkmark; a cap of 2 is enforced by graying the rest, not by an error message.

### The Getaway screen

- Plays mostly as a **watched beat** — the stall opens, the scene reveals who's out there, reacting according to your final Discretion.
- Exactly **one input**, presented as two big thumb-zone buttons: **WASH** or **BOLT**. No timer pressure beyond a short auto-select, so the beat can't stall a player who's stopped paying attention.
- The Discretion meter is the visual anchor here — it should be the thing that animates as consequences land, closing the loop on a meter that otherwise just sits at a number.

---

## Readability & quality floor

- **Glance test:** a player must read all four meters + the current prompt in under one second. If a screenshot can't be parsed that fast, it's too busy.
- **Motion discipline:** ambient motion is minimal (a breathing needle glow, a sweat drip when tense). Motion is a *signal*, so save big animation for hazards, where movement means "react." Respect reduced-motion settings.
- **Safe areas:** keep meters and the pause button clear of the notch/punch-hole and the home indicator.
- **Contrast:** every meter and prompt must stay legible against a busy, colorful scene — hence the dark ink backing behind the HUD, pills, and Prompt band.
- **Thumb-side option:** plan a left-handed mirror mode (gauge and pad swap sides) as an accessibility setting.

---

## Component / asset checklist

For the artist and engineer, the discrete pieces this screen needs:

- HUD: pause, mute, level-label plate.
- Composure bar with 3-stage color states.
- Relief vertical meter + goal line + fill.
- Discretion & Cleanliness pills (icon + bar), each with color states.
- Scene layers: environment back (swappable per level), toilet, character rig (idle + tense + fail poses), floor.
- Hazard actors: door + latch, neighbor shadow, smell cloud, waiter shadow, bowl/splash FX, phone.
- Prompt band: calm variant + alert (orange) variant + swipe-arrow motif.
- Force gauge: track, dead/flow/red regions, needle (with glow), Flow-Zone variants (shift/narrow/split).
- Hold pad: idle + pressed states, plus the "RELEASE" freeze variant.
- Results card (Resolution).

---

## Open questions

- [ ] **Gauge orientation:** vertical (current) vs. horizontal along the bottom — vertical reads as "pressure" but eats width; prototype both.
- [ ] **Hold-anywhere vs. dedicated pad:** the spec says "hold anywhere"; the mockup uses a defined pad so hazard taps have somewhere to live. Confirm which, since it affects where reflex targets can go.
- [ ] **Colorblind support:** green/amber/red needs a secondary channel (icon shape or pattern), not color alone.
- [ ] **Prompt band vs. floating prompts:** a fixed band (current) is predictable; floating prompts near the hazard are more diegetic but risk the reach problem. Leaning fixed band.
- [ ] **Composure representation:** a bar (current) vs. a shrinking ring vs. a rising "panic" tint on the whole screen.
