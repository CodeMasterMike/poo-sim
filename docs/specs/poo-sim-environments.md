# Poo Sim — Environment Design Backlog

*Companion to the main spec (§9 Environments) and the [Hazard Catalog](poo-sim-hazard-catalog.md). Version 0.1 — a living menu; add entries as you dream them up.*

This doc exists so the good environment ideas are **saved with the reason they're good**, not just as names. The spec lists a backlog of settings in one sentence; this expands each into the one thing that earns it a slot.

---

## The one rule of this doc

From spec §9: **a good environment changes a rule; it does not change the wallpaper.** An environment that only swaps the background art is a cosmetic, not a level. So every entry below leads with the single rule it breaks — because *the rule is the obstacle*. If an idea can't name the rule it changes, it isn't ready.

Each entry uses this shape:

- **Rule it breaks** — the one assumption about how a toilet works that this venue violates.
- **The obstacle that creates** — what the player now has to *do* differently.
- **Meters** — which of the four (Relief · Composure · Discretion · Cleanliness) it leans on.
- **Hazards** — what it reuses from the catalog vs. the new system it needs.
- **Build cost** — 🟢 cheap (tuning + reskin) · 🟡 one new system/operator · 🔴 several new systems.
- **Status** — **Launch** (in the 20-level curriculum) · **Backlog** (named in spec §9) · **New** (born here).

---

## Launch environments (recap)

Fully specced in the [Difficulty Curve](poo-sim-difficulty-curve.md); listed here only for the rule each one owns.

| Environment | Rule it owns | Status |
|---|---|---|
| **Work Bathroom** | You must play *quiet* — a lowered safe-push cap (The Neighbor). | Launch · W1 |
| **Festival Porta-Potty** | Your thumb has too much to do — periodic taps steal time from The Push. | Launch · W2 |
| **Gas Station** | You start compromised and greed clogs the bowl — the first hard-fails. | Launch · W3 |
| **Airplane** | The world moves — turbulence shoves the needle and the Flow Zone. | Launch · W4 |

---

## Early-game tier

Gentle rooms for a new player's first minutes. They teach one idea with a heavy telegraph and no hard-fail.

### Work Bathroom — *the classroom* · Launch
Already World 1. The calm, enclosed room where The Push and quiet play are taught. See the curriculum.

### Co-ed Bathroom — *"the audience keeps changing"* · New
> *Suggested as an early level — a Work-world sibling with a social twist.*
- **Rule it breaks:** you can't assume who's in the room. A shared sink area means occupants **rotate**, so there's no stable "safe" moment to rely on — you learn to *read the room before you commit to a push*.
- **The obstacle:** the quiet-band cap isn't fixed; it shifts as people come and go, and a "someone notable just walked in" beat can spike the stakes without warning. Gentle version of Discretion pressure — a soft introduction to reading, not reacting.
- **Meters:** Discretion (primary), Composure.
- **Hazards:** reuses **The Neighbor** (variable cap) + a light **Waiter**-style churn of entrants. Optional later escalation: **The Peeker** (the stall-door gap — a backlog hazard in the catalog).
- **Build cost:** 🟢 (Neighbor variant + a rotating cap).
- **Open:** needs its distinct comedic hook nailed down so it doesn't read as "Work Bathroom 2." Candidate: the awkward-eye-contact-at-the-sink gag.

---

## The backlog, grouped by the rule they break

### A. Gate *when* you can push — cover-noise windows

A new system: an external noise source that periodically makes loud play safe (or silence makes it deadly). Turns The Push into a **timing/rhythm** game — bank Relief in the safe windows, freeze in the rest. One system, two opposite venues.

#### ⛪ Church / Library / Quiet Car — *"push only under cover"* · New
- **Rule it breaks:** you cannot push above a whisper *except* during bursts of ambient noise — the organ swells, the choir stands, the train clatters over a junction. In the silence between, any real push is instant detection.
- **The obstacle:** watch/listen for the cover window, slam your progress in during it, and hold perfectly still the rest of the time.
- **Meters:** Discretion (brutal threshold), Composure (freezing bleeds the clock).
- **Hazards:** needs a new **Cover Window** event (temporarily lifts the safe-push cap); pairs with a very high `detect_threshold`.
- **Build cost:** 🟡 (one new scheduled event type).
- **Why it's a standout:** the single biggest *mechanical* unlock in this doc — a genuinely new way to play The Push.

