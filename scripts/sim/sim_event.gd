class_name SimEvent
extends RefCounted
## A typed, time-scheduled change to the sim. This is the one representation the
## scheduler consumes, so the same code path will later resolve level events,
## recorded-ghost events, and opponent sabotage alike (spec §17 guardrail 2).
##
## `time` is authoring convenience (seconds); `step` is the resolved integer
## trigger, snapped once at load — integer comparison is what keeps triggering
## deterministic (float `elapsed >= time` can fire a step early or late after
## drift). `payload` is a typed data object per kind, never a Dictionary bag, so
## every event's fields are validated at parse time.
##
## The Kind enum reserves hazard slots now, before their handlers exist, so
## serialized levels and ghosts stay forward-compatible.

## SMELL is appended rather than slotted in, so the existing ordinals stay put and
## any serialized level/ghost keeps meaning what it meant.
enum Kind { FLOW_ZONE, METER, PROMPT, KNOCK, JOLT, BUZZ, SMELL }

## What makes the event fire. TIME is the clock; RELIEF paces the beat off the
## player's actual progress, which is what the spec's three-act micro-curve wants
## ("random after ~30% Relief", the Final Push spike near 85%).
enum Trigger { TIME, RELIEF }

var time: float = 0.0
var step: int = 0
var trigger: int = Trigger.TIME
var relief_at: float = 0.0
## Randomizes the trigger point by +/- this much, rolled ONCE per match from the
## match-seeded RNG. Same seed rolls the same schedule (fair mirrored boards,
## reproducible ghosts); a different seed reshuffles the sit.
var jitter: float = 0.0
var kind: Kind = Kind.FLOW_ZONE
var payload: RefCounted = null


func _init(t: float, k: Kind, p: RefCounted) -> void:
	time = t
	kind = k
	payload = p


## Chainable authoring helpers: SimEvent.knock(...).on_relief(30.0).with_jitter(5.0)

func on_relief(pct: float) -> SimEvent:
	trigger = Trigger.RELIEF
	relief_at = pct
	return self


func with_jitter(j: float) -> SimEvent:
	jitter = j
	return self


## Fix the concrete trigger point for this match. Any jitter is rolled here, from
## the seeded RNG, so the schedule is decided once and is identical for a given
## seed. Time triggers also snap onto the integer step grid (comparing ints, not
## a drifting float clock, is what keeps firing reproducible).
func resolve(fixed_dt: float, rng: RandomNumberGenerator) -> void:
	var roll := 0.0
	if jitter > 0.0:
		roll = rng.randf_range(-jitter, jitter)
	if trigger == Trigger.RELIEF:
		relief_at = clampf(relief_at + roll, 0.0, 100.0)
		step = 0
	else:
		step = int(round(maxf(0.0, time + roll) / fixed_dt))


# --- Static factories: author events with typed payloads and full autocomplete ---

static func flow_zone(t: float, bands: Array[Vector2], ramp: float = 0.0) -> SimEvent:
	return SimEvent.new(t, Kind.FLOW_ZONE, FlowZonePayload.new(bands, ramp))


static func meter(t: float, meter_id: int, delta: float) -> SimEvent:
	return SimEvent.new(t, Kind.METER, MeterPayload.new(meter_id, delta))


static func prompt(t: float, text: String, hold: float) -> SimEvent:
	return SimEvent.new(t, Kind.PROMPT, PromptPayload.new(text, hold))


static func knock(t: float, telegraph: float, freeze: float, discretion_cost: float,
		grace: float = 0.25) -> SimEvent:
	return SimEvent.new(t, Kind.KNOCK, KnockPayload.new(telegraph, freeze, discretion_cost, grace))


## A Smell Cloud is normally EMITTED by play rather than scheduled (see
## PushSim's smell charge), but the payload is the same either way, so a level can
## still script one — same hazard, same code path, two possible sources.
static func smell(t: float, telegraph: float, window: float, discretion_cost: float) -> SimEvent:
	return SimEvent.new(t, Kind.SMELL, SmellPayload.new(telegraph, window, discretion_cost))


# --- Typed payloads (inner classes: referenced as SimEvent.FlowZonePayload etc.) ---

class FlowZonePayload extends RefCounted:
	var bands: Array[Vector2]
	var ramp: float   ## seconds to lerp toward the new bands (0 = instant)
	func _init(b: Array[Vector2], r: float) -> void:
		bands = b
		ramp = r


class MeterPayload extends RefCounted:
	var meter_id: int   ## SimState.Meter
	var delta: float
	func _init(m: int, d: float) -> void:
		meter_id = m
		delta = d


class PromptPayload extends RefCounted:
	var text: String
	var hold: float     ## seconds the prompt banner stays up
	func _init(tx: String, h: float) -> void:
		text = tx
		hold = h


class KnockPayload extends RefCounted:
	var telegraph: float        ## warning window before the freeze (seconds)
	var freeze: float           ## the reaction window — release and hold still (seconds)
	var discretion_cost: float  ## Discretion lost if a push lands during the freeze
	var grace: float            ## seconds of forgiveness at the start of the freeze
	func _init(tg: float, fz: float, dc: float, gr: float) -> void:
		telegraph = tg
		freeze = fz
		discretion_cost = dc
		grace = gr


class SmellPayload extends RefCounted:
	var telegraph: float        ## the cloud drifting in — swipe early and it disperses
	var window: float           ## last-chance reaction window once it arrives
	var discretion_cost: float  ## Discretion lost if it lands unwafted
	func _init(tg: float, wn: float, dc: float) -> void:
		telegraph = tg
		window = wn
		discretion_cost = dc
