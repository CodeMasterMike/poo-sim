class_name Hazards
extends RefCounted
## Dispatch layer for in-flight hazards. One place decides which operator ticks
## which slot, so PushSim stays a single ordered mutation path (determinism) and
## adding a hazard is "one arm each here + one operator file" — no changes to
## SimState or PushSim.
##
## The SimClock is threaded through so hazards can pull from the match-seeded RNG
## (the Jolt rolls its direction). Any hazard randomness must come from there,
## never a global randf(), or replays and mirrored boards break.

## Arm a hazard from its payload, whether that came from the timeline or from
## emergent play (see PushSim's smell charge).
static func start(state: SimState, kind: int, payload: RefCounted, clock: SimClock) -> void:
	match kind:
		SimEvent.Kind.KNOCK:
			KnockHazard.start(state, payload as SimEvent.KnockPayload)
		SimEvent.Kind.SMELL:
			SmellCloudHazard.start(state, payload as SimEvent.SmellPayload)
		SimEvent.Kind.JOLT:
			JoltHazard.start(state, payload as SimEvent.JoltPayload, clock)
		SimEvent.Kind.BUZZ:
			BuzzHazard.start(state, payload as SimEvent.BuzzPayload, clock)
		SimEvent.Kind.COVER:
			CoverWindowHazard.start(state, payload as SimEvent.CoverPayload)
		_:
			pass  # the rest of the catalog: slots reserved, no operators yet


## Advance every in-flight hazard, then retire the resolved ones.
static func tick(state: SimState, intent: PlayerIntent, level: LevelDef, clock: SimClock,
		dt: float) -> void:
	for slot in state.hazards:
		if slot.phase == HazardSlot.Phase.RESOLVED:
			continue
		match slot.kind:
			SimEvent.Kind.KNOCK:
				KnockHazard.tick(state, slot, intent, level, dt)
			SimEvent.Kind.SMELL:
				SmellCloudHazard.tick(state, slot, intent, level, dt)
			SimEvent.Kind.JOLT:
				JoltHazard.tick(state, slot, intent, level, clock, dt)
			SimEvent.Kind.BUZZ:
				BuzzHazard.tick(state, slot, intent, level, clock, dt)
			SimEvent.Kind.COVER:
				CoverWindowHazard.tick(slot, dt)
			_:
				pass
	_sweep(state)


## Retire resolved slots, recording the outcome on SimState so the view can react
## (and Scoring can read streaks) without the sim holding view state.
static func _sweep(state: SimState) -> void:
	var keep: Array[HazardSlot] = []
	for slot in state.hazards:
		if slot.phase != HazardSlot.Phase.RESOLVED:
			keep.append(slot)
			continue
		# Constraint windows (the Cover Window) retire quietly — resolving one isn't
		# a pass/fail reaction, so it neither pulses the view nor moves the tallies.
		if not slot.scored:
			continue
		state.hazard_resolve_pulse += 1
		state.last_hazard_kind = slot.kind
		state.last_hazard_failed = slot.failed
		if slot.failed:
			state.hazards_failed += 1
		else:
			state.hazards_passed += 1
	state.hazards = keep


## True while any in-flight hazard is freezing The Push (gates Relief fill).
static func relief_stalled(state: SimState) -> bool:
	for slot in state.hazards:
		if slot.stalls_relief and slot.phase == HazardSlot.Phase.ACTIVE:
			return true
	return false


## True while any acoustic window (COVER slot) is ACTIVE — the Church's organ
## swells, the Rave's hushes. It's a neutral "the soundscape has flipped from
## baseline" signal; whether that helps or hurts is the level's call (room_exposed).
## Derived from the hazard list rather than a stored flag, so overlapping windows
## and same-step resolution can't desync it.
static func acoustic_window_active(state: SimState) -> bool:
	for slot in state.hazards:
		if slot.kind == SimEvent.Kind.COVER and slot.phase == HazardSlot.Phase.ACTIVE:
			return true
	return false


## Is the room audible RIGHT NOW, in a quiet-room level? The baseline is exposed or
## covered per the level; an active acoustic window flips it. Church (exposed
## baseline): exposed until an organ swell covers you. Rave (covered baseline):
## covered until a hush exposes you. This one call serves both polarities.
static func room_exposed(state: SimState, level: LevelDef) -> bool:
	return level.baseline_exposed != acoustic_window_active(state)


## The first in-flight slot of a kind, or null. Used by the view for prompts.
static func find(state: SimState, kind: int) -> HazardSlot:
	for slot in state.hazards:
		if slot.kind == kind:
			return slot
	return null
