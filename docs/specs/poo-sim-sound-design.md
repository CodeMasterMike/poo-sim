# Poo Sim — Sound Design

*Companion to the main spec (§11 Art & Audio Direction). Pairs with the interactive demo `poo-sim-sound-demo.html`. Version 0.1.*

The spec is blunt about this: **sound is the comedy engine.** In a game this visually simple, the audio does most of the heavy lifting — it sells the gross-out, it telegraphs the hazards, and it turns a filling meter into a tiny drama. This is a priority budget line, not a polish-pass afterthought.

---

## The role of audio

Three jobs, in priority order:

1. **Deliver the comedy.** The laugh is almost always in the sound — the strained squelch, the disaster splash, the sad trombone of a failed run. Visuals set up the joke; audio is the punchline.
2. **Telegraph the game.** Every hazard has an **audio tell** that fires a beat before it needs a reaction, so a skilled player can play half by ear. The soundscape *is* readability.
3. **Build tension.** An adaptive underscore that tightens as Composure drains turns a 60-second sit into a nail-biter.

---

## The mute reality (read this first)

Most mobile sessions are played **with the sound off** — on the toilet, on the couch, in public. This is the single most important constraint on the whole audio design:

> **Audio always enhances; it never gates.** Every audio tell must have a visual twin. If a hazard is only announced by sound, a muted player is being treated unfairly.

This dovetails with the UI spec's color language: the orange "react now" prompt is the *visual* twin of every hazard's audio tell. Design them as a pair, always. A third channel — **haptics** — backs up the biggest moments (a buzz on The Buzz, a thud on each star stamp), and works even in a silent pocket.

So: build the audio to be *delightful when on* and *completely skippable when off.*

---

## The gross-out palette

The game is "full gross-out crude," but crude done wrong is just nauseating. The rule is **cartoon, not documentary:**

- Exaggerated, comedic foley — think classic cartoon squelches and boings, not realistic recordings. Distance from realism is what makes it funny instead of repulsive.
- **Restraint is the joke.** A single perfectly-timed sound lands far harder than a wet montage. Less is funnier.
- Keep it PG-13 crude — clever and silly, never genuinely disgusting. The moment a sound makes someone put the phone *down* instead of laughing, it's failed.
- Record real foley (celery, wet sponges, squeeze bottles — the standard tricks) and pitch/process it into cartoon territory.

**The act foley is confirmed in scope.** The "poo sounds" — the squelch cadence of The Push, the plops, the splash, the triumphant final release — are core content, not an optional layer. They're the loudest joke in the game, so they get real recording time and careful comedic timing. (They ride the dedicated Foley bus and the "Gross-Out" volume slider, so players who want them quieter still get full gameplay feedback.)

---

## The sound of The Push (core continuous audio)

The Push is the heart of the game, so it gets the richest continuous audio. **You should be able to hear where the needle is without looking.**

- **Force → pitch/intensity.** As you push harder, a base tone rises in pitch and thickness. The gauge has an audio shape.
- **Flow Zone = consonant & satisfying.** Land the needle in the green and a warm, in-tune sweetener fades in (a consonant harmony over the base). It *sounds* productive. This is the audio reward for good play.
- **Red Zone = strained & wrong.** Push into the red and a dissonant, buzzing edge creeps in, plus a warning creak. It sounds like effort about to go wrong — the ear tells you to back off before Splashback even fires.
- **The act itself** rides on top: a comedic squelch cadence tied to Relief progress — steady and satisfying in the Flow Zone, frantic and strained in the red.
- **Relief milestones** (25 / 50 / 75 / 100%) chime up in pitch — an ascending sense of nearly-there.

The demo lets you hold a pad and hear this zone-shift live.

---

## Meter audio

