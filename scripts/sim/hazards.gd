class_name Hazards
extends RefCounted
## Dispatch layer for in-flight hazards. One place decides which operator ticks
## which slot, so PushSim stays a single ordered mutation path (determinism) and
## adding a hazard is "one operator file + one line in the table below" — no
## changes to SimState or PushSim.
##
## That table replaced two hand-maintained `match` statements — one to arm a
## hazard, one to tick it — which between them named every kind twice. A hazard
## registered in the first and forgotten in the second would arm and then sit
## there, permanently in TELEGRAPH, doing nothing and never retiring: a bug with no
## error and no crash. There is now one list, and the operator declares its own
## kind, so the two cannot disagree.
##
## The SimClock is threaded through so hazards can pull from the match-seeded RNG
## (the Jolt rolls its direction). Any hazard randomness must come from there,
## never a global randf(), or replays and mirrored boards break.

## THE registry: one stateless operator per hazard kind. Add a hazard by appending
## its operator here — it keys itself off its own `kind()`.
##
## Operators hold no state (all of it lives on the HazardSlot), so one shared
## instance serves every slot of that kind for the life of the process. Built lazily
## because a `const` can't hold object instances.
static var _ops: Dictionary = {}


static func _table() -> Dictionary:
	if _ops.is_empty():
		for op in [
			KnockHazard.new(),
			SmellCloudHazard.new(),
			JoltHazard.new(),
			BuzzHazard.new(),
			CoverWindowHazard.new(),
		]:
			_ops[op.kind()] = op
	return _ops


## The operator for a kind, or null for the reserved-but-unimplemented rest of the
## catalog. Callers treat null as "nothing to do", which is what an event naming a
## hazard this build doesn't have yet should do — a forward-compatible level or
## ghost is the whole reason SimEvent.Kind reserves those slots.
static func operator_for(kind: int) -> HazardOp:
	return _table().get(kind)


## Arm a hazard from its payload, whether that came from the timeline or from
## emergent play (see PushSim's smell charge).
static func start(state: SimState, kind: int, payload: RefCounted, clock: SimClock) -> void:
	var op: HazardOp = operator_for(kind)
	if op == null:
		return
	var slot: HazardSlot = op.arm(state, payload, clock)
	if slot == null:
		return   # a payload of the wrong type: drop it rather than arm a half-built slot
	state.hazards.append(slot)


## Advance every in-flight hazard, then retire the resolved ones.
static func tick(state: SimState, intent: PlayerIntent, level: LevelDef, clock: SimClock,
		dt: float) -> void:
	for slot in state.hazards:
		if slot.phase == HazardSlot.Phase.RESOLVED:
			continue
		var op: HazardOp = operator_for(slot.kind)
		if op != null:
			op.tick(state, slot, intent, level, clock, dt)
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


## How hard the room is shaking you right now, 0..1. Turbulence, a passing truck,
## a wobbling porta-potty: anything that makes you a less steady platform.
##
## Kept here rather than in PushSim, and derived from the hazard list rather than a
## stored flag, for the same reason room_exposed is: it's a QUESTION about the
## in-flight set, and any later hazard that shakes you (a train, a bass drop) joins
## by adding an arm here — PushSim and SimState don't change.
##
## The Jolt already carries its impulse magnitude in `slot.cost`, so that doubles
## as the shake strength, normalised against the operator's own full-shake scale.
## Ask the operator for that scale rather than keeping a number here: a second
## shaking hazard brings its own, and this table shouldn't accumulate them.
##
## Concurrent shakes take the WORST, they don't add — two hazards agreeing you're
## unsteady is still one unsteady sitter, and summing would let a stacked pair
## throw the stream clean out of the bowl.
static func turbulence(state: SimState) -> float:
	var worst := 0.0
	for slot in state.hazards:
		if slot.kind == SimEvent.Kind.JOLT and slot.phase == HazardSlot.Phase.ACTIVE:
			worst = maxf(worst, clampf(slot.cost / JoltHazard.FULL_SHAKE_IMPULSE, 0.0, 1.0))
	return worst


## The first in-flight slot of a kind, or null. Used by the view for prompts.
static func find(state: SimState, kind: int) -> HazardSlot:
	for slot in state.hazards:
		if slot.kind == kind:
			return slot
	return null
