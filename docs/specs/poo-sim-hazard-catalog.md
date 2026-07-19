# Poo Sim — Hazard Catalog

*Companion to the main spec (§6 Hazards). Version 0.1 — a living catalog; add entries as you design.*

---

## What a hazard is

A **hazard** is a timed event layered *on top of* The Push. The Push alone is a steady hold-to-fill mechanic — pleasant, but it would put you to sleep. Hazards are what turn a sitting into a panic. Each one demands a quick, **distinct** reaction so the player can never just clamp the button down and zone out.

Three rules every hazard must obey:

1. **One clear input.** A hazard has exactly one signature reaction. If the player can't tell in half a second what to do, it's not readable enough for a phone.
2. **It threatens one meter.** Every hazard maps cleanly to Relief, Composure, Discretion, or Cleanliness. This keeps the four-meter system legible even in chaos.
3. **Fail funny.** Failing a hazard is a comedic beat, not a spreadsheet penalty. The audio and animation sell the disaster.

---

## Anatomy of a hazard (entry template)

Every entry below uses these fields — copy this shape for any new hazard:

- **Type** — its behavior category (see below)
- **Threatens** — the primary meter at risk
- **Trigger** — when/how it fires
- **Reaction** — the one input that resolves it
- **Success / Failure** — outcomes
- **Cost** — (dilemmas only) what saying "yes" to the reaction costs you
- **Scales by** — how it gets nastier at higher difficulty
- **Homes** — environments where it lives; **(S)** = signature

---

## Hazard types

The catalog is more interesting than "tap-when-flashing" because hazards come in different shapes. The best ones are **Dilemmas**, not reflexes — they make you trade one meter for another.

| Type | What it does | Feels like |
|---|---|---|
| **Reflex** | One quick input inside a short window | A twitch check |
| **Dilemma** | Forces a costly tradeoff between meters | "Ugh, either way I lose something" |
| **Sustained Constraint** | Changes the rules of the Push for a duration | Playing with one hand tied |
| **Decision** | A one-time branching choice | A gamble |
| **Setup Modifier** | Alters starting conditions before the act | A bad hand you're dealt |
| **Pressure** | No direct input; raises the stakes of everything else | A ticking clock |

A good level mixes types. A level that's all Reflex is a whack-a-mole; a level that's all Pressure is boring. Aim for a spine of one or two Dilemmas with Reflexes sprinkled around them.

---

# The Catalog

Grouped by the meter each hazard threatens.

---

## Discretion hazards *(noise, smell, getting caught)*

### The Knock — *Dilemma*
> Three sharp raps. "Someone in there?"
- **Threatens:** Discretion
- **Trigger:** Random after ~30% Relief; telegraphed by a shadow at the door.
- **Reaction:** Release The Push and **hold completely still** (no input) for the beat.
- **Success:** They move on. Discretion safe.
- **Failure:** Keep pushing (audible) → Discretion craters, and it escalates the Neighbor/Waiter.
- **Cost:** Freezing means zero Relief progress during the hold — you're bleeding Composure to stay quiet. The longer the knock lasts at higher difficulty, the sharper the bind.
- **Scales by:** Longer freeze window; multiple knocks per sit; less telegraph.
- **Homes:** Work Bathroom **(S)**, Airplane.

### The Neighbor — *Sustained Constraint*
> The stall beside you is occupied. They can hear *everything.*
- **Threatens:** Discretion
- **Trigger:** Present for a stretch of the level; a **"quiet band"** overlays the Force gauge, capping your safe max push far lower than normal.
- **Reaction:** Ease off and keep the needle under the lowered cap.
- **Success:** Discretion safe — but Relief fills slowly, so Composure pressure builds.
- **Failure:** Exceed the cap → a loud, unmistakable noise, Discretion crater, and a comedic in-fiction reaction from next door.
- **Cost:** You're trading speed for silence for the whole duration.
- **Scales by:** Lower cap; longer duration; the neighbor "leans in" (cap tightens over time).
- **Homes:** Work Bathroom **(S)**.

