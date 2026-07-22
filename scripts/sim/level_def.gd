class_name LevelDef
extends RefCounted
## Level schema: every scalar the sim reads plus the event timeline. Pure data,
## no baked content — concrete levels are factories (scripts/content/*) that
## return a filled-in LevelDef, so a "match" just takes one of these (guardrail 5).
##
## For the grey-box prototype the view fills these from live-tune @exports so the
## feel loop (nudge a value, replay) still works in the remote inspector. When
## real content lands this can become a Resource loaded from .tres.

# --- Needle physics ---
var push_accel: float = 2.2
var gravity: float = 1.6
var damping: float = 3.0
var max_speed: float = 1.5

# --- Flow zone (initial band set) ---
var flow_bands: Array[Vector2] = [Vector2(0.50, 0.72)]

# --- Relief fill (% per second, by zone) ---
var fill_dead: float = 4.0
var fill_flow: float = 14.0
var fill_red: float = 22.0

# --- Red-zone risk ---
var red_strain_time: float = 1.5   ## seconds camping red before a splash fires
var splash_stall_time: float = 0.5 ## seconds Relief is frozen after a splash

# --- Four-meter tuning ---
var composure_seconds: float = 60.0    ## full Composure lasts ~this long at flow baseline
var composure_drain_dead: float = 1.7  ## drain multiplier while in the dead zone
var composure_drain_red: float = 1.3   ## drain multiplier while in the red zone
var splash_cleanliness_hit: float = 12.0 ## Cleanliness lost per splash
var red_noise_rate: float = 20.0       ## Discretion lost per second camping red (noise)
var smell_rate: float = 1.0            ## Discretion lost per second (ambient smell)
var detect_threshold: float = 35.0     ## Discretion below this = a detection event

# --- Timeline ---
var timeline: Array[SimEvent] = []


## Snap every event's authoring time onto the integer step grid. Call once at load.
func resolve_timeline(fixed_dt: float) -> void:
	for ev in timeline:
		ev.resolve_step(fixed_dt)
