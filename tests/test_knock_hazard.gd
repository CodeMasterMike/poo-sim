@tool
extends McpTestSuite
## The Knock hazard, end to end through the sim: a scheduled KNOCK event arms it,
## and the freeze window is a real detection test — release and hold still to
## pass, push to fail. Deterministic; no engine/scene needed.
##
## Knock at t=2s, telegraph 1s, freeze 2s ⇒ FREEZE runs steps ~[180, 300).


func suite_name() -> String:
	return "knock"


func _level_with_knock(at: float, telegraph: float, freeze: float, cost: float) -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0       # isolate Discretion changes to the hazard alone
	level.red_noise_rate = 0.0
	var tl: Array[SimEvent] = [SimEvent.knock(at, telegraph, freeze, cost)]
	level.timeline = tl
	level.resolve_timeline(SimClock.FIXED_DT)
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


func _run(level: LevelDef, seed_value: int, hold_pattern: Callable, steps: int) -> SimState:
	var clock := SimClock.new(seed_value)
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
	var level := _level_with_knock(2.0, 1.0, 2.0, 40.0)
	var never_hold := func(_s: int) -> bool: return false
	var state := _run(level, 1337, never_hold, int(6.0 / SimClock.FIXED_DT))

	assert_eq(state.knock_phase, KnockHazard.Phase.RESOLVED, "knock should have resolved")
	assert_false(state.knock_failed, "not holding must pass the knock")
	assert_eq(state.discretion, 100.0, "a passed knock costs no Discretion")


## A push during the freeze is audible: Discretion craters by exactly the cost, once.
func test_push_during_freeze_fails_and_craters_discretion() -> void:
	var level := _level_with_knock(2.0, 1.0, 2.0, 40.0)
	var hold_in_freeze := func(s: int) -> bool: return s >= 180 and s < 300
	var state := _run(level, 1337, hold_in_freeze, int(6.0 / SimClock.FIXED_DT))

	assert_true(state.knock_failed, "pushing during the freeze must fail the knock")
	assert_eq(state.discretion, 60.0, "Discretion should crater by exactly the cost, once")


## The freeze stalls Relief: it doesn't accrue across the freeze even while holding
## (which would otherwise fill fastest).
func test_freeze_stalls_relief() -> void:
	var level := _level_with_knock(2.0, 1.0, 2.0, 40.0)
	var hold_from_telegraph := func(s: int) -> bool: return s >= 150
	var at_freeze_start := _run(level, 1337, hold_from_telegraph, 180)
	var at_freeze_end := _run(level, 1337, hold_from_telegraph, 300)

	assert_gt(at_freeze_start.relief, 0.0, "Relief should have been accruing before the freeze")
	assert_true(absf(at_freeze_end.relief - at_freeze_start.relief) < 1.0,
			"Relief should be stalled through the freeze (delta=%f)" %
			(at_freeze_end.relief - at_freeze_start.relief))
