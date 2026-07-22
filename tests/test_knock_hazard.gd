@tool
extends McpTestSuite
## The Knock hazard, end to end through the sim: a scheduled KNOCK event arms a
## HazardSlot, and its ACTIVE window is a real detection test — release and hold
## still to pass, push to fail. Deterministic; no engine/scene needed.
##
## Knock at t=2s (no jitter), telegraph 1s, freeze 2s ⇒ ACTIVE runs steps ~[180, 300).


func suite_name() -> String:
	return "knock"


func _make_knock_level() -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0       # isolate Discretion changes to the hazard alone
	level.red_noise_rate = 0.0
	var tl: Array[SimEvent] = [SimEvent.knock(2.0, 1.0, 2.0, 40.0)]
	level.timeline = tl
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


func _run(make_level: Callable, seed_value: int, hold_pattern: Callable, steps: int) -> SimState:
	var level: LevelDef = make_level.call()
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
		scheduler.tick(clock, state)
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return state


## Releasing (no input) through the freeze passes the knock — Discretion untouched.
func test_release_passes_the_knock() -> void:
	var never_hold := func(_s: int) -> bool: return false
	var state := _run(_make_knock_level, 1337, never_hold, int(6.0 / SimClock.FIXED_DT))

	assert_eq(state.hazard_resolve_pulse, 1, "the knock should have resolved exactly once")
	assert_false(state.last_hazard_failed, "not holding must pass the knock")
	assert_eq(state.hazards_passed, 1, "a passed knock should count as passed")
	assert_eq(state.discretion, 100.0, "a passed knock costs no Discretion")
	assert_true(state.hazards.is_empty(), "resolved slots must be retired")


## A push during the freeze is audible: Discretion craters by exactly the cost, once.
func test_push_during_freeze_fails_and_craters_discretion() -> void:
	var hold_in_freeze := func(s: int) -> bool: return s >= 180 and s < 300
	var state := _run(_make_knock_level, 1337, hold_in_freeze, int(6.0 / SimClock.FIXED_DT))

	assert_true(state.last_hazard_failed, "pushing during the freeze must fail the knock")
	assert_eq(state.hazards_failed, 1, "a failed knock should count as failed")
	assert_eq(state.discretion, 60.0, "Discretion should crater by exactly the cost, once")


## The grace window forgives human reaction time: still mid-push when the freeze
## begins is fine, as long as you let go within it. Freeze starts ~step 179 and
## the default 0.25s grace covers ~15 steps, so releasing at 190 is in time.
func test_grace_window_forgives_a_late_release() -> void:
	var release_late := func(s: int) -> bool: return s < 190
	var state := _run(_make_knock_level, 1337, release_late, int(6.0 / SimClock.FIXED_DT))

	assert_false(state.last_hazard_failed, "releasing inside the grace window must still pass")
	assert_eq(state.hazards_passed, 1, "a late-but-in-time release should count as passed")
	assert_eq(state.discretion, 100.0, "no Discretion cost when the release lands in grace")


## Holding past the grace window still fails — grace forgives reaction time, not
## ignoring the knock outright.
func test_holding_past_grace_still_fails() -> void:
	var hold_through := func(s: int) -> bool: return s >= 180 and s < 300
	var state := _run(_make_knock_level, 1337, hold_through, int(6.0 / SimClock.FIXED_DT))

	assert_true(state.last_hazard_failed, "holding beyond the grace window must fail")
	assert_eq(state.discretion, 60.0, "Discretion craters by the cost, once")


## The freeze stalls Relief: it doesn't accrue across the freeze even while
## holding (which would otherwise fill fastest).
func test_freeze_stalls_relief() -> void:
	var hold_from_telegraph := func(s: int) -> bool: return s >= 150
	var at_freeze_start := _run(_make_knock_level, 1337, hold_from_telegraph, 180)
	var at_freeze_end := _run(_make_knock_level, 1337, hold_from_telegraph, 300)

	assert_gt(at_freeze_start.relief, 0.0, "Relief should have been accruing before the freeze")
	assert_true(absf(at_freeze_end.relief - at_freeze_start.relief) < 1.0,
			"Relief should be stalled through the freeze (delta=%f)" %
			(at_freeze_end.relief - at_freeze_start.relief))
