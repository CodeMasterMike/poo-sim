class_name JoltHazard
extends RefCounted
## Jolt / Turbulence — a Reflex hazard that attacks The Push itself rather than a
## meter. Turbulence, a passing truck, a wobbling porta-potty: the needle gets
## shoved and you have a moment to drag it back.
##
## Its damage is POSITIONAL. Failing it subtracts nothing directly — it just
## leaves you where it threw you, and the systems already in place do the rest:
## flung high you bleed Discretion and charge toward a splash, knocked low your
## Relief stalls and Composure drains faster. That makes it the first hazard whose
## entire cost is emergent, and the reason it needs no `discretion_cost`.
##
## `slot.cost` carries the impulse magnitude here rather than meter damage.
##
## Direction is rolled from the match-seeded RNG when the jolt lands, so it can
## shove you either way while still replaying identically for a given seed.

static func start(state: SimState, payload: SimEvent.JoltPayload, _clock: SimClock) -> void:
	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.JOLT
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.timer = payload.telegraph
	slot.active_len = payload.window
	slot.cost = payload.displacement
	state.hazards.append(slot)


static func tick(state: SimState, slot: HazardSlot, intent: PlayerIntent, level: LevelDef,
		clock: SimClock, dt: float) -> void:
	match slot.phase:
		HazardSlot.Phase.TELEGRAPH:
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.ACTIVE
				slot.timer = slot.active_len
				# It lands: shove the needle, direction from the seeded RNG.
				var dir := 1.0 if clock.rng.randf() < 0.5 else -1.0
				state.needle_vel += slot.cost * dir
		HazardSlot.Phase.ACTIVE:
			if intent.swipe.length() >= level.swipe_min:
				_recenter(state, level)
				slot.phase = HazardSlot.Phase.RESOLVED
				return
			slot.timer -= dt
			if slot.timer <= 0.0:
				# No save. You're left wherever it put you — that IS the cost.
				slot.failed = true
				slot.phase = HazardSlot.Phase.RESOLVED
		_:
			pass


## Kill the imparted momentum and drag the needle back toward the Flow band.
static func _recenter(state: SimState, level: LevelDef) -> void:
	state.needle_vel = 0.0
	if state.flow_bands.is_empty():
		return
	var band: Vector2 = state.flow_bands[0]
	var mid: float = (band.x + band.y) * 0.5
	state.needle = lerpf(state.needle, mid, level.jolt_recenter)
