class_name JoltHazard
extends HazardOp
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

## The displacement that counts as being shaken as hard as the model goes.
##
## `slot.cost` carries this jolt's own displacement, so it doubles as a shake
## strength; `Hazards.turbulence()` normalises against this to report 0..1, and a
## gentler jolt therefore throws the stream around less than a violent one. It
## lives HERE rather than in the dispatch layer because it's a fact about the
## Jolt: the next hazard that shakes you brings its own scale, and Hazards should
## be asking each operator, not carrying a number for one of them.
##
## Matches the displacement the authored jolts use (see LevelGreybox), so a stock
## jolt reads as a full shake.
const FULL_SHAKE_IMPULSE: float = 1.2


func kind() -> int:
	return SimEvent.Kind.JOLT


func arm(_state: SimState, payload: RefCounted, _clock: SimClock) -> HazardSlot:
	var p := payload as SimEvent.JoltPayload
	if p == null:
		return null
	return new_slot(p.telegraph, p.window, p.displacement)


## The ONE hazard that checks its phase here, and it has to.
##
## HazardOp answers a hazard in either phase because reacting early is normally a
## virtue. Not for a jolt: there is nothing to swipe back until it has actually
## thrown you, so a swipe during the telegraph would retire the slot before
## `on_arrive` ever ran — the needle would never be shoved, and bracing early would
## make the hazard vanish rather than survive it.
func resolved_by_player(state: SimState, slot: HazardSlot, intent: PlayerIntent,
		level: LevelDef, _clock: SimClock, _dt: float) -> bool:
	if slot.phase != HazardSlot.Phase.ACTIVE:
		return false
	if intent.swipe.length() < level.swipe_min:
		return false
	_recenter(state, level)
	return true


## It lands: shove the needle, direction from the seeded RNG.
func on_arrive(state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		clock: SimClock, _dt: float) -> void:
	var dir := 1.0 if clock.rng.randf() < 0.5 else -1.0
	state.needle_vel += slot.cost * dir


## No save. You're left wherever it put you — that IS the cost, so nothing is
## charged here beyond recording the miss.
func on_lapse(_state: SimState, slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	slot.failed = true


## Kill the imparted momentum and drag the needle back toward the Flow band.
##
## Toward the NEAREST band, which matters only on a split zone: the middle of the
## span sits in the dead notch there, so recovering from a jolt would drop you in
## the worst place on the gauge. On a single band the two are the same number.
static func _recenter(state: SimState, level: LevelDef) -> void:
	state.needle_vel = 0.0
	if state.flow_bands.is_empty():
		return
	state.needle = lerpf(state.needle, PushSim.nearest_band_centre(state), level.jolt_recenter)
