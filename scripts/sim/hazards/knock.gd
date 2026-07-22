class_name KnockHazard
extends RefCounted
## The Knock — a Dilemma hazard that threatens Discretion. This is the first real
## hazard and the template for the rest: a scheduled KNOCK event arms it, PushSim
## ticks it, and it is entirely self-contained — no new meter, no hardcoded timer.
##
## Two phases after arming: a telegraphed warning, then a FREEZE window. During
## the freeze you must release and hold still — ANY push is audible and craters
## Discretion. The freeze also stalls Relief and bleeds Composure faster (the cost
## of holding your breath to stay quiet).
##
## Stateless operator: it reads and writes primitive `knock_*` fields on SimState
## rather than owning an object, so SimState stays pure data and no class cycle
## forms (SimState never references this class). Called only from PushSim's single
## tick path, so mutation order stays deterministic and auditable.

enum Phase { IDLE, TELEGRAPH, FREEZE, RESOLVED }

## Composure drains this much faster while frozen (you're clenched and silent).
const FREEZE_COMPOSURE_MULT: float = 1.5


static func start(state: SimState, payload: SimEvent.KnockPayload) -> void:
	state.knock_phase = Phase.TELEGRAPH
	state.knock_timer = payload.telegraph
	state.knock_freeze_len = payload.freeze
	state.knock_cost = payload.discretion_cost
	state.knock_failed = false


## Telegraph (fair warning) or freeze (the reaction test) is running.
static func is_active(state: SimState) -> bool:
	return state.knock_phase == Phase.TELEGRAPH or state.knock_phase == Phase.FREEZE


## In the freeze window: Relief is stalled and any push is a detection.
static func freezing(state: SimState) -> bool:
	return state.knock_phase == Phase.FREEZE


## Advance one step. Mutates `state`: bleeds Composure while frozen, and craters
## Discretion the instant a push lands during the freeze.
static func tick(state: SimState, intent: PlayerIntent, level: LevelDef, dt: float) -> void:
	match state.knock_phase:
		Phase.TELEGRAPH:
			state.knock_timer -= dt
			if state.knock_timer <= 0.0:
				state.knock_phase = Phase.FREEZE
				state.knock_timer = state.knock_freeze_len
		Phase.FREEZE:
			var bleed := (100.0 / level.composure_seconds) * FREEZE_COMPOSURE_MULT * dt
			state.composure = maxf(0.0, state.composure - bleed)
			# One push during the freeze is enough — they heard you.
			if intent.holding and not state.knock_failed:
				state.knock_failed = true
				state.apply_meter(SimState.Meter.DISCRETION, -state.knock_cost)
			state.knock_timer -= dt
			if state.knock_timer <= 0.0:
				state.knock_phase = Phase.RESOLVED
		_:
			pass
