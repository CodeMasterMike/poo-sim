class_name SmellCloudHazard
extends RefCounted
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
## punished. Let the window lapse and Discretion takes the hit.
##
## It deliberately does NOT stall The Push (`stalls_relief` stays false): you deal
## with it while still pushing. That's what makes it a different texture of
## pressure from the Knock's freeze, and keeps the two stackable without violating
## "one decision at a time" — the Knock takes your input away, this one asks for a
## flick.
##
## `grace` is unused here: failing this hazard is about inaction, not about being
## caught mid-input, so there's nothing to forgive at the start of the window.

static func start(state: SimState, payload: SimEvent.SmellPayload) -> void:
	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.SMELL
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.timer = payload.telegraph
	slot.active_len = payload.window
	slot.cost = payload.discretion_cost
	state.hazards.append(slot)


static func tick(state: SimState, slot: HazardSlot, intent: PlayerIntent, level: LevelDef, dt: float) -> void:
	# A swipe wafts it away in either phase — no reason to punish a fast reaction.
	if intent.swipe.length() >= level.swipe_min:
		slot.phase = HazardSlot.Phase.RESOLVED
		return

	match slot.phase:
		HazardSlot.Phase.TELEGRAPH:
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.ACTIVE
				slot.timer = slot.active_len
		HazardSlot.Phase.ACTIVE:
			slot.timer -= dt
			if slot.timer <= 0.0:
				# It landed on you. This is what the greedy push actually cost.
				slot.failed = true
				state.apply_meter(SimState.Meter.DISCRETION, -slot.cost)
				slot.phase = HazardSlot.Phase.RESOLVED
		_:
			pass
