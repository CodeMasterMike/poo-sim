class_name SimState
extends RefCounted
## The mutable simulation model. The UI only READS this — it is never stored
## canonically inside Control nodes (spec §17 guardrail 3). It is also the exact
## surface you would snapshot to sync a match or record a ghost, so it holds no
## Node references and no view-only state (screen shake, flashes live in the view).

enum Phase { PLAYING, WON, LOST }

## Identifies a meter for timeline/hazard events that nudge a value directly.
enum Meter { RELIEF, COMPOSURE, DISCRETION, CLEANLINESS }

# --- Needle / The Push ---
var needle: float = 0.0        ## 0 = bottom, 1 = top
var needle_vel: float = 0.0

# --- Flow zone as bands, not a scalar. Each Vector2(low, high). One band today;
#     a "split" is simply two elements — no reshape needed later. `target` is what
#     the current bands lerp toward, so timeline events can shift/narrow smoothly. ---
var flow_bands: Array[Vector2] = []
var flow_target_bands: Array[Vector2] = []
var flow_ramp_rate: float = 0.0   ## per-second lerp rate toward target (0 = snap)

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


func flow_ratio() -> float:
	return 0.0 if total_fill <= 0.0 else flow_fill / total_fill


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
