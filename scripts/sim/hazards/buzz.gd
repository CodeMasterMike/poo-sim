class_name BuzzHazard
extends HazardOp
## The Buzz — your phone lights up mid-sit. A Reflex hazard threatening Composure
## while it buzzes and Discretion if you let it ring out.
##
## It's the only hazard that costs you continuously while unresolved: the buzzing
## bleeds Composure as a distraction, so ignoring it is never free even if you're
## willing to eat the Discretion hit at the end. That is HazardOp's `bleed` hook,
## and this is the only operator that uses it. Tap to dismiss, in either phase.
##
## Uses `intent.tap` — the last of the three intent fields to find a use. Note
## that a tap is a *short press*, deliberately distinguished from the press that
## starts a hold, or every push would dismiss your phone by accident.


func kind() -> int:
	return SimEvent.Kind.BUZZ


func arm(_state: SimState, payload: RefCounted, _clock: SimClock) -> HazardSlot:
	var p := payload as SimEvent.BuzzPayload
	if p == null:
		return null
	var slot: HazardSlot = new_slot(p.telegraph, p.window, p.discretion_cost)
	slot.drain = p.composure_drain
	return slot


## Buzzing away in your pocket is a distraction for as long as you allow it.
func bleed(state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, dt: float) -> void:
	state.composure = maxf(0.0, state.composure - slot.drain * dt)


func resolved_by_player(_state: SimState, _slot: HazardSlot, intent: PlayerIntent,
		_level: LevelDef, _clock: SimClock, _dt: float) -> bool:
	return intent.tap


## It rings out. Everyone hears it.
func on_lapse(state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	slot.failed = true
	state.apply_meter(SimState.Meter.DISCRETION, -slot.cost)