| Meter | Sound |
|---|---|
| **Composure** | The adaptive underscore itself (see Music). As it drains, the tempo climbs and layers stack — a nervous ticking becomes a pounding heartbeat. |
| **Discretion** | A sharp, dissonant **detection sting** the instant you're noticed — the "oh no" stab. Small ticks as it erodes toward the threshold. |
| **Cleanliness** | Wet consequence sounds — the splash, the ominous gurgle of a rising clog. |
| **Relief** | The milestone chimes and the final triumphant resolution. |

---

## Hazard audio tells

Every hazard fires a distinct, recognizable cue *just before* its reaction window, paired with its visual twin. The cues must be instantly distinguishable from each other in a busy mix.

| Hazard | Audio tell | Visual twin |
|---|---|---|
| The Knock | Three sharp door raps | Door shadow + rattle |
| The Neighbor | A pointed cough, then a muttered voiced grumble | Quiet-band overlay on the gauge |
| Smell Cloud | A rising waft-whoosh + a distant sniff | Green cloud drifting up |
| The Broken Latch | A slow creak as the door drifts | Door easing open |
| Empty Roll | A hollow cardboard *boop* | Bare tube reveal |
| Clog Risk | A gurgling drain + rising alarm | Bowl filling / clog meter |
| Splashback | A quick comedic *sploosh* | Splash flash |
| Questionable Seat | A squelchy *ugh* on contact | Grimy seat (setup) |
| The Waiter | Impatient foot-taps, a heavy sigh, and a voiced "come *on*…" | External patience timer |
| The Buzz | A phone rattle-buzz | Phone lights up |
| The Announcement | A PA *bing-bong* chime + garbled voice | Banner drops |
| Dead Leg | A pins-and-needles high sparkle | Numbness meter |
| Jolt / Turbulence | A low lurching rumble | Needle knocked / screen shake |
| Slippery Grip | A greasy slip-wobble (ambient, sustained) | Drifting needle |

The demo includes a bank of these so you can hear how distinct they are back-to-back.

---

## Voiced reactions

The NPCs get voice — little comedic vocal reactions that give the bathrooms personality: the Neighbor's disgusted mutters, the Waiter's escalating impatience, the boss's suspicious "…hello?" at the door, the flight attendant's clipped announcements. Voice is where a lot of the character (and the laughs) will come from.

The design rule that keeps this cheap and scalable: **keep it (mostly) non-verbal.** Grumbles, sighs, groans, gibberish mutters, and gasps carry the comedy without real dialogue — which means **almost no localization cost** and a huge library from a single short recording session. A few iconic semi-words ("*seriously?*", "come *on*") are fine sparingly, but the backbone is universal human noises. Gross-out reactions are funny in every language.

Voice runs on its own bus (below) so it ducks the music and sits clearly above the foley. A handful of variations per reaction prevents repetition fatigue across dozens of runs.

---

## Reaction feedback

The moment-to-moment "did I do that right" audio, which also feeds the scoring streak:

- **Perfect (in-window) reaction:** a bright, satisfying pluck. Chained perfect reactions **climb in pitch** with the Reaction Streak — the sound of a hot streak is itself a reward, and you *hear* the multiplier building.
- **Fumbled reaction:** a short, deflating *womp* — comedic, not punishing.
- The streak-break is audible: the pitch resets to the bottom, so losing a streak stings by ear.

---

## Prep & Getaway audio

The bookends are short, so their audio has to do a lot in very few seconds. Each is built around one idea.

### Prep — you can hear the clock being spent

The prep dilemma is that time costs you, so **make the cost audible.** A soft, steady tick runs under the whole prep screen — the same tick that later becomes the Composure underscore, introduced here at its calmest. It isn't tense yet; it's just *running*, and that's the point. The player learns the sound of their own clock before it ever threatens them. (Its visual twin is the Composure bar visibly draining, per the UI spec — so a muted player loses nothing.)