### Smell Cloud — *Reflex*
> A visible stink drifts up toward a vent, a fan, or a person's nose.
- **Threatens:** Discretion (smell axis)
- **Trigger:** Emitted periodically after big pushes; a green cloud rises on a slow arc.
- **Reaction:** **Swipe** to waft it away before it reaches the target.
- **Success:** Dispersed. No penalty.
- **Failure:** It lands → Smell spikes → Discretion hit; someone gags.
- **Scales by:** Faster clouds; multiple at once; smaller swipe tolerance.
- **Homes:** Festival Porta-Potty, Gas Station.

### The Broken Latch — *Sustained Constraint*
> The lock is busted. The door keeps drifting open.
- **Threatens:** Discretion (exposure)
- **Trigger:** Persistent; a "door ajar" meter creeps open on its own throughout the sit.
- **Reaction:** Periodically **tap the door** to shove it shut — stealing thumb-time away from The Push.
- **Success:** Kept shut, nobody sees in.
- **Failure:** Door swings open at the wrong moment → instant exposure, big Discretion hit, passersby react.
- **Cost:** Every tap on the door is a moment you're not managing your Push.
- **Scales by:** Faster drift; gusts of wind that snap it open suddenly.
- **Homes:** Festival Porta-Potty **(S)**.

---

## Cleanliness hazards *(mess, clogs, splash)*

### Empty Roll — *Decision*
> You reach for the TP. The roll is a bare cardboard tube.
- **Threatens:** Cleanliness
- **Trigger:** One-time reveal, usually mid-to-late act.
- **Reaction:** A quick branching choice: **Ration** (dab the last scraps — small, safe Cleanliness cost) / **Improvise** (high variance — could be fine, could be a catastrophe) / **Tough it out** (skip it — hits Cleanliness now but saves time).
- **Success:** Depends on the branch and a little luck.
- **Failure:** The Improvise gamble going wrong is a signature comedic disaster.
- **Scales by:** Fewer safe options in harder levels; a decoy full roll that's actually empty.
- **Prep interaction:** "Check the paper" during Prep reveals the empty roll *before* you commit — turning this from a random gotcha into a mistake the player chose to risk. Skipping the check is what makes the punishment feel fair.
- **Homes:** Festival **(S)**, Gas Station, Airplane.

### Clog Risk — *Dilemma*
> The bowl is filling faster than it's draining.
- **Threatens:** Cleanliness (and Relief, if you back off)
- **Trigger:** Fires when you overshoot — pushing hard/greedy fills a hidden **Clog meter**.
- **Reaction:** Either **mash** to work it down, or **ease off the Push** to let it settle.
- **Success:** Cleared or held stable.
- **Failure:** Clog meter maxes → overflow. Cleanliness fail, possible hard fail depending on severity setting.
- **Cost:** Mashing splits your attention; easing off stalls Relief. The greedy fast-fill strategy is exactly what triggers this — it's the game punishing recklessness.
- **Scales by:** Faster clog buildup; weaker flush (see below); overflow at lower thresholds.
- **Homes:** Gas Station **(S)**, older-building levels.

### Splashback — *Reflex*
> Push too hard and physics has opinions.
- **Threatens:** Cleanliness
- **Trigger:** A warning flashes whenever the needle sits in the red for too long.
- **Reaction:** Quick **tap the warning** to "adjust posture" and avoid it.
- **Success:** Dodged.
- **Failure:** Splash → Cleanliness hit, and an audible/visible *yuck.*
- **Scales by:** Shorter warning; triggers deeper into the amber zone, not just red.
- **Homes:** All levels; nastier at Gas Station.

### Questionable Seat — *Setup Modifier*
> The seat is... a crime scene.
- **Threatens:** Cleanliness (starting value)
- **Trigger:** During the **Prep phase**, before The Push begins.
- **Reaction:** "Clean the seat" is one of the Prep options — a short swipe that sets your *starting* Cleanliness. Spend the seconds, or skip it and start compromised.
- **Success:** Higher starting Cleanliness = more headroom for the sit.
- **Failure:** N/A — it's a floor-setter, not a fail state. But a filthy start leaves no margin for later Cleanliness hits.
- **Scales by:** Grimier seats need more/faster swiping for the same result.
- **Homes:** Gas Station **(S)**.

