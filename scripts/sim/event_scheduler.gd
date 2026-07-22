class_name EventScheduler
extends RefCounted
## Consumes a level's timeline and applies each event's typed payload to the sim
## when its step arrives. This is the ONE code path that will later resolve level
## events, ghost events, and opponent sabotage — they differ only in where the
## SimEvents come from, not how they resolve (spec §17 guardrail 2).
##
## Triggering is by integer step (SimEvent.step), never a float clock, so an
## event fires on exactly the same step every run.

var _pending: Array[SimEvent] = []
var _next: int = 0

## The current prompt-band text (view reads this). Empty when nothing is showing.
var last_prompt: String = ""
var _prompt_until_step: int = 0


func load_timeline(events: Array[SimEvent]) -> void:
	_pending = events.duplicate()
	_pending.sort_custom(func(a: SimEvent, b: SimEvent) -> bool: return a.step < b.step)
	_next = 0
	last_prompt = ""
	_prompt_until_step = 0


func tick(clock: SimClock, state: SimState) -> void:
	while _next < _pending.size() and _pending[_next].step <= clock.step:
		_apply(_pending[_next], state, clock)
		_next += 1
	if _prompt_until_step > 0 and clock.step >= _prompt_until_step:
		last_prompt = ""
		_prompt_until_step = 0


func _apply(ev: SimEvent, state: SimState, clock: SimClock) -> void:
	match ev.kind:
		SimEvent.Kind.FLOW_ZONE:
			var p := ev.payload as SimEvent.FlowZonePayload
			if p.ramp <= 0.0:
				state.flow_bands = p.bands.duplicate()
				state.flow_target_bands = p.bands.duplicate()
				state.flow_ramp_rate = 0.0
			else:
				state.flow_target_bands = p.bands.duplicate()
				state.flow_ramp_rate = 1.0 / p.ramp
		SimEvent.Kind.METER:
			var m := ev.payload as SimEvent.MeterPayload
			state.apply_meter(m.meter_id, m.delta)
		SimEvent.Kind.PROMPT:
			var pr := ev.payload as SimEvent.PromptPayload
			last_prompt = pr.text
			_prompt_until_step = clock.step + int(round(pr.hold / SimClock.FIXED_DT))
		_:
			# KNOCK / JOLT / BUZZ and future hazards: slots reserved, no handlers yet.
			pass
