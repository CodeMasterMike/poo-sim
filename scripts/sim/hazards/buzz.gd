class_name BuzzHazard
extends RefCounted
## The Buzz — your phone lights up mid-sit. A Reflex hazard threatening Composure
## while it buzzes and Discretion if you let it ring out.
##
## It's the only hazard that costs you continuously while unresolved: the buzzing
## bleeds Composure as a distraction, so ignoring it is never free even if you're
## willing to eat the Discretion hit at the end. Tap to dismiss, in either phase.
##
## Uses `intent.tap` — the last of the three intent fields to find a use. Note
## that a tap is a *short press*, deliberately distinguished from the press that
## starts a hold, or every push would dismiss your phone by accident.

static func start(state: SimState, payload: SimEvent.BuzzPayload, _clock: SimClock) -> void:
	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.BUZZ
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.timer = payload.telegraph
	slot.active_len = payload.window
	slot.cost = payload.discretion_cost
	slot.drain = payload.composure_drain
	state.hazards.append(slot)


static func tick(state: SimState, slot: HazardSlot, intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, dt: float) -> void:
	# Buzzing away in your pocket is a distraction for as long as you allow it.
	state.composure = maxf(0.0, state.composure - slot.drain * dt)

	if intent.tap:
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
				# It rings out. Everyone hears it.
				slot.failed = true
				state.apply_meter(SimState.Meter.DISCRETION, -slot.cost)
				slot.phase = HazardSlot.Phase.RESOLVED
		_:
			pass
