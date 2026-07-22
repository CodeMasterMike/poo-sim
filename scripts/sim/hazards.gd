class_name Hazards
extends RefCounted
## Dispatch layer for in-flight hazards. One place decides which operator ticks
## which slot, so PushSim stays a single ordered mutation path (determinism) and
## adding a hazard is "one arm here + one operator file" — no changes to SimState.

## Arm a hazard from its scheduled event payload.
static func start(state: SimState, kind: int, payload: RefCounted) -> void:
	match kind:
		SimEvent.Kind.KNOCK:
			KnockHazard.start(state, payload as SimEvent.KnockPayload)
		_:
			pass  # JOLT / BUZZ and the rest: slots reserved, no operators yet


## Advance every in-flight hazard, then retire the resolved ones.
static func tick(state: SimState, intent: PlayerIntent, level: LevelDef, dt: float) -> void:
	for slot in state.hazards:
		if slot.phase == HazardSlot.Phase.RESOLVED:
			continue
		match slot.kind:
			SimEvent.Kind.KNOCK:
				KnockHazard.tick(state, slot, intent, level, dt)
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


## The first in-flight slot of a kind, or null. Used by the view for prompts.
static func find(state: SimState, kind: int) -> HazardSlot:
	for slot in state.hazards:
		if slot.kind == kind:
			return slot
	return null
