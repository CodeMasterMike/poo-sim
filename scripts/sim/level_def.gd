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
@export var fill_red: float = 3.4

# --- Red-zone risk ---
@export var red_strain_time: float = 1.5   ## seconds camping red before a splash fires
@export var splash_stall_time: float = 0.5 ## seconds Relief is frozen after a splash

# --- Four-meter tuning ---
@export var composure_seconds: float = 60.0    ## full Composure lasts ~this long at flow baseline
@export var composure_drain_dead: float = 1.7  ## drain multiplier while in the dead zone
@export var composure_drain_red: float = 1.3   ## drain multiplier while in the red zone
@export var splash_cleanliness_hit: float = 12.0 ## Cleanliness lost per splash
@export var red_noise_rate: float = 20.0       ## Discretion lost per second camping red (noise)
@export var smell_rate: float = 1.0            ## Discretion lost per second (ambient smell)
@export var detect_threshold: float = 35.0     ## Discretion below this = a detection event

# --- Timeline (SimEvent is RefCounted, so this is runtime-only, not exported) ---
var timeline: Array[SimEvent] = []


## Fix every event's trigger point for this match, rolling any jitter from the
## match-seeded RNG. Call once, after the SimClock exists and before the
## scheduler loads the timeline. Iterating in authored order keeps the RNG pull
## sequence deterministic.
func resolve_timeline(fixed_dt: float, rng: RandomNumberGenerator) -> void:
	for ev in timeline:
		ev.resolve(fixed_dt, rng)
