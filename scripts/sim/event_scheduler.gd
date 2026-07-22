class_name EventScheduler
extends RefCounted
## Consumes a level's timeline and applies each event's typed payload when its
## trigger fires. This is the ONE code path that will later resolve level events,
## ghost events, and opponent sabotage — they differ only in where the SimEvents
## come from, not how they resolve (spec §17 guardrail 2).
##
## Two trigger families, both deterministic:
##   TIME    — fires on an integer step (never a drifting float clock).
##   RELIEF  — fires once the player's Relief crosses a threshold, so pacing can
##             follow actual progress (the spec's three-act micro-curve) instead
##             of a fixed stopwatch.
## Any randomness in *when* these fire was already rolled from the match seed in
## LevelDef.resolve_timeline, so the schedule is fixed before the first tick.

var _timed: Array[SimEvent] = []
var _conditional: Array[SimEvent] = []
var _next: int = 0

## The current prompt-band text (view reads this). Empty when nothing is showing.
var last_prompt: String = ""
var _prompt_until_step: int = 0


## Events must already be resolved (see LevelDef.resolve_timeline).
func load_timeline(events: Array[SimEvent]) -> void:
	_timed.clear()
	_conditional.clear()
	for ev in events:
		if ev.trigger == SimEvent.Trigger.RELIEF:
			_conditional.append(ev)
		else:
			_timed.append(ev)
	_timed.sort_custom(func(a: SimEvent, b: SimEvent) -> bool: return a.step < b.step)
	_next = 0
	last_prompt = ""
	_prompt_until_step = 0


func tick(clock: SimClock, state: SimState) -> void:
	# Time-keyed first, then condition-keyed in authored order — a fixed
	# resolution order matters for determinism once events can affect each other.
	while _next < _timed.size() and _timed[_next].step <= clock.step:
		_apply(_timed[_next], state, clock)
		_next += 1

	var i := 0
	while i < _conditional.size():
		var ev := _conditional[i]
		if state.relief >= ev.relief_at:
			_apply(ev, state, clock)
			_conditional.remove_at(i)
		else:
			i += 1

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
			# Hazard kinds arm an in-flight slot; Hazards owns the dispatch table.
			Hazards.start(state, ev.kind, ev.payload)
