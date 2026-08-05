class_name SimState
extends RefCounted
## The mutable simulation model. The UI only READS this — it is never stored
## canonically inside Control nodes (spec §17 guardrail 3). It is also the exact
## surface you would snapshot to sync a match or record a ghost, so it holds no
## Node references and no view-only state (screen shake, flashes live in the view).

enum Phase { PLAYING, WON, LOST }

## Identifies a meter for timeline/hazard events that nudge a value directly.
##
## RELIEF is RESERVED, not usable — see apply_meter. Its ordinal stays put anyway,
## for the same reason SimEvent.Kind never reslots: a serialized level or ghost
## holding a `2` has to keep meaning DISCRETION.
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

## The consistency of what's ALREADY IN the bowl — a mass-weighted mean of every
## deposit — as opposed to `thickness`, which is what's at the exit right now.
##
## They have to be separate. The settle reads this one, and it used to read
## `thickness`: since letting go drives `thickness` to runny, a firm mound you had
## built would liquefy and slump flat the moment you stopped pushing. Matter in the
## bowl does not re-grade itself because you paused.
##
## Meaningless until the first deposit, which sets it outright (there is no mass to
## weight against).
var bowl_thickness: float = 0.5

## Where the stream is landing, as an offset either side of the bowl's centre.
## It is never a function of how HIGH the needle is — pushing harder doesn't aim
## you sideways, it just makes you a worse nozzle — so this wanders around the
## middle, wider the harder you push and wider again when the room shakes you.
var sway: float = 0.0
var sway_clock: float = 0.0   ## sim-time driving the waver; replays exactly

## How close the bowl is to done, 0..100 — the pile's peak measured against the
## goal line. THIS is what ends the run, not `relief`.
##
## The two differ on purpose. `relief` is mass evacuated; `progress` is how high
## what came out actually stands. A firm, well-aimed pile stacks and reaches the
## line on less mass; a runny one spreads flat and needs more. That's the payoff
## for the whole consistency model — how you played decides how much you need.
##
## A high-water mark, so it never runs backwards when the pile settles. Resting
## already costs Composure; watching the meter fall too reads as being punished
## twice for one pause.
var progress: float = 0.0

# --- The four meters (all 0..100; "fuller is better" for every one) ---
## How much has actually left you. Drives Flow Ratio and the timeline's own
## accounting; it is NOT the finish line any more — see `progress`.
var relief: float = 0.0
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


## A state seeded for a level, ready for the first tick.
##
## THE way to build one. The view and four test suites each grew their own copy of
## this, and they had already drifted — only some seeded `thickness` from the
## level's baseline, so the suites were ticking a sitter the game never produces.
## The meters aren't set here: their field defaults above already are the opening
## values, and repeating them was half of what let the copies disagree.
static func for_level(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	# Open at the level's OWN consistency, not the neutral default — otherwise every
	# sit starts the same and eases into its character a second later.
	s.thickness = level.thickness_base
	s.composure_start = s.composure
	return s


## The outer edges of the Flow Zone as (lowest floor, highest ceiling).
##
## One implementation of a loop that had been written out four times — in
## `zone_of`, in `_curve_rate`, in `band_centre`, and again in
## `QuietRoom.flow_floor`. Static so it serves a LevelDef's authored bands as well
## as a SimState's live (ramping) ones.
static func span_of(bands: Array[Vector2]) -> Vector2:
	if bands.is_empty():
		return Vector2(0.0, 0.0)
	var span := Vector2(bands[0].x, bands[0].y)
	for band in bands:
		span.x = minf(span.x, band.x)
		span.y = maxf(span.y, band.y)
	return span


## This state's live band span. The bands ramp, so this moves with them.
func band_span() -> Vector2:
	return span_of(flow_bands)


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
##
## RELIEF is refused. It stopped being a meter the moment Relief became mass
## evacuated into `bowl`: the number here is only the tally, the pile is the truth,
## and the run finishes on `progress` (the pile's HEIGHT) rather than on this. So a
## bare `relief +=` writes a figure the bowl does not back — and since the win still
## also trips at `relief >= 100`, a scripted `+100` ended the sit on the spot over a
## visibly empty bowl. A negative delta is worse: nothing takes matter back OUT of
## the heightfield, so it breaks the mass invariant the settle rests on.
##
## Granting progress is a real thing a level might want; it just has to arrive as
## matter, through PushSim's deposit path, not as a number poked in from outside.
func apply_meter(meter_id: int, delta: float) -> void:
	match meter_id:
		Meter.RELIEF:
			push_error("SimState.apply_meter: RELIEF is not directly settable — "
					+ "Relief is mass in `bowl`, so it must be deposited, not assigned.")
		Meter.COMPOSURE:
			composure = clampf(composure + delta, 0.0, 100.0)
		Meter.DISCRETION:
			discretion = clampf(discretion + delta, 0.0, 100.0)
		Meter.CLEANLINESS:
			cleanliness = clampf(cleanliness + delta, 0.0, 100.0)
