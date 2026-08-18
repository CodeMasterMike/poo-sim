class_name CoverWindowHazard
extends HazardOp
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
## ask `Hazards.room_exposed(state, level)` — which resolves this window against the
## level's polarity, via `Hazards.acoustic_window_active(state)` — to know whether
## it is currently safe to push. That's why it overrides no hooks at all beyond
## arming: nothing the player does resolves it; it simply expires, and HazardOp's
## bare phase machine is the entire behaviour.
##
## `scored = false`: a window ending is not a pass/fail, so it retires without the
## resolution flash and without touching the hazard tallies. TELEGRAPH is the cover
## building in (still silent — audible play is still heard); ACTIVE is the safe
## window; then it resolves back to silence.


func kind() -> int:
	return SimEvent.Kind.COVER


func arm(_state: SimState, payload: RefCounted, _clock: SimClock) -> HazardSlot:
	var p := payload as SimEvent.CoverPayload
	if p == null:
		return null
	var slot: HazardSlot = new_slot(p.telegraph, p.duration)
	slot.scored = false
	return slot