#### 🎸 Rave / Main-Stage Porta-Potty — *the exact inverse* · New
- **Rule it breaks:** the bass is so loud nobody can hear anything — push as hard as you like — **until the song ends** and three seconds of crowd-quiet makes every sound audible.
- **The obstacle:** the same Cover Window system, inverted: the danger is the *gap between songs*. Punishes the player who forgets the music will stop.
- **Meters:** Discretion (spikes in the gaps), Relief (free to floor it otherwise); constant low **Jolt** from the bass.
- **Hazards:** reuses the Cover Window system + a sustained Jolt.
- **Build cost:** 🟡 (reuses the church system; ship the two as a pair).

### B. Invert the Push physics

#### 🚀 Space Station / Zero-G — *"release doesn't lower the needle"* · Backlog
- **Rule it breaks:** with no gravity, letting go no longer relaxes you — the needle **floats** where you left it. You must actively drive it both up *and* down. Everything the player internalized about the control inverts.
- **The obstacle:** two-directional control; a suction system instead of a gravity drop.
- **Meters:** Relief (via harder control), Cleanliness (a slip in zero-G is a floating catastrophe — brutal).
- **Hazards:** mostly reuses existing hazards under new physics; Cleanliness fail is severe.
- **Build cost:** 🟢 (largely a flip of the `gravity`/`damping` tuning constants + reskin — cheapest "whoa, different" per line).

#### 🚢 Cruise Ship / Ferry in a Swell — *"the world rolls"* · Backlog
- **Rule it breaks:** a slow, continuous sine-wave sway moves the whole gauge — Airplane's rhythmic, predictable cousin rather than sharp jolts.
- **The obstacle:** ride the roll; seasickness couples to Composure.
- **Meters:** Relief (control), Composure.
- **Hazards:** a sustained **Jolt** variant.
- **Build cost:** 🟢.

### C. Redefine what "getting caught" means

#### 🌲 The Woods / Camping — *"there are no walls"* · Backlog
- **Rule it breaks:** Discretion stops being noise and becomes **line-of-sight**. A hiker crests the trail on a timer — finish or freeze before they see you.
- **The obstacle:** exposure windows (the Knock reskinned as being *seen*); and since you're squatting, holding position itself burns Composure faster the longer you dawdle.
- **Meters:** Discretion (as sightline), Composure (the squat burn).
- **Hazards:** reuses **The Knock** (as exposure) + a Composure-drain-over-time modifier (kin to Dead Leg).
- **Build cost:** 🟡.

#### 🍽️ Fancy Restaurant / Wedding — *"marble amplifies everything"* · Backlog
- **Rule it breaks:** polished acoustics multiply your Noise contribution — every sound counts double — and a bathroom attendant standing *right there* keeps Discretion pressure constant.
- **The obstacle:** an even lower noise tolerance than the Work Bathroom, plus a tip/social beat.
- **Meters:** Discretion (multiplied noise).
- **Hazards:** a Noise multiplier + an attendant (Waiter/Neighbor hybrid) + the recognizable-shoes gag.
- **Build cost:** 🟢.

#### 🛝 Playground Porta-Potty — *"the clock is the tell"* · New
> **Read the warning first:** this is the Festival Porta-Potty's box, wobble and Empty Roll. Without the rule below it is **wallpaper** — the exact failure §9's selection principle exists to prevent. It ships with the rule or it doesn't ship.
- **Rule it breaks:** Discretion stops measuring *noise* and starts measuring **elapsed time**. Nobody out there can hear you over the kids — but you are a parent who walked away from a birthday party, and the longer the door stays shut the more the outside world wonders where you went. Going quiet buys you nothing; only *finishing* does.
- **The obstacle:** it kills the turtle strategy from a new direction. Dead Leg punishes stalling through Composure, which the player can nurse; here stalling is *directly* the thing that exposes you, so every defensive "wait it out" answer they've learned in ten levels is actively wrong.
- **Meters:** Discretion (driven by duration, not sound), Composure.
- **Hazards:** reuses the Festival kit — **Jolt** (kids rocking the unit), **The Broken Latch**, **Empty Roll** — over a Discretion drain keyed to elapsed time rather than Noise. The escalating "where'd you go?" beat is **The Waiter** with the queue outside replaced by your own party.
- **Build cost:** 🟢 (retarget the Discretion input on an existing level kit).
- **Framing note:** play it as *the parent who ducked out of the party* — the anxiety is social absence, not suspicion. The "lone adult lingering at a playground" read is one step away and is not a joke this game should be making; the birthday-party framing keeps the duration rule and drops that entirely.

### D. Couple two meters together

#### 🏥 Hospital — *"your panic gives you away"* · Backlog
- **Rule it breaks:** you're wired to a heart-rate monitor whose beeping **is** your noise source. As Composure drops, Discretion bleeds with it — losing your nerve literally makes you louder.
- **The obstacle:** a feedback loop the player hasn't met — staying calm is now a Discretion strategy, not just a clock.
- **Meters:** Composure ↔ Discretion (coupled).
- **Hazards:** a small coupling term (low Composure → Discretion drain) + a nurse doing rounds (scheduled Knock).
- **Build cost:** 🟡 (conceptually the most novel rule here).

