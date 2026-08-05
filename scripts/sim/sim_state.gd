class_name SimState
extends RefCounted
## The mutable simulation model. The UI only READS this — it is never stored
## canonically inside Control nodes (spec §17 guardrail 3). It is also the exact
## surface you would snapshot to sync a match or record a ghost, so it holds no
## Node references and no view-only state (screen shake, flashes live in the view).

enum Phase { PLAYING, WON, LOST }

## Identifies a meter for timeline/hazard events that nudge a value directly.
enum Meter { RELIEF, COMPOSURE, DISCRETION, CLEANLINESS }

## How many columns the bowl's contents are modelled as. A heightfield, not a
## particle sim — see PushSim._slump for why engine physics is off the table.
## 24 is enough to read as a mound and cheap enough to settle every tick.
const BOWL_COLUMNS: int = 24

# --- Needle / The Push ---
var needle: float = 0.0        ## 0 = bottom, 1 = top
var needle_vel: float = 0.0

# --- Flow zone as bands, not a scalar. Each Vector2(low, high). One band today;
#     a "split" is simply two elements — no reshape needed later. `target` is what
#     the current bands lerp toward, so timeline events can shift/narrow smoothly. ---
var flow_bands: Array[Vector2] = []
var flow_target_bands: Array[Vector2] = []
var flow_ramp_rate: float = 0.0   ## per-second lerp rate toward target (0 = snap)

# --- Consistency, and what's landed ---
## 0 = runny, 1 = solid. The level seeds a baseline (what you ate) and sustained
## pressure shifts it; PushSim eases it toward that target rather than snapping,
## so thickness has inertia. Thicker matter is denser, so more of you leaves per
## second — and it stacks at a steeper angle once it lands.
var thickness: float = 0.5

## The bowl's contents as a heightfield: one entry per column, in units where
## 1.0 = filled to the rim. Sum over the columns == BOWL_COLUMNS at 100% Relief,
## so the pile is exactly the Relief you earned, redistributed by how it settled.
## Plain floats on purpose — this snapshots for a ghost or a mirrored board the
## same way every other field here does.
var bowl: PackedFloat32Array = PackedFloat32Array()

## Where the stream is landing, as an offset either side of the bowl's centre.
## It is never a function of how HIGH the needle is — pushing harder doesn't aim
## you sideways, it just makes you a worse nozzle — so this wanders around the
## middle, wider the harder you push and wider again when the room shakes you.
var sway: float = 0.0
var sway_clock: float = 0.0   ## sim-time driving the waver; replays exactly

# --- The four meters (all 0..100; "fuller is better" for every one) ---
var relief: float = 0.0        ## win condition — fill to 100
var composure: float = 100.0   ## time/urgency; only drains; empty = LOST
var discretion: float = 100.0  ## noise + smell; high = undetected
var cleanliness: float = 100.0 ## splashback/mess; high = spotless

# --- Risk state ---
var strain: float = 0.0        ## 0..1, builds while camping the red zone
var splash_stall: float = 0.0  ## Relief frozen while > 0 (the mess cost)
var splash_pulse: int = 0      ## increments on each splash — the view watches this
                               ## to fire its flash/shake without owning sim state

var phase: Phase = Phase.PLAYING

# --- In-flight hazards. One generic slot type serves the whole catalog, so new
#     hazards never add fields here. SimState references only HazardSlot (pure
#     data), never the hazard operators — that keeps it acyclic. ---
var hazards: Array[HazardSlot] = []

## Bumped when a hazard retires — the view watches this (like splash_pulse) to
## fire its pass/fail feedback without the sim holding view state.
var hazard_resolve_pulse: int = 0
var last_hazard_kind: int = 0
var last_hazard_failed: bool = false
var hazards_passed: int = 0
var hazards_failed: int = 0

## 0..1. Builds while pushing hard, bleeds off otherwise; at 1.0 PushSim emits a
## Smell Cloud and resets it. This is what makes that hazard a consequence of how
## you played rather than something the timeline does to you.
var smell_charge: float = 0.0

# --- Scoring accumulators (read at end-of-run by Scoring) ---
var composure_start: float = 100.0
var flow_fill: float = 0.0     ## Relief earned inside a flow band
var total_fill: float = 0.0    ## total Relief earned (denominator of Flow Ratio)
var detection_count: int = 0   ## times Discretion crossed the detect threshold
var detected_low: bool = false ## edge tracker so one dip counts once


func _init() -> void:
	bowl.resize(BOWL_COLUMNS)


func flow_ratio() -> float:
	return 0.0 if total_fill <= 0.0 else flow_fill / total_fill


## Total matter in the bowl, in column-heights. Equals BOWL_COLUMNS at 100%
## Relief — the settle only ever moves matter sideways, never creates it.
func bowl_mass() -> float:
	var total := 0.0
	for v in bowl:
		total += v
	return total


## The tallest column, in rim-fractions. > 1.0 means the pile is standing proud
## of the rim — nothing acts on that yet, but it is the hook an overflow rule
## would read.
func bowl_peak() -> float:
	var peak := 0.0
	for v in bowl:
		peak = maxf(peak, v)
	return peak


## Apply a signed delta to a meter (timeline/hazard events use this). Clamped.
func apply_meter(meter_id: int, delta: float) -> void:
	match meter_id:
		Meter.RELIEF:
			relief = clampf(relief + delta, 0.0, 100.0)
		Meter.COMPOSURE:
			composure = clampf(composure + delta, 0.0, 100.0)
		Meter.DISCRETION:
			discretion = clampf(discretion + delta, 0.0, 100.0)
		Meter.CLEANLINESS:
			cleanliness = clampf(cleanliness + delta, 0.0, 100.0)
