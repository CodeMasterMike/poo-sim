class_name LevelDef
extends Resource
## Level schema: every scalar the sim reads, plus the event timeline.
##
## THE single source of tuning. It is a Resource with @export fields so the same
## numbers are editable in the inspector (and savable as a .tres) that the tests
## read via LevelDef.new() and the game reads at runtime. The view no longer
## mirrors these as its own @exports — that duplication meant tests could quietly
## validate different values than you were playing.
##
## To tune: edit the defaults here, or assign a .tres override on the Sit scene's
## `tuning_override`. Concrete levels are factories (scripts/content/) that fill
## in a LevelDef and its timeline.

# --- Needle physics ---
@export var push_accel: float = 2.2
@export var gravity: float = 1.6
@export var damping: float = 3.0
@export var max_speed: float = 1.5

# --- Flow zone (initial band set; more than one band = a split zone) ---
@export var flow_bands: Array[Vector2] = [Vector2(0.50, 0.72)]

# --- Relief fill (% per second) ---
## These three are ANCHORS on a continuous curve, not three flat rates (they used
## to be a step function of zone, which meant needle position inside the Flow band
## did nothing at all and every clean run finished in the same time). Each is the
## rate at NEUTRAL thickness — see `density_swing`.
##
## Sized to the spec's 45-75s sit (§3): perfect flow fills in ~45s, the greedy
## red line in ~29s. Dead-zone fill is a genuine crawl (~200s) so idling can
## never out-race Composure — doing nothing must lose, not win.
@export var fill_dead: float = 0.5   ## rate at needle 0
@export var fill_flow: float = 2.2   ## rate at the CENTRE of the Flow band
## Red must be a genuine temptation, not a trap. At 4.5 with the splash duty
## cycle below it nets ~3.4%/s — about 1.5x flow. (At 3.4 it netted *less* than
## flow once stalls were counted, so the greedy line was strictly dominated and
## nobody would ever take it.)
@export var fill_red: float = 4.5    ## rate at needle 1.0
## How much the rate varies ACROSS the Flow band, either side of `fill_flow`.
## At 0.25 the band's ceiling pays 2.75%/s and its floor 1.65%/s — so riding the
## top edge is a third faster, and the band stops being a flat plateau you can
## park in. 0 restores the old behaviour exactly.
@export var fill_flow_spread: float = 0.25

# --- Consistency ---
## The level's baseline consistency (0 = runny, 1 = solid) — what you ate. 0.5 is
## neutral and fills at exactly the anchor rates above, so a level that leaves
## this alone keeps its existing pacing to the decimal.
@export var thickness_base: float = 0.5
## How far sustained pressure shifts thickness off that baseline, per unit of
## needle away from the Flow band's centre. Bearing down extrudes thicker matter.
@export var thickness_push_gain: float = 0.9
## Per-second ease toward the target. The lag IS the mechanic: a flick into the
## red gets you the steeper rate curve but not the density bonus, because the
## matter hasn't had time to thicken. You only get thick by committing.
@export var thickness_ease: float = 0.8
## Fill-rate multiplier swing across the full thickness range, centred on 0.5.
## At 0.35: runny = 0.65x, neutral = 1.0x, solid = 1.35x.
@export var density_swing: float = 0.35

# --- Bowl physics (the settle; see PushSim._slump) ---
## Angle of repose, as the max height difference two neighbouring columns can
## hold. Runny is near zero, so it self-levels into a flat pool; solid holds a
## steep face and stacks into a mound under wherever the stream is landing.
##
## `repose_runny` has to be MUCH smaller than it looks like it needs to be: it is
## a per-column limit, so the profile can legally wedge by repose × columns end to
## end, and that wedge IS the equilibrium — the settle has no obligation to remove
## it. At 0.03 the bowl can legally sit at a 0.69 ramp, which reads as a slope, not
## a pool. 0.0015 caps the whole bowl at ~0.035 out of level.
@export var repose_runny: float = 0.0015
## `repose_solid` is tuned for READABILITY, not physical accuracy, and the two
## genuinely disagree here. The drawn cavity is about four times wider than it is
## deep, so a realistic ~35° heap spanning it would stand roughly three cavity-
## depths tall — a real toilet gets away with that because it has a narrow deep
## trap, and this cutaway is a wide shallow box.
##
## What matters is the peak at the end of a run. A point-source pile cones out
## over all 24 columns, and for a triangular profile peak ≈ mean + 6 × repose. At
## 100% Relief the mean is exactly the rim, so 0.06 finishes standing ~1.35 proud
## of it: mounded, clearly not a pool, still recognisably in the bowl. 0.13 (the
## physical figure) finished at 1.8 and was already over the rim by the halfway
## mark with half the bowl still bare.
@export var repose_solid: float = 0.06
## How fast the material relaxes toward that angle. Runny slumps almost at once;
## solid barely creeps, so a mound you build stays built.
@export var slump_relax_runny: float = 0.85
@export var slump_relax_solid: float = 0.22
# --- Where the stream lands (see PushSim._update_sway) ---
## The landing point wavers around the CENTRE of the bowl. It deliberately does
## not track needle height: aiming isn't what a harder push does, so force buys
## amplitude, not direction. These are offsets in bowl-widths either side of
## centre, and they add.
##
## This is also the environment hook the airplane wants — crank `sway_ambient`
## and `sway_turbulence` and the whole level is fighting a moving target, with no
## new system behind it.
@export var sway_ambient: float = 0.035     ## baseline waver, even at a gentle push
@export var sway_push: float = 0.10         ## extra amplitude at full-force push
@export var sway_turbulence: float = 0.17   ## extra while the room is shaking you
@export var sway_rate: float = 0.42         ## oscillations per second

