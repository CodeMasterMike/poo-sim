class_name KnockHazard
extends RefCounted
## The Knock — a Dilemma hazard that threatens Discretion, and the reference
## implementation for the rest of the catalog.
##
## Telegraphed warning, then a freeze window: release and hold still, because ANY
## push during the freeze is audible and craters Discretion. The freeze also
## stalls Relief and bleeds Composure faster (the cost of holding your breath).
##
## Stateless operator over a HazardSlot — it owns no state of its own, and is
## driven only from PushSim's single tick path via Hazards, so mutation order
## stays deterministic and auditable.

## Composure drains this much faster while frozen (you're clenched and silent).
const FREEZE_COMPOSURE_MULT: float = 1.5


static func start(state: SimState, payload: SimEvent.KnockPayload) -> void:
	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.KNOCK
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.timer = payload.telegraph
	slot.active_len = payload.freeze
	slot.cost = payload.discretion_cost
	slot.grace = payload.grace
	state.hazards.append(slot)


static func tick(state: SimState, slot: HazardSlot, intent: PlayerIntent, level: LevelDef, dt: float) -> void:
	match slot.phase:
		HazardSlot.Phase.TELEGRAPH:
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.ACTIVE
				slot.timer = slot.active_len
				slot.stalls_relief = true  # the freeze pauses The Push by design
		HazardSlot.Phase.ACTIVE:
			var bleed := (100.0 / level.composure_seconds) * FREEZE_COMPOSURE_MULT * dt
			state.composure = maxf(0.0, state.composure - bleed)
			# One push during the freeze is enough — they heard you. But the first
			# `grace` seconds are forgiven: you get a beat to actually let go,
			# instead of failing on the very first frame for being mid-push.
			var since_freeze_began := slot.active_len - slot.timer
			if intent.holding and not slot.failed and since_freeze_began >= slot.grace:
				slot.failed = true
				state.apply_meter(SimState.Meter.DISCRETION, -slot.cost)
			slot.timer -= dt
			if slot.timer <= 0.0:
				slot.phase = HazardSlot.Phase.RESOLVED
				slot.stalls_relief = false
		_:
			pass