### E. Add a "don't move" constraint

#### 🚽 Automatic / Sensor Toilet — *"the toilet has opinions"* · New
- **Rule it breaks:** an aggressive auto-flush fires on its own, and the motion sensor means *dodging another hazard* (leaning to swipe a Smell Cloud, shifting off a splash) can **trip a flush** that interrupts your Relief.
- **The obstacle:** it taxes every *other* reaction — your existing hazards now fight each other. Near-free novelty from content you already have.
- **Meters:** Relief (interrupted), Discretion (the flush is loud).
- **Hazards:** a new **Sensor Flush** emergent hazard triggered by large swipes/leans.
- **Build cost:** 🟡.

### F. Remove a resource

#### 🏰 Medieval Garderobe — *"no flush, and a very long drop"* · Backlog
- **Rule it breaks:** no plumbing means no clog and no flush — but the long drop delays the smell, which rises back up on a timer; and a shared medieval privy can seat a permanent occupant on *both* sides.
- **The obstacle:** a delayed-Smell mechanic and possibly a double Neighbor.
- **Meters:** Discretion (delayed smell), Cleanliness (reframed — nothing to clean, but exposure to the elements).
- **Hazards:** a delayed **Smell Cloud** variant; optional double **Neighbor**. A castle-under-siege reskin makes the arrow-storm a **Jolt**.
- **Build cost:** 🟡. (More flavor-forward than the others — validate the rule holds up.)

### G. Publish the schedule

#### 🏫 High School Bathroom — *"you can see it coming"* · New
- **Rule it breaks:** every other room hides its schedule — hazards arrive and you react. Here the bell schedule is **posted on the wall and counting down**. The passing period isn't a wave to dodge, it's a wall: the room goes from empty to forty kids in one second, on a clock the player can read from the first frame.
- **The obstacle:** the sit becomes a *planning* problem before it's a reaction problem — budget the whole run against a visible countdown, and decide early whether to floor it and eat the noise or ration and hope. Getting caught out isn't a knock; it's the room filling around you.
- **Meters:** Composure (the countdown *is* the clock), Discretion (tolerance collapses to near-zero once the room fills).
- **Hazards:** all existing. **The Announcement** as the bell — the same deadline event, only revealed in advance; a burst of **The Waiter** / **The Neighbor** through the passing period; the doorless-stall gag is **The Broken Latch** with the drift taken out — it simply never shuts.
- **Build cost:** 🟡 — the events are ones we have; what's new is the *telegraph* (a schedule readout, and event fire-times exposed to the HUD). Still a seeded event per spec §17; we're only showing the player when it lands.
- **Why it earns a slot:** it's the one level where the right play is decided before you push. Every other room teaches reading the moment; this one teaches spending a run.
- **Open:** does a visible countdown collide with the **Cover Window** levels? The bet: Church/Rave telegraph a window you react *into*, seconds ahead — the bell telegraphs the whole run from t=0. If playtest says they feel the same, the bell needs a second beat of its own.

### H. Take away the reset