- **Prep tick** — a quiet metronomic pulse, one per second, locked to the draining Composure bar.
- **Card select** — a satisfying stamp as a prep action is chosen. Two picks, two stamps; the second lands a semitone higher, so a full loadout *sounds* resolved.
- **Card lockout** — a soft muted thud when the cap is reached and the remaining cards gray out. Non-punishing; just closed.
- **JUST GO** — a decisive whoosh that cuts the tick dead. Skipping should sound bold, not like a forfeit — it's a legitimate strategy and the audio shouldn't editorialize.
- **Target glint** — a tiny sparkle as each interactive prep target (the roll, the latch) highlights, pulling the ear toward what's worth checking.

### The Getaway — Discretion becomes a punchline

The exit's job is converting an abstract meter into a social consequence, and audio does most of that work. The reveal has **three tiers**, keyed to final Discretion:

| Discretion | What you hear |
|---|---|
| **High** (undetected) | Ambient room tone. Nobody looks up. The absence of sound is the reward. |
| **Mid** | A murmur, one pointed cough, a chair shifting. Somebody knows. |
| **Low** (detected) | A slow clap, a stifled laugh, a camera shutter. Full public humiliation, played for comedy. |

Then the choice lands:

- **WASH** — running water, a paper-towel yank, and a resolved chord. The virtuous option *sounds* virtuous; it's the audio equivalent of straightening your tie.
- **BOLT** — quick receding footsteps, a door swinging, and a single disapproving murmur sting. Funny, never shaming.

Both branches end on the same door-close, which doubles as the transition into the results card.

---

## Music

**Launch approach — keep it cheap.** For now, music is deliberately simple: one short looping track per environment plus a single "tense" variant that swaps in when Composure gets low. That's it — a base loop and a stressed loop, crossfaded. It's inexpensive to produce, light on memory, and still gives the game a pulse. Voice and foley are where the budget goes first; music can be lean at launch.

Even in the cheap version, keep two things: **ducking** (music briefly dips whenever a hazard tell or voice fires, so cues always cut through) and the **resolution stingers** (a triumphant victory-flush fanfare on a clean finish, a sad-trombone droop on a fail). Those two do most of the emotional work for very little cost.

**Later upgrade (not now).** When there's budget, the base/tense swap can grow into a proper **dynamic underscore**: tempo and layers that scale continuously with Composure (add hats → stressed bass → racing arp), a dedicated surge at the **Final Push** (~85% Relief), and per-hazard musical accents. Worth building the loops in stems now so this upgrade is a mix change later, not a re-score.

### Per-environment musical flavor

Even the cheap loops should carry each world's character:

| World | Musical character |
|---|---|
| Work Bathroom | Sparse and tense. Fluorescent hum, muffled office murmur, a nervous muted-synth tick. Quiet by design, so Discretion cues read. |
| Festival Porta-Potty | Muffled festival bass thumping through the walls, a wash of distant crowd, a heat-shimmer high whine. Chaotic energy. |
| Gas Station | A buzzing, flickering fluorescent, highway whoosh outside, a lonely radio bleed, a slow drip. Desolate and grimy. |
| Airplane Lavatory | Constant engine drone and rushing air, seatbelt-sign dings, muffled cabin PA. Pressurized and claustrophobic. |

---

## Results screen audio

Ties directly to the scoring reveal choreography:

- **Axis tally:** each score bar fills with a rising tick sequence — the classic arcade count-up.
- **Streak bonus:** an escalating chime as it adds on.
- **Star stamp:** each star lands on a heavy, ascending bass hit (C → E → G) with a bright accent and a haptic thud. This is the peak dopamine beat — give it weight.
- **Title slam:** a comedic brass/impact hit under the rank title.
- **Victory flush vs. fail:** triumphant fanfare for a clear, sad trombone for a fail. The fail sound should be funny enough to soften the loss.

---

## Mix & technical

