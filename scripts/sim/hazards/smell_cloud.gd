class_name SmellCloudHazard
extends HazardOp
## Smell Cloud — a Reflex hazard threatening Discretion, and the second use of the
## hazard recipe.
##
## Unlike The Knock, this one is EMERGENT: nothing schedules it. PushSim emits it
## once hard pushing has built up enough charge (SimState.smell_charge), which is
## the point — it turns the red-zone gamble into a two-part decision (go greedy,
## then deal with what that produces) instead of the flat unavoidable tax the old
## scripted version was.
##
## TELEGRAPH is the cloud drifting in; ACTIVE is it arriving, the last chance. A
## swipe disperses it in EITHER phase, so reacting early is rewarded rather than
## punished — which is HazardOp's default for `resolved_by_player`, so this one
## simply doesn't check the phase. Let the window lapse and Discretion takes the hit.
##
## It deliberately does NOT stall The Push (`stalls_relief` stays false): you deal
## with it while still pushing. That's what makes it a different texture of
## pressure from the Knock's freeze, and keeps the two stackable without violating
## "one decision at a time" — the Knock takes your input away, this one asks for a
## flick.
##
## `grace` is unused here: failing this hazard is about inaction, not about being
## caught mid-input, so there's nothing to forgive at the start of the window.


func kind() -> int:
	return SimEvent.Kind.SMELL


func arm(_state: SimState, payload: RefCounted, _clock: SimClock) -> HazardSlot:
	var p := payload as SimEvent.SmellPayload
	if p == null:
		return null
	return new_slot(p.telegraph, p.window, p.discretion_cost)


## A swipe wafts it away in either phase — no reason to punish a fast reaction.
func resolved_by_player(_state: SimState, _slot: HazardSlot, intent: PlayerIntent,
		level: LevelDef, _clock: SimClock, _dt: float) -> bool:
	return intent.swipe.length() >= level.swipe_min


## It landed on you. This is what the greedy push actually cost.
func on_lapse(state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	slot.failed = true
	state.apply_meter(SimState.Meter.DISCRETION, -slot.cost)
