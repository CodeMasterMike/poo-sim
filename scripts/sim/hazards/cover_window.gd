class_name CoverWindowHazard
extends RefCounted
## The Cover Window — the Church's signature Sustained-Constraint hazard, and the
## first that SUPPRESSES a penalty instead of inflicting one.
##
## The room is silent by default: PushSim bleeds Discretion whenever the needle is
## above `level.silence_push_cap` and no cover is active (its "silence penalty").
## A Cover Window — an organ swell, a hymn — is a stretch during which that penalty
## is lifted, so the player banks Relief in the windows and eases off in the hush.
## The Push turns into a timing game keyed to the ambient sound.
##
## The window is NOT a reaction test: it just holds its phase, and PushSim/the view
## read `Hazards.under_cover(state)` (derived from any ACTIVE cover slot) to know
## whether cover is up. That's why it needs no `intent` — nothing the player does
## resolves it; it simply expires.
##
## `scored = false`: a window ending is not a pass/fail, so it retires without the
## resolution flash and without touching the hazard tallies. TELEGRAPH is the cover
## building in (still silent — audible play is still heard); ACTIVE is the safe
## window; then it resolves back to silence.

static func start(state: SimState, payload: SimEvent.CoverPayload) -> void:
	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.COVER
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.timer = payload.telegraph
	slot.active_len = payload.duration
	slot.scored = false
	state.hazards.append(slot)


static func tick(slot: HazardSlot, dt: float) -> void:
	match slot.phase:
		HazardSlot.Phase.TELEGRAPH:
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.ACTIVE
				slot.timer = slot.active_len
		HazardSlot.Phase.ACTIVE:
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.RESOLVED
		_:
			pass