# --- Red-zone risk ---
## 2.5s of strain means a short red burst is free, which makes red a tactical
## dip rather than a punish; sustained camping still splashes repeatedly.
@export var red_strain_time: float = 2.5   ## seconds camping red before a splash fires
@export var splash_stall_time: float = 0.5 ## seconds Relief is frozen after a splash

# --- Four-meter tuning ---
## 80s of Composure against a ~57s ideal fill. At 60 even a flawless run ran out
## of clock at ~92% Relief — the sit was literally unwinnable.
@export var composure_seconds: float = 80.0    ## full Composure lasts ~this long at flow baseline
@export var composure_drain_dead: float = 1.7  ## drain multiplier while in the dead zone
@export var composure_drain_red: float = 1.3   ## drain multiplier while in the red zone
@export var splash_cleanliness_hit: float = 12.0 ## Cleanliness lost per splash
## A 2s red burst should cost ~10 Discretion, not wipe the meter. At 20/s red
## emptied Discretion in five seconds flat.
@export var red_noise_rate: float = 5.0        ## Discretion lost per second camping red (noise)
## Ambient bleed over a full sit should be a nuisance (~-19), not most of the
## meter. At 1.0/s a flawless run still ended near zero, making the 300-point
## Discretion axis all but un-earnable.
@export var smell_rate: float = 0.35           ## Discretion lost per second (ambient smell)
@export var detect_threshold: float = 35.0     ## Discretion below this = a detection event

# --- Quiet-room silence penalty (Church cover-window levels; 0 disables) ---
## In a "quiet room", actively bearing down (holding) with the needle above
## `silence_push_cap` while no Cover Window is active is audible: Discretion bleeds
## at this rate (per second). Coasting back down after you release is free — cover
## windows don't telegraph their end. 0 = not a quiet room (every non-Church
## level), so the penalty is a no-op there.
@export var silence_noise_rate: float = 0.0
## The needle level above which you're audible in silence. Defaults to the Flow
## floor so that in silence you can idle low but a real (flow-level) push is heard —
## the whole point of the Church is that you push only under cover.
@export var silence_push_cap: float = 0.5
## Is the room audible (exposed) by default? An acoustic window (COVER slot) FLIPS
## this for its duration. Church = true: exposed by default, a cover window shields
## you. Rave = false: covered by default (the bass), a hush window exposes you. So
## the same window machinery drives both polarities — see Hazards.room_exposed.
@export var baseline_exposed: bool = true

# --- Smell Cloud (emergent hazard; emitted by hard pushing, not scheduled) ---
## At 0.5/s a cloud forms after ~2s in the red — roughly in step with the splash
## threshold, so a brief dip stays free but committing to the red line produces
## something you have to deal with.
@export var smell_charge_rate: float = 0.5   ## charge per second while pushing in the red
@export var smell_decay_rate: float = 0.25   ## charge bled off per second otherwise
@export var smell_telegraph: float = 1.2     ## the cloud drifting in (seconds)
@export var smell_window: float = 1.6        ## last-chance reaction window
@export var smell_cost: float = 18.0         ## Discretion lost if it lands unwafted
@export var swipe_min: float = 15.0          ## drag distance in one step that counts as a swipe

# --- Jolt ---
## How far a successful swipe drags the needle back toward the Flow band (0..1).
@export var jolt_recenter: float = 0.6

# --- Timeline (SimEvent is RefCounted, so this is runtime-only, not exported) ---
var timeline: Array[SimEvent] = []


## Fix every event's trigger point for this match, rolling any jitter from the
## match-seeded RNG. Call once, after the SimClock exists and before the
## scheduler loads the timeline. Iterating in authored order keeps the RNG pull
## sequence deterministic.
func resolve_timeline(fixed_dt: float, rng: RandomNumberGenerator) -> void:
	for ev in timeline:
		ev.resolve(fixed_dt, rng)
