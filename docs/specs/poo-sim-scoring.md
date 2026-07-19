# Poo Sim — Results & Scoring

*Companion to the main spec (§8 Scoring & Star Rating). Pairs with the interactive mockup `poo-sim-results-screen.html`. Version 0.1.*

The results screen is the single biggest driver of "one more sit." A clear should feel like a tiny triumph, a botched run should be funny enough that you *want* to try again, and the star you just missed should nag you. This doc defines both the **math** (how a run becomes a score) and the **choreography** (how that score is revealed).

---

## What a result is made of

Every completed sit is scored on four axes plus a clear bonus. Two axes are "don't screw up" (Discretion, Cleanliness); two are "do it well" (Flow, Speed). They're deliberately independent, so different playstyles score differently.

| Component | Measures | How it's read |
|---|---|---|
| **Clear bonus** | Did you finish at all? | Flat award for reaching 100% Relief. |
| **Discretion** | Stealth — were you ever noticed? | Final Discretion meter, minus a penalty per detection event. |
| **Cleanliness** | Mess — clogs, splashback, disasters. | Final Cleanliness meter. |
| **Relief (Flow)** | *How* you pushed — skill, not speed. | Flow Ratio: the fraction of your fill earned inside the green Flow Zone vs. greedy red-zone mashing. |
| **Speed** | Time to spare. | Composure remaining at the moment you finished. |

The key design move: **Relief isn't scored on finishing** (that's the clear bonus) — it's scored on *fill quality.* You can grind it out cleanly in the Flow Zone (high Flow, maybe low Speed) or mash the red zone fast (high Speed, low Flow, and you probably wrecked Cleanliness doing it). That tension is the whole scoring game.

---

## The point model

Base score runs 0–1000. Weights lean toward the "keep it clean and quiet" fantasy:

| Component | Max points |
|---|---:|
| Clear bonus | 100 |
| Discretion | 300 |
| Cleanliness | 300 |
| Relief (Flow) | 150 |
| Speed | 150 |
| **Base total** | **1000** |

### Reaction Streak (bonus, on top of base)

Every hazard you resolve *inside its window* extends a streak; any fumble resets it to zero. At the end, the streak pays out as a bonus — roughly **+25 per flawless reaction**, stacking, with a satisfying escalating chime. A god-run lands well above 1000, which gives leaderboards and personal bests real headroom.

**Stars key off the base score only.** The streak bonus is pure flair and leaderboard fuel — it never inflates your star rating. That keeps a star meaning the same thing every time: quality of outcome, not flashiness of execution.

---

## The bookends — how Prep and The Getaway score

Neither bookend adds a point bucket. Both are **modifiers on axes that already exist**, which keeps the base at 1000 and honors the Complexity Budget's "no new meters" rule.

### Prep → Speed

Prep time is deducted from Composure before the sit begins, so it lands on the **Speed** axis automatically — spend six seconds checking the paper and you have six fewer seconds of cushion at the finish. No separate penalty is applied anywhere; the cost is simply that Speed gets scored from a lower starting clock.

This is the prep dilemma expressed in points: the picks that protect Discretion and Cleanliness (worth 600 combined) are paid for out of Speed (worth 150). Prepping is therefore usually correct — and *over*-prepping is exactly how you lose the Speed points you needed for a third star.

### The Getaway → Discretion vs. Speed

The exit is one choice, and it trades the same two axes the rest of the game trades:

| Choice | Effect |
|---|---|
| **WASH** | A fixed time cost (~4s equivalent) deducted before Speed is scored. In exchange, Discretion is **restored by up to +40**, capped at the axis maximum — you left like a civilized person. |
| **BOLT** | No time cost. Discretion takes a penalty **scaled to how exposed you already were.** |

The scaling on BOLT is what keeps the choice alive. Bolt on a spotless run and barely anyone registers it — a trivial penalty. Bolt after you've been detected twice and it compounds: you're the person who made that noise *and* didn't wash. The penalty grows as final Discretion falls, so bolting is cheap exactly when you don't need it and expensive right when you're tempted.

**Washing restores meter points; it does not erase a detection event.** The 3★ gate's "never detected" clause still refers to whether you were caught during the sit, so a good exit can't launder a bad one. This matters — otherwise WASH becomes a mandatory tax rather than a choice.

**The Getaway can move a star**, which is the entire point of keeping it — it's a reversal, not a formality. A run sitting at 840 with clean Discretion can wash its way into ★★★, or bolt and settle for ★★.

---

## Star thresholds

| Stars | Requirement |
|---|---|
| ★ | Cleared (reached 100% Relief). |
| ★★ | Base score ≥ 600. |
| ★★★ | Base score ≥ 850 **and** never detected **and** no clog/major mess. |

