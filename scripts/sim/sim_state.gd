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

# --- The Knock (hazard runtime). KnockHazard operates on these primitives so
#     SimState stays pure data and never references the hazard class (no cycle). ---
var knock_phase: int = 0        ## KnockHazard.Phase (0 = IDLE)
var knock_timer: float = 0.0    ## seconds left in the current knock phase
var knock_freeze_len: float = 0.0
var knock_cost: float = 0.0     ## Discretion craters by this on a failed freeze
var knock_failed: bool = false  ## did a push land during the freeze?

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