---

## Composure hazards *(time and pressure)*

### The Waiter — *Pressure*
> Someone's out there. Foot tapping. Sighing loudly.
- **Threatens:** Composure (via an external clock)
- **Trigger:** A visible **second timer**, separate from Composure, counting down the patience of whoever's waiting.
- **Reaction:** None direct — it just *pressures* you to push harder and faster, which risks Discretion and Cleanliness.
- **Success:** Finish before it empties.
- **Failure:** It empties → they bang on the door / leave a scathing review / a forced early exit that caps your Relief.
- **Scales by:** Shorter patience; the waiter escalates (polite → hostile) with audio to match.
- **Homes:** Festival, Airplane **(S, aisle queue)**, Work.

### The Buzz — *Reflex / Decision*
> Your phone lights up on your knee.
- **Threatens:** Composure (distraction) and Discretion (if it rings)
- **Trigger:** Random buzz; if ignored it buzzes louder (Noise creeping toward Discretion).
- **Reaction:** **Tap to dismiss** (safe). Or read it — a comedic beat that drains Composure while you're distracted.
- **Success:** Dismissed, back to business.
- **Failure:** Let it ring out → Discretion hit; get sucked into doomscrolling → Composure bleed.
- **Scales by:** More frequent buzzes; a "just one more notification" temptation loop.
- **Homes:** All levels. (Airplane pairs it with a mode-related gag.)

### The Announcement — *Pressure / Deadline*
> "Ladies and gentlemen, we're beginning our descent."
- **Threatens:** Composure (hard deadline)
- **Trigger:** A scripted event that either lops a chunk off Composure or slams down a fixed countdown to a forced exit.
- **Reaction:** None — it forces a scramble to finish *now*.
- **Success:** Beat the new deadline.
- **Failure:** Caught out → forced exit, Relief capped where it stands.
- **Scales by:** Earlier trigger; harsher time cut; stacked with a live hazard.
- **Homes:** Airplane **(S, seatbelt sign)**, Festival (set about to start).

### Dead Leg — *Pressure (anti-stall)*
> Sit too long and you lose all feeling below the knee.
- **Threatens:** Composure (and a stumble penalty)
- **Trigger:** A **numbness meter** that fills whenever you dawdle at a low push for too long.
- **Reaction:** **Mash to "shake it out"** before it maxes.
- **Success:** Circulation restored.
- **Failure:** Full numbness → a stumble on exit: a comedic penalty and a Cleanliness/Discretion ding.
- **Cost:** Exists specifically to punish the "turtle" strategy of stalling to avoid other hazards.
- **Scales by:** Faster numbness; longer shake-out required.
- **Homes:** All levels.

---

## Control-disruption hazards *(they attack the Push itself)*

These threaten **Relief** indirectly by making the core control harder to hold steady.

### Jolt / Turbulence — *Reflex*
> The whole world lurches.
- **Threatens:** Relief (via Push disruption)
- **Trigger:** A single jolt (a truck rumbles past, someone bumps the unit) or sustained turbulence (repeated jolts).
- **Reaction:** **Swipe / drag** to re-center the knocked needle fast.
- **Success:** Recentered, minimal Relief lost.
- **Failure:** Needle flies into red (Splashback/Noise risk) or bottoms out (progress stalls).
- **Scales by:** Bigger displacement; sustained rolling turbulence; jolts timed to fire mid-Knock.
- **Homes:** Airplane **(S, turbulence)**, Festival (crowd bumps), moving-vehicle levels.