#### 🧟 Zombie Apocalypse — *"noise never forgives"* · New
> Absorbs the *haunted house* one-liner from spec §9 — same comedy register, with an actual rule under it.
- **Rule it breaks:** everywhere else, Discretion recovers — go quiet and the pressure recedes. The horde doesn't forget. Noise is **cumulative and one-way**: every sound ratchets the safe-push cap permanently tighter, and the horde converges on your running total.
- **The obstacle:** the run becomes a *budget* rather than a threshold. You're not staying under a line moment to moment — you're spending a fixed noise allowance across the whole sit, and every loud second bought early is one you won't have at the end, when you still have to finish *and* get out.
- **Meters:** Discretion (as a one-way ratchet), Composure (the horde's arrival is the deadline).
- **Hazards:** no new hazard type. **The Neighbor** supplies the cap — it now only ever tightens instead of flexing; **The Announcement** is the horde arriving as a hard deadline; the barricade beat is **The Broken Latch** with something worse on the other side.
- **Build cost:** 🟢–🟡 (a monotonic accumulator on the existing Noise contribution, stepping the safe-push cap down in bands — no new meter, no new operator).
- **Why it earns a slot:** the cheapest *strategic* change in this doc. The Push doesn't change and the hazards don't change; what changes is that mistakes stop being survivable, and that reframes the whole risk calculus from one accumulator.
- **Open:** does the ratchet read as a new meter (§2's complexity budget)? The bet: it isn't one — the player still watches Discretion, which now has a floor that only rises. If it needs its own horde-proximity readout to be legible, that's a budget conversation.

### I. Move the finish line

#### 🏡 Guest Bathroom at a Friend's House — *"finishing isn't winning"* · New
- **Rule it breaks:** every other level is decided during **② The Sit**, and **③ The Getaway** is a 3–5s seasoning beat (spec §3). Here that inverts: hitting 100% Relief is the *halfway* point, because you have to walk back out and sit with these people. The evidence outlives you — no fan, no window, a flush that's the loudest thing in a quiet house, and a smell on a timer in a room the next guest is walking into.
- **The obstacle:** a real second act. Once Relief closes, the meters that matter flip to Cleanliness and Discretion, and the choices are all lose-lose: flush now (loud, and everyone in the living room hears the second one) or wait it out (quiet, but the clock is running); use the decorative hand towel nobody has ever used; deal with a **Clog Risk** you cannot ask for help with. Every other room lets you leave the mess behind. This one makes you host it.
- **Meters:** Cleanliness and Discretion (both come due *after* Relief), Composure (the second-act clock).
- **Hazards:** reuses **Clog Risk** (as an unaskable social catastrophe rather than a fail state), **Smell Cloud** on a delay, **The Knock** ("you okay in there?" from someone who likes you), **Empty Roll** at its most humiliating.
- **Build cost:** 🟡 — no new hazard, but The Getaway has to grow from one choice into a scored phase, which touches the level flow rather than just tuning.
- **Why it earns a slot:** it's the only entry that changes the *shape of a run* instead of the shape of the push. It also cashes in Cleanliness, our least-exercised meter, as a headline rather than a footnote.
- **Supersedes:** the **first date's apartment (thin walls)** one-liner in spec §9 — same house, sharper rule. Keep the date version as the harder sibling: identical structure, tighter thresholds, plus someone whose opinion you actually care about.
- **Open:** the 60–90s budget and the 80/20 split (§3). A scored Getaway spends seconds The Sit currently owns — either this level runs a shorter Sit, or it's the one level allowed to break the ratio, and that's a deliberate call not an accident.

---

## Recommended prototype order

1. **Church + Rave (the cover-window pair)** — one new system, two levels that feel unlike anything else. Biggest mechanical unlock. 🟡
2. **Automatic / Sensor Toilet** — turns the existing four hazards against each other; huge novelty for one new operator. 🟡
3. **Space Station / Zero-G** — cheapest dramatic change; mostly a physics-constant flip. 🟢
4. **Hospital** — the meter-coupling rule, if we want to prove a genuinely new *kind* of mechanic. 🟡

Everything else is 🟢 reskins/variants we can slot in once the core hazard set is richer.

---

## Notes for the other docs

- Several entries imply **new hazards not yet in the [Hazard Catalog](poo-sim-hazard-catalog.md)**: Sensor Flush, line-of-sight exposure, the Composure↔Discretion coupling, delayed Smell. When one gets greenlit, add it to the catalog in the catalog's entry shape (it already lists **The Peeker**, **The Draft**, **The Floater**, **Weak Flush** as backlog hazards). The **Cover Window / Hush** has since been greenlit, built, and cataloged — the model for that promotion.
- **Groups G and H deliberately add no new hazard** — each is an existing hazard with one constant changed (a fire time revealed in advance; a cap that only tightens). If either ships, record it as a variant note on the parent hazard's entry rather than as a new catalog line.
- New environments still obey the **Complexity Budget** (spec §2): no new meters, one decision at a time, explainable in a sentence.
- Determinism/hazards-as-sabotage rules still apply — any new system fires from a seeded **event**, never a hardcoded timer (spec §17).

---

## Open questions

- [ ] **Co-ed bathroom's distinct hook** — what stops it reading as a second Work Bathroom?
- [ ] **Cover-window readability** — can a player reliably *see* a safe window coming on a phone screen, or does it need an audio-led telegraph?
- [ ] **Zero-G control** — does two-directional drive stay one-thumb-friendly, or does it break the one-hand pillar?
- [ ] **The bell vs. the cover window** — does a run-long visible countdown play differently from a seconds-ahead telegraphed window, or is High School just the Church with a clock on the wall?
- [ ] **The noise ratchet and the complexity budget** — is a one-way Discretion floor legible without a readout of its own, and would that readout be a fifth meter in all but name?
- [ ] **Does a scored Getaway fit the time budget** — or is the Guest Bathroom the one level that knowingly breaks the 80/20 Sit-to-bookend ratio?
- [ ] **Which of these are launch+1 vs. far backlog** — this doc is a menu, not a commitment; pick the slate once the vertical slice proves the core.
