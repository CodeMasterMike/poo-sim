@tool
extends McpTestSuite
## The Buzz — tap to dismiss, or bleed Composure until it rings out and takes
## Discretion with it.
##
## It's the only hazard that charges you continuously while unresolved, so these
## tests check both halves: the ongoing drain and the final hit.
##
## Buzz at t=2s, telegraph 1.0s, window 2.0s ⇒ rings out ~t=5s.


func suite_name() -> String:
	return "buzz"


func _make_level() -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0
	level.red_noise_rate = 0.0
	var tl: Array[SimEvent] = [SimEvent.buzz(2.0, 1.0, 2.0, 15.0, 3.0)]
	level.timeline = tl
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


func _run(tap_pattern: Callable, steps: int) -> SimState:
	var level := _make_level()
	var clock := SimClock.new(1337)
	level.resolve_timeline(SimClock.FIXED_DT, clock.rng)
	var state := _initial_state(level)
	var sim := PushSim.new()
	var scheduler := EventScheduler.new()
	scheduler.load_timeline(level.timeline)
	for _i in steps:
		if state.phase != SimState.Phase.PLAYING:
			break
		var intent := PlayerIntent.new()
		intent.holding = false
		intent.tap = bool(tap_pattern.call(clock.step))
		scheduler.tick(clock, state)
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return state


## A tap dismisses it cleanly, at no Discretion cost.
func test_tap_dismisses_the_buzz() -> void:
	var tap_once := func(s: int) -> bool: return s == 130  # shortly after it starts
	var state := _run(tap_once, int(6.0 / SimClock.FIXED_DT))

	assert_eq(state.hazards_passed, 1, "tapping should pass the buzz")
	assert_eq(state.hazards_failed, 0, "and not fail it")
	assert_eq(state.discretion, 100.0, "a dismissed phone costs no Discretion")


## Letting it ring out costs exactly its Discretion price.
func test_ignored_buzz_rings_out_and_costs_discretion() -> void:
	var never_tap := func(_s: int) -> bool: return false
	var state := _run(never_tap, int(6.0 / SimClock.FIXED_DT))

	assert_eq(state.hazards_failed, 1, "an unanswered buzz should ring out once")
	assert_eq(state.discretion, 85.0, "Discretion should drop by the 15-point cost")


## The distraction bleeds Composure the whole time it buzzes, so ignoring it is
## never free — it costs you before it ever rings out.
func test_buzzing_bleeds_composure_while_unresolved() -> void:
	var never_tap := func(_s: int) -> bool: return false
	var tap_immediately := func(s: int) -> bool: return s == 121
	var ignored := _run(never_tap, int(6.0 / SimClock.FIXED_DT))
	var dismissed := _run(tap_immediately, int(6.0 / SimClock.FIXED_DT))

	assert_gt(dismissed.composure, ignored.composure,
			"ignoring the buzz should cost more Composure than dismissing it")