### Slippery Grip — *Sustained Constraint*
> It's 95°F in a plastic box. Your thumb won't cooperate.
- **Threatens:** Relief (via Push precision)
- **Trigger:** Environmental (heat/sweat); active for the whole sit.
- **Reaction:** Constant micro-corrections — the needle drifts on its own and never sits still.
- **Success:** Managed drift, steady-ish fill.
- **Failure:** Left uncorrected, it wanders into red or dead zones.
- **Scales by:** Stronger drift; drift direction changes unpredictably.
- **Homes:** Festival Porta-Potty **(S, heat)**.

---

# Difficulty scaling — global levers

Rather than inventing new hazards for every level, dial these knobs on the ones you have:

1. **Frequency** — more hazard events per sit.
2. **Reaction window** — shorter time to respond.
3. **Telegraph** — less warning before it fires.
4. **Severity** — bigger meter hit on failure.
5. **Overlap** — two hazards active at once (see fairness rules).
6. **Introduction cadence** — each new world debuts one new hazard, then remixes it with the old ones.

A clean difficulty curve teaches one hazard in isolation, then starts combining. Never introduce a brand-new hazard *and* a punishing window in the same level.

---

# Environment × Hazard matrix

**(S)** = signature (defines the level's feel) · **✓** = appears

| Hazard | Festival | Work | Airplane | Gas Station |
|---|:---:|:---:|:---:|:---:|
| The Knock | | **(S)** | ✓ | |
| The Neighbor | | **(S)** | | |
| Smell Cloud | **(S)** | | | ✓ |
| The Broken Latch | **(S)** | | | |
| Empty Roll | **(S)** | | ✓ | ✓ |
| Clog Risk | | | | **(S)** |
| Splashback | ✓ | ✓ | ✓ | ✓ |
| Questionable Seat | | | | **(S)** |
| The Waiter | ✓ | ✓ | **(S)** | |
| The Buzz | ✓ | ✓ | ✓ | ✓ |
| The Announcement | ✓ | | **(S)** | |
| Dead Leg | ✓ | ✓ | ✓ | ✓ |
| Jolt / Turbulence | ✓ | | **(S)** | |
| Slippery Grip | **(S)** | | | |

Every environment has 3+ signatures plus a share of the four universals (Splashback, The Buzz, Dead Leg, The Waiter). Signatures are what a player remembers; universals are the connective tissue.

---

# Stacking & fairness rules

Overlap is where difficulty gets spicy — and where it gets *unfair* if you're careless. Guardrails:

- **Cap simultaneous hazards.** ~2 early game, ~3 late. More than that is noise, not challenge.
- **Never stack contradictory inputs.** The Knock (freeze, don't touch) must never fire at the same instant as Clog Risk (mash now) or Dead Leg (shake now). Asking the thumb to freeze and mash simultaneously is a cheap-feeling loss.
- **Stagger reaction windows.** Two Reflex hazards should peak a beat apart, not on the same frame.
- **Telegraph every overlap.** If two things are about to hit, both must be visible early enough to plan.
- **Signature combos are fine — and good.** Turbulence + The Waiter on the plane, or The Neighbor + The Knock in the work bathroom, are *fair* pairings that define those levels. Design a few of these deliberately.
- **One dilemma at a time.** Two simultaneous tradeoff-dilemmas is overwhelming; let Reflexes garnish a Dilemma, not compete with it.

---

# Open questions

- [ ] **Overlay vs. pause:** do hazards play *over* a still-running Push (max tension) or briefly pause it? Recommendation: overlay for everything except freeze-type hazards (The Knock).
- [ ] **Tilt controls:** use the accelerometer for Jolt re-centering, or keep everything one-thumb touch? Leaning toward touch-only to honor the one-hand pillar.
- [ ] **Failure model:** per-hazard failure = meter damage vs. instant fail. Ties directly to the failure-severity open question in the main spec (§15).
- [ ] **Telegraph budget:** how much warning is fair on a small screen? Needs playtesting to find the line between "tense" and "unreadable."
- [ ] **Backlog hazards to spec later:** The Floater (post-flush minigame), The Peeker (gap in the stall door), The Draft (cold-snap needle spike), Weak Flush (amplifies Clog Risk).