Three stars is a "clean, quiet, efficient" gate on purpose — you can post a high number and still miss it if you got spotted once or left a disaster. **Assisted runs cap at ★★** (see the Difficulty Curve's assist system), so assists get you unstuck without cheapening a 3-star.

*All thresholds are starting values to tune against real playtest score distributions.*

---

## Rank titles (the comedy grade)

On top of stars, every run earns a **title** — the shareable, funny verdict. This is where the game's voice lives. Titles read off stars *and* the standout (or standout-bad) axis:

| Outcome | Title |
|---|---|
| ★★★ flawless (no fumbles, all axes high) | 👑 **The Porcelain Throne** |
| ★★★ | **Smooth Operator** |
| ★★ balanced | **Got the Job Done** |
| ★★ fast & greedy (high Speed, low Flow) | **In and Out** |
| ★ low Cleanliness | **Crime Scene** |
| ★ detected | **Publicly Humiliated** |
| ★ squeaked in (low Speed) | **By a Hair** |
| Fail — Composure emptied | **Couldn't Hold It** |
| Fail — clog overflow | **Catastrophic** |

Titles are cosmetic but sticky — they're the line a player screenshots. Write more of them than you think you need; variety is what keeps the payoff fresh across dozens of runs.

---

## Achievements (per-level badges)

Optional objectives that unlock in the Bathroom Log / collection. They give skilled players a reason to replay a level they've already 3-starred:

- **Silent But Deadly** — clear with perfect Discretion (never detected).
- **Zero Splashback** — clear a splash-heavy level with perfect Cleanliness.
- **Flow State** — 100% Flow Ratio; never touched the red zone.
- **Speedrun** — finish with ≥ 60% Composure remaining.
- **No-TP Victory** — clear at high Cleanliness despite an Empty Roll gone wrong.
- **Held the Line** — the Broken Latch never once swung open (Festival).
- **Unbothered** — dismiss every Buzz inside its window.
- **Ironclad** — earn ★★★ with no assists active.

---

## The results screen sequence (choreography)

Order and timing matter as much as the numbers. The reveal is a build, not a data dump:

1. **The Getaway resolves** *(3–5s)* — the exit plays out first: the door opens, the room reacts according to your final Discretion, and the wash-or-bolt choice is taken. This is the comedic payoff *and* the last scoring input, and it happens before a single number appears.
2. **Card drop** — the results card slides in; environment + level label at top.
3. **Axis tally** — Discretion → Cleanliness → Flow → Speed count up one at a time, each with a filling bar and a tick sound. Sequential, not simultaneous — the anticipation is the point. **The Getaway's adjustment animates as a delta on the rows it modifies** (a late +40 nudging the Discretion bar, or a bite taken out of Speed) rather than appearing as a fifth row — the card stays at four axes, and the player watches their exit choice land where it actually applied.
4. **Streak bonus** — the reaction-streak chime escalates as it adds on.
5. **Total** — the big number counts up to its final value.
6. **Star stamp** — stars slam in one by one with impact (screen shake, a bass hit). This is the peak dopamine moment; give it room.
7. **Title slam** — the rank title crashes onto the screen.
8. **Achievement pop** — any newly unlocked badges toast in.
9. **Buttons** — **Retry** (always prominent — protect "one more sit"), **Next** (if cleared), **Menu**.

On a fail, skip the stars/streak: play the disaster beat, show the fail title, and land fast on an encouraging **Retry** ("So close. One more?"). No punishment beyond the retry itself.

---

## Fail states

| Trigger | Result |
|---|---|
| Composure empties | Panic fail — "Couldn't Hold It." No stars. |
| Clog overflow (W3+) | Hard-fail disaster — "Catastrophic." No stars. |
| Waiter timer empties before 100% | Forced early exit; if Relief < 100% it's a fail. |

Fails are comedic set-pieces, never scolding. The failure animation *is* the reward for losing — make it worth watching, then get out of the way so the player can retry instantly.

---

## Open questions

- [ ] **Score visibility:** show the raw 0–1000 number, or keep it stars-and-title only for a more casual feel? Numbers help mastery players and leaderboards; they can feel "tryhard" for casual ones. Possibly a setting.
- [ ] **Streak cap:** uncapped (leaderboard arms race) vs. a soft cap so scores stay legible?
- [ ] **3★ gate strictness:** is "never detected + no mess" too punishing for a 3-star, or exactly the right skill bar?
- [ ] **Per-level vs. global leaderboards:** and are they even in scope for launch, or a post-launch add?
- [ ] **Title randomization:** one fixed title per outcome (predictable, learnable) vs. a small random pool per bucket (fresher, less "earned")?
- [ ] **WASH restore value:** is +40 Discretion enough to make washing feel worth the seconds, or does it need to scale with how filthy the environment is (a gas-station wash arguably matters more)?
- [ ] **BOLT penalty curve:** linear with final Discretion, or sharper at the low end so a truly exposed run gets properly punished for fleeing?
- [ ] **Prep cost visibility:** should the results card call out how much Speed the prep phase cost, so players connect the two — or does surfacing it just make prepping feel bad?
