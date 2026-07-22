@tool
extends McpTestSuite
## The Smell Cloud: an EMERGENT hazard. Nothing schedules it — pushing in the red
## builds a charge that emits one, which is what turns the greedy line into a
## two-part decision (take the red, then deal with what it produces) instead of
## the flat unavoidable tax the old scripted version was.
##
## Covers: hard pushing emits one, staying in flow never does, a swipe wafts it
## for free, and ignoring it costs exactly its Discretion price.


func suite_name() -> String:
	return "smell"


## A bare level — no timeline at all, so anything that happens here is emergent.
func _make_level() -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0       # no ambient bleed; isolate the cloud's cost
	level.red_noise_rate = 0.0   # and no red-zone noise either
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


## `swipe_pattern` is Callable(step) -> Vector2, so a waft is a pure function of
## the step exactly like the hold pattern.
func _run(make_level: Callable, hold_pattern: Callable, swipe_pattern: Callable, steps: int) -> SimState:
	var level: LevelDef = make_level.call()
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
		intent.holding = bool(hold_pattern.call(clock.step))
		intent.swipe = swipe_pattern.call(clock.step)
		scheduler.tick(clock, state)
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return state


func _never_swipe() -> Callable:
	return func(_s: int) -> Vector2: return Vector2.ZERO


## Sustained red-zone pushing emits a cloud with nothing scheduled to do it.
func test_hard_pushing_emits_a_cloud() -> void:
	var always_hold := func(_s: int) -> bool: return true
	# ~6s: long enough to climb into the red and charge past the threshold.
	var state := _run(_make_level, always_hold, _never_swipe(), int(6.0 / SimClock.FIXED_DT))

	var seen := state.hazards.size() + state.hazards_passed + state.hazards_failed
	assert_gt(seen, 0, "pushing in the red should have emitted a Smell Cloud")


## Playing the flow line never produces one — the hazard is a consequence of
## greed, not a tax on time.
func test_flow_pushing_emits_no_cloud() -> void:
	var level := _make_level()
	var mid: float = (level.flow_bands[0].x + level.flow_bands[0].y) * 0.5
	var clock := SimClock.new(1337)
	var state := _initial_state(level)
	var sim := PushSim.new()
	# A bang-bang controller that parks the needle inside the Flow band.
	for _i in int(20.0 / SimClock.FIXED_DT):
		var intent := PlayerIntent.new()
		intent.holding = state.needle < mid
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()

	# A momentary overshoot may tick the charge up a hair before it bleeds off;
	# what matters is that it never approaches the emission threshold.
	assert_true(state.smell_charge < 0.5,
			"flow play should never approach the emission threshold (charge=%f)" % state.smell_charge)
	assert_eq(state.hazards.size(), 0, "no cloud should exist after 20s of clean flow play")
	assert_eq(state.hazards_failed, 0, "and nothing should have failed")


## A swipe disperses the cloud at no cost.
func test_swipe_wafts_the_cloud_for_free() -> void:
	var always_hold := func(_s: int) -> bool: return true
	var always_swipe := func(_s: int) -> Vector2: return Vector2(40.0, 0.0)
	var state := _run(_make_level, always_hold, always_swipe, int(8.0 / SimClock.FIXED_DT))

	assert_eq(state.discretion, 100.0, "a wafted cloud must cost no Discretion")
	assert_eq(state.hazards_failed, 0, "swiping must not fail the hazard")
	assert_gt(state.hazards_passed, 0, "the wafted cloud should have resolved as passed")


## Ignoring it lands the cloud for exactly its cost.
func test_ignored_cloud_costs_discretion() -> void:
	var always_hold := func(_s: int) -> bool: return true
	# telegraph 1.2 + window 1.6 = 2.8s after emission, so 8s is comfortably past it.
	var state := _run(_make_level, always_hold, _never_swipe(), int(8.0 / SimClock.FIXED_DT))

	assert_eq(state.hazards_failed, 1, "an ignored cloud should land exactly once")
	assert_eq(state.discretion, 82.0, "Discretion should drop by the 18-point cost")