- **Buses:** Music / SFX / Foley (gross-out) / UI / Ambience / Voice, each on its own bus for independent control and ducking.
- **Ducking:** a sidechain from hazard tells and UI onto Music, so critical cues always surface.
- **Latency:** touch-to-sound must be tight (< ~30 ms feel). The Push and reaction feedback live or die on responsiveness — budget for low-latency audio on mobile.
- **Middleware:** Godot's built-in audio buses can carry the whole game and keep the build lean — recommended for launch scope. FMOD/Wwise integration is an option if the adaptive-music system grows beyond what buses comfortably handle; not needed day one.
- **Voice count & memory:** cap simultaneous voices and stream long ambiences while keeping short one-shots in memory. Keep the audio memory footprint modest for mid-range phones.
- **Formats:** compressed (OGG/AAC) for music and ambience; short SFX as small PCM/compressed one-shots.

---

## Audio settings & accessibility

- Independent volume sliders: **Music, SFX, and a dedicated "Gross-Out" slider** (turn the wet foley down without losing the game feedback).
- **Clean Mode** toggle — swaps the crudest foley for tamer cartoon equivalents (boings, pops) for players (or public settings) who want the game without the ick.
- **Visual cues on** — every audio tell's visual twin can be emphasized for muted or hard-of-hearing players.
- **Haptics** — the third feedback channel; independently toggleable.
- **Captions** — brief on-screen labels for key sounds (e.g., "*knock*"), for full-mute accessibility.

---

## SFX inventory (build checklist)

For the audio designer, the concrete asset buckets:

- **The Push:** base tone (looped/synth), Flow-Zone sweetener, Red-Zone strain layer, warning creak, Relief milestone chimes ×4, completion resolve.
- **The act (poo foley) — priority:** squelch cadence (calm + strained), plops/variations, the splash, the triumphant final release. Recorded and pitched into cartoon territory; multiple takes to avoid repetition.
- **Voice (non-verbal, priority):** NPC grumbles, sighs, groans, gasps, and a few semi-words — Neighbor (disgust), Waiter (impatience), boss (suspicion), attendant (clipped) — several variations each. Mostly language-neutral to skip localization.
- **Prep:** clock tick (loopable, one per second), card stamp ×2 pitches, lockout thud, JUST GO whoosh, target glint.
- **Getaway:** three reveal tiers (ambient / murmur + cough / slow clap + shutter), WASH branch (water, towel yank, resolve chord), BOLT branch (receding footsteps, door swing, murmur sting), shared door-close transition.
- **Hazard tells:** all 14 from the table above (calm + escalated variants where they scale).
- **Reaction feedback:** perfect chime (pitch-laddered for streak), fumble womp, streak-break reset.
- **Meters:** detection sting, discretion erosion ticks, clog gurgle, splash.
- **Music (lean):** 4 environment loops, each with a base + "tense" variant (stems built for a later dynamic upgrade), victory flush, fail trombone.
- **Ambience:** 4 environment loops.
- **Results:** tally ticks, streak chime, 3× star bass hits, title slam, achievement pop.
- **UI:** menu taps, world unlock, star-gate locked/unlocked, button presses.

---

## Decisions locked

- **Music:** lean for launch — one loop + a "tense" variant per environment, built as stems so it can grow into a dynamic score later. ✅
- **Voiced reactions:** in — mostly non-verbal grumbles to keep localization near-zero. ✅
- **Poo foley:** confirmed core content, with real recording time. ✅

## Open questions

- [ ] **Gross-Out slider default:** ship at full crude, or default to medium so the store-listing first impression is broadly palatable?
- [ ] **How much actual dialogue** beyond grumbles — do any NPCs get real (localizable) lines, or stay 100% gibberish?
- [ ] **Music that reacts to The Push itself** (pitch of the act ties into the key of the track) — delightful, but a "later" nice-to-have given the lean music plan.
- [ ] **Haptics scope:** which moments truly need it, before it becomes battery-draining noise?
