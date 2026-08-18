@tool
extends McpTestSuite
## Guards the hazard dispatch table.
##
## Arming and ticking a hazard used to be two `match` statements that each named
## every kind. A hazard present in one and missing from the other armed a slot that
## then never advanced — stuck in TELEGRAPH forever, never retiring, with no error
## and no crash. One registry replaced both, and these tests guard the properties
## that made the split dangerous: every operator is reachable, every operator is
## reachable as ITSELF, and an unknown kind degrades quietly instead of exploding.


func suite_name() -> String:
	return "hazard_registry"


## The kinds that have a live operator today. The rest of SimEvent.Kind is
## deliberately reserved without one (see Hazards), so this is a roster, not a
## derivation from the enum.
const IMPLEMENTED := [
	SimEvent.Kind.KNOCK,
	SimEvent.Kind.SMELL,
	SimEvent.Kind.JOLT,
	SimEvent.Kind.BUZZ,
	SimEvent.Kind.COVER,
]


func test_every_implemented_hazard_has_an_operator() -> void:
	for kind in IMPLEMENTED:
		assert_ne(Hazards.operator_for(kind), null,
				"no operator registered for kind %d" % kind)


## An operator registered under the wrong key would tick the wrong hazard's slot —
## a Knock advancing with the Buzz's rules. The table keys itself off `kind()`, so
## this checks the operator agrees with where it landed.
func test_each_operator_reports_the_kind_it_is_registered_under() -> void:
	for kind in IMPLEMENTED:
		var op := Hazards.operator_for(kind)
		assert_eq(op.kind(), kind,
				"the operator at kind %d reports kind %d" % [kind, op.kind()])


## Every operator must override kind(). The base returns -1, so one that forgets
## registers under -1 and silently never dispatches.
func test_no_operator_is_left_on_the_base_kind() -> void:
	assert_eq(Hazards.operator_for(-1), null,
			"an operator registered under -1 — it never overrode kind()")


## Reserved-but-unimplemented kinds return null rather than throwing. A level or a
## ghost from a later build can name a hazard this one doesn't have; the forward
## compatibility SimEvent.Kind is built for depends on that being survivable.
func test_an_unimplemented_kind_degrades_quietly() -> void:
	assert_eq(Hazards.operator_for(SimEvent.Kind.PROMPT), null,
			"PROMPT is not a hazard and must have no operator")
	assert_eq(Hazards.operator_for(9999), null, "an unknown kind must return null")

	# ...and arming one must be a no-op, not a crash or a half-built slot.
	var state := SimState.for_level(Tuning.base())
	Hazards.start(state, 9999, null, SimClock.new(1337))
	assert_true(state.hazards.is_empty(), "an unknown kind should arm nothing")


## A payload of the wrong type is dropped rather than armed. `arm()` casts, and a
## failed cast yields null — appending a slot built from null would leave a hazard
## with a zero timer that fires instantly.
func test_a_mismatched_payload_arms_nothing() -> void:
	var state := SimState.for_level(Tuning.base())
	# A Knock kind handed a Cover payload.
	Hazards.start(state, SimEvent.Kind.KNOCK, SimEvent.CoverPayload.new(1.0, 2.0),
			SimClock.new(1337))
	assert_true(state.hazards.is_empty(), "a mismatched payload should arm nothing")


## The operators are stateless singletons — one instance per kind, reused. If a
## fresh one came back each call, any future per-operator caching would silently
## stop working, and the table would be allocating on the sim's hot path.
func test_operators_are_shared_instances() -> void:
	for kind in IMPLEMENTED:
		assert_eq(Hazards.operator_for(kind).get_instance_id(),
				Hazards.operator_for(kind).get_instance_id(),
				"kind %d handed back two different operator instances" % kind)


## Arming through the registry produces a slot in TELEGRAPH carrying the payload's
## own numbers — the contract PushSim and the view both read.
func test_arming_produces_a_telegraphing_slot() -> void:
	var state := SimState.for_level(Tuning.base())
	Hazards.start(state, SimEvent.Kind.KNOCK,
			SimEvent.KnockPayload.new(1.5, 2.0, 40.0, 0.35), SimClock.new(1337))

	assert_eq(state.hazards.size(), 1, "the knock should have armed exactly one slot")
	var slot: HazardSlot = state.hazards[0]
	assert_eq(slot.kind, SimEvent.Kind.KNOCK, "the slot should carry its own kind")
	assert_eq(slot.phase, HazardSlot.Phase.TELEGRAPH, "a hazard opens telegraphing")
	assert_eq(slot.timer, 1.5, "the telegraph length should come from the payload")
	assert_eq(slot.active_len, 2.0, "the window length should come from the payload")
	assert_eq(slot.cost, 40.0, "the cost should come from the payload")
	assert_eq(slot.grace, 0.35, "the grace should come from the payload")


## The Cover Window is the one that retires unscored, and the view's resolution
## flash and the hazard tallies both key off that bit.
func test_only_the_cover_window_retires_unscored() -> void:
	var clock := SimClock.new(1337)
	for kind in IMPLEMENTED:
		var state := SimState.for_level(Tuning.base())
		Hazards.start(state, kind, _payload_for(kind), clock)
		assert_eq(state.hazards.size(), 1, "kind %d failed to arm" % kind)
		var scored: bool = state.hazards[0].scored
		if kind == SimEvent.Kind.COVER:
			assert_false(scored, "a cover window is not a pass/fail reaction")
		else:
			assert_true(scored, "kind %d should count toward the hazard tallies" % kind)


func _payload_for(kind: int) -> RefCounted:
	match kind:
		SimEvent.Kind.KNOCK:
			return SimEvent.KnockPayload.new(1.5, 2.0, 40.0, 0.25)
		SimEvent.Kind.SMELL:
			return SimEvent.SmellPayload.new(1.2, 1.6, 18.0)
		SimEvent.Kind.JOLT:
			return SimEvent.JoltPayload.new(0.6, 1.5, 1.2)
		SimEvent.Kind.BUZZ:
			return SimEvent.BuzzPayload.new(1.0, 2.0, 15.0, 3.0)
		SimEvent.Kind.COVER:
			return SimEvent.CoverPayload.new(1.2, 4.0)
		_:
			return null
