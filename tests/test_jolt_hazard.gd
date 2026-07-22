@tool
extends McpTestSuite
## Jolt / Turbulence — the hazard that attacks The Push itself rather than a meter.
##
## Its cost is POSITIONAL: failing it subtracts nothing directly, it just leaves
## the needle where it threw you. These tests pin that down, because "failure
## costs no meter" is the kind of property that looks like a bug later.
##
## Jolt at t=2s, telegraph 0.6s, window 1.5s ⇒ it lands ~step 156.


func suite_name() -> String:
	return "jolt"


func _make_level(displacement: float = 1.2) -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0
	level.red_noise_rate = 0.0
	var tl: Array[SimEvent] = [SimEvent.jolt(2.0, 0.6, 1.5, displacement)]
	level.timeline = tl
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


func _run(seed_value: int, hold_pattern: Callable, swipe_pattern: Callable, steps: int) -> SimState:
	var level := _make_level()
	var clock := SimClock.new(seed_value)
	level.resolve_timeline(SimClock.FIXED_DT, clock.rng)
	var state := _initial_state(level)
	var sim := PushSim.new()
	var scheduler := EventScheduler.new()
	scheduler.load_timeline(level.timeline)
	for _i in steps:
		if state.phase != SimState.Phase.PLAYING:
			break
		var intent := PlayerIntent.new()
		intent.holding = bool(hold_pattern.call(clock.step))
		intent.swipe = swipe_pattern.call(clock.step)
		scheduler.tick(clock, state)
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return state


func _no_swipe() -> Callable:
	return func(_s: int) -> Vector2: return Vector2.ZERO


## The jolt shoves the needle: velocity is meaningfully disturbed when it lands.
func test_jolt_displaces_the_needle() -> void:
	var never_hold := func(_s: int) -> bool: return false
	# Sample just after it lands (~step 156) but before the window closes.
	var jolted := _run(1337, never_hold, _no_swipe(), 170)

	assert_true(absf(jolted.needle_vel) > 0.2,
			"the jolt should have imparted real velocity (got %f)" % jolted.needle_vel)


## Ignoring it fails the hazard but costs no meter directly — the damage is
## entirely positional, routed through the systems already in place.
func test_ignored_jolt_costs_no_meter_directly() -> void:
	var never_hold := func(_s: int) -> bool: return false
	var state := _run(1337, never_hold, _no_swipe(), int(5.0 / SimClock.FIXED_DT))

	assert_eq(state.hazards_failed, 1, "an unanswered jolt should resolve as failed")
	assert_eq(state.discretion, 100.0, "a failed jolt must not deduct Discretion itself")
	assert_eq(state.cleanliness, 100.0, "nor Cleanliness")


## Swiping inside the window re-centres the needle and passes the hazard.
func test_swipe_recenters_and_passes() -> void:
	var never_hold := func(_s: int) -> bool: return false
	var swipe_after_landing := func(s: int) -> Vector2:
		return Vector2(40.0, 0.0) if s >= 160 else Vector2.ZERO
	var state := _run(1337, never_hold, swipe_after_landing, int(5.0 / SimClock.FIXED_DT))

	assert_eq(state.hazards_passed, 1, "swiping in the window should pass the jolt")
	assert_eq(state.hazards_failed, 0, "and it should not also count as failed")


## Direction comes from the match-seeded RNG, so a given seed always jolts the
## same way — the property mirrored 1v1 boards and ghost replay depend on.
func test_jolt_direction_is_seeded() -> void:
	var never_hold := func(_s: int) -> bool: return false
	var a := _run(1337, never_hold, _no_swipe(), 170)
	var b := _run(1337, never_hold, _no_swipe(), 170)

	assert_eq(a.needle_vel, b.needle_vel, "same seed must jolt identically")
	assert_eq(a.needle, b.needle, "and land the needle in the same place")
