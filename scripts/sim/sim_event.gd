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

enum Kind { FLOW_ZONE, METER, PROMPT, KNOCK, JOLT, BUZZ }

var time: float = 0.0
var step: int = 0
var kind: Kind = Kind.FLOW_ZONE
var payload: RefCounted = null


func _init(t: float, k: Kind, p: RefCounted) -> void:
	time = t
	kind = k
	payload = p


## Snap the authoring time onto the integer step grid. Called once at load.
func resolve_step(fixed_dt: float) -> void:
	step = int(round(time / fixed_dt))


# --- Static factories: author events with typed payloads and full autocomplete ---

static func flow_zone(t: float, bands: Array[Vector2], ramp: float = 0.0) -> SimEvent:
	return SimEvent.new(t, Kind.FLOW_ZONE, FlowZonePayload.new(bands, ramp))


static func meter(t: float, meter_id: int, delta: float) -> SimEvent:
	return SimEvent.new(t, Kind.METER, MeterPayload.new(meter_id, delta))


static func prompt(t: float, text: String, hold: float) -> SimEvent:
	return SimEvent.new(t, Kind.PROMPT, PromptPayload.new(text, hold))


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
