class_name KnockHazard
extends HazardOp
## The Knock — a Dilemma hazard that threatens Discretion, and the reference
## implementation for the rest of the catalog.
##
## Telegraphed warning, then a freeze window: release and hold still, because ANY
## push during the freeze is audible and craters Discretion. The freeze also
## stalls Relief and bleeds Composure faster (the cost of holding your breath).
##
## Stateless operator over a HazardSlot — it owns no state of its own, and is
## driven only from PushSim's single tick path via Hazards, so mutation order
## stays deterministic and auditable. The phase machine itself lives in HazardOp;
## what is left here is only what makes a Knock a Knock.
##
## It is the one hazard with nothing to answer: there is no swipe or tap that
## dismisses it, so it overrides no `resolved_by_player`. You pass it by doing
## nothing, which is the whole dilemma.

## Composure drains this much faster while frozen (you're clenched and silent).
const FREEZE_COMPOSURE_MULT: float = 1.5


func kind() -> int:
	return SimEvent.Kind.KNOCK


func arm(_state: SimState, payload: RefCounted, _clock: SimClock) -> HazardSlot:
	var p := payload as SimEvent.KnockPayload
	if p == null:
		return null
	var slot: HazardSlot = new_slot(p.telegraph, p.freeze, p.discretion_cost)
	slot.grace = p.grace
	return slot


## The freeze pauses The Push by design — that is most of what the hazard costs.
func on_arrive(_state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	slot.stalls_relief = true


func on_active_tick(state: SimState, slot: HazardSlot, intent: PlayerIntent, level: LevelDef,
		_clock: SimClock, dt: float) -> void:
	var bleed_amount := (100.0 / level.composure_seconds) * FREEZE_COMPOSURE_MULT * dt
	state.composure = maxf(0.0, state.composure - bleed_amount)
	# One push during the freeze is enough — they heard you. But the first
	# `grace` seconds are forgiven: you get a beat to actually let go, instead of
	# failing on the very first frame for being mid-push.
	var since_freeze_began := slot.active_len - slot.timer
	if intent.holding and not slot.failed and since_freeze_began >= slot.grace:
		slot.failed = true
		state.apply_meter(SimState.Meter.DISCRETION, -slot.cost)


## Surviving the freeze is not a "lapse" to punish — the cost was already charged
## the moment a push was heard. All that is left is to hand The Push back.
func on_lapse(_state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	slot.stalls_relief = false
