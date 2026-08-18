class_name HazardOp
extends RefCounted
## One hazard's behaviour, and the phase machine every hazard shares.
##
## Each hazard in the catalog is the same story — a telegraphed warning, an active
## reaction window, then resolution — and each of the five operators wrote that
## story out longhand. Five copies of `timer -= dt; if timer <= 0.0:`, five slots
## built field by field, and five DIFFERENT tick signatures (the Knock took no
## clock, the Cover Window took neither state nor intent), which is what forced
## Hazards to keep two hand-maintained `match` tables instead of one lookup.
##
## So the machine lives here once and the hazards supply only what makes them
## different. `tick()` below is deliberately final in spirit: an operator overrides
## the HOOKS, never the loop, because the order of mutation inside a step is what
## determinism rests on (spec §17) and it should be readable in one place.
##
## Operators are STATELESS — one shared instance per kind, held by Hazards. All
## per-hazard state lives on the HazardSlot, which is plain data, so a SimState
## still snapshots for a ghost or a mirrored board with no operator in it.
##
## Every hook takes the same six arguments whether it needs them or not. That is
## the point: one uniform signature is what lets Hazards dispatch from a dictionary
## instead of a switch, so hazards #9-14 cost an operator file and one registration
## line rather than an edit in three places.


## The SimEvent.Kind this operator serves. Hazards keys its table off this, so an
## operator that forgets to override it registers under -1 and is never dispatched
## — which the hazard suite checks for.
func kind() -> int:
	return -1


## Build and arm this hazard's slot from its typed payload. Override to set the
## fields the hazard actually uses; `new_slot()` below covers the common ones.
##
## Returning null means "refuse to arm" — a malformed payload should drop the
## hazard, never append a half-built slot the tick loop would then have to survive.
func arm(_state: SimState, _payload: RefCounted, _clock: SimClock) -> HazardSlot:
	return null


## A slot pre-filled with everything every hazard sets the same way. Hazards that
## carry no cost or no window simply leave those at zero.
func new_slot(telegraph: float, active_len: float, cost: float = 0.0) -> HazardSlot:
	var slot := HazardSlot.new()
	slot.kind = kind()
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.timer = telegraph
	slot.active_len = active_len
	slot.cost = cost
	return slot


# ------------------------------------------------------------------------ hooks
#
# All five share one signature. Override the ones your hazard uses; the defaults
# are no-ops, which is exactly what a pure timer window (the Cover Window) wants.

## A per-tick cost paid for as long as the hazard is unresolved, in ANY phase —
## The Buzz distracting you from your pocket. Runs before the resolution check, so
## the tick on which the player answers still costs them that tick.
func bleed(_state: SimState, _slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	pass


## Did the player answer it this step? Return true and the slot retires unfailed.
##
## Called in BOTH phases, because reacting early should be rewarded rather than
## punished — a Smell Cloud disperses whether you swipe as it drifts in or as it
## lands. A hazard that can only be answered once it has arrived (the Jolt: there
## is nothing to swipe back before it hits) must check `slot.phase` itself.
func resolved_by_player(_state: SimState, _slot: HazardSlot, _intent: PlayerIntent,
		_level: LevelDef, _clock: SimClock, _dt: float) -> bool:
	return false


## The telegraph is over and the thing is on you — the one step where TELEGRAPH
## becomes ACTIVE. Where the Jolt shoves the needle and the Knock starts freezing
## The Push. Any RNG a hazard pulls belongs here, from `clock.rng`, never a global.
func on_arrive(_state: SimState, _slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	pass


## Every step of the ACTIVE window, before the timer is decremented — the Knock
## bleeding Composure and listening for a push.
func on_active_tick(_state: SimState, _slot: HazardSlot, _intent: PlayerIntent,
		_level: LevelDef, _clock: SimClock, _dt: float) -> void:
	pass


## The window closed with no answer. Most hazards mark `slot.failed` and charge
## their cost here; the Jolt marks it and charges nothing, because being left where
## it threw you IS the cost. Deliberately NOT defaulted to "fail": the Cover Window
## expiring is not a failure, and a default that quietly failed it would have to be
## overridden back to nothing.
func on_lapse(_state: SimState, _slot: HazardSlot, _intent: PlayerIntent, _level: LevelDef,
		_clock: SimClock, _dt: float) -> void:
	pass


# ------------------------------------------------------------------ the machine

## Advance one slot by one step. THE loop — do not override it.
##
## The order below is the order the five hand-written copies already used, kept
## exactly: bleed, then the player's answer, then the phase's own business. Moving
## any of them changes what a given intent stream produces, which would break
## replay for every recorded run.
func tick(state: SimState, slot: HazardSlot, intent: PlayerIntent, level: LevelDef,
		clock: SimClock, dt: float) -> void:
	bleed(state, slot, intent, level, clock, dt)

	if resolved_by_player(state, slot, intent, level, clock, dt):
		slot.phase = HazardSlot.Phase.RESOLVED
		return

	match slot.phase:
		HazardSlot.Phase.TELEGRAPH:
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.ACTIVE
				slot.timer = slot.active_len
				on_arrive(state, slot, intent, level, clock, dt)
		HazardSlot.Phase.ACTIVE:
			on_active_tick(state, slot, intent, level, clock, dt)
			slot.timer -= dt
			if slot.timer <= 0.0:
				on_lapse(state, slot, intent, level, clock, dt)
				slot.phase = HazardSlot.Phase.RESOLVED
		_:
			pass
