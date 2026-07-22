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

# --- Relief fill (% per second, by zone) ---
## Sized to the spec's 45-75s sit (§3): perfect flow fills in ~45s, the greedy
## red line in ~29s. Dead-zone fill is a genuine crawl (~200s) so idling can
## never out-race Composure — doing nothing must lose, not win.
@export var fill_dead: float = 0.5
@export var fill_flow: float = 2.2
## Red must be a genuine temptation, not a trap. At 4.5 with the splash duty
## cycle below it nets ~3.4%/s — about 1.5x flow. (At 3.4 it netted *less* than
## flow once stalls were counted, so the greedy line was strictly dominated and
## nobody would ever take it.)
@export var fill_red: float = 4.5

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

# --- Smell Cloud (emergent hazard; emitted by hard pushing, not scheduled) ---
## At 0.5/s a cloud forms after ~2s in the red — roughly in step with the splash
## threshold, so a brief dip stays free but committing to the red line produces
## something you have to deal with.
@export var smell_charge_rate: float = 0.5   ## charge per second while pushing in the red
@export var smell_decay_rate: float = 0.25   ## charge bled off per second otherwise
@export var smell_telegraph: float = 1.2     ## the cloud drifting in (seconds)
@export var smell_window: float = 1.6        ## last-chance reaction window
@export var smell_cost: float = 18.0         ## Discretion lost if it lands unwafted
@export var swipe_min: float = 15.0          ## drag distance in one step that counts as a waft

# --- Timeline (SimEvent is RefCounted, so this is runtime-only, not exported) ---
var timeline: Array[SimEvent] = []


## Fix every event's trigger point for this match, rolling any jitter from the
## match-seeded RNG. Call once, after the SimClock exists and before the
## scheduler loads the timeline. Iterating in authored order keeps the RNG pull
## sequence deterministic.
func resolve_timeline(fixed_dt: float, rng: RandomNumberGenerator) -> void:
	for ev in timeline:
		ev.resolve(fixed_dt, rng)
