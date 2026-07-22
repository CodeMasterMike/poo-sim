@tool
extends McpTestSuite
## Guards the core guarantee of scripts/sim/: the simulation is deterministic and
## seeded (spec §17). Same seed + same per-step intents must reproduce a run
## bit-for-bit — that's what makes ghost replay and fair mirrored 1v1 boards
## possible. Also checks the lose path and that the timeline actually mutates a
## meter mid-run.


func suite_name() -> String:
	return "sim"


# ---------------------------------------------------------------- helpers

func _make_level() -> LevelDef:
	var level := LevelDef.new()
	level.timeline = LevelGreybox.timeline()
	level.resolve_timeline(SimClock.FIXED_DT)
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


## Run a whole match headlessly and return the final SimState. `hold_pattern` is
## a Callable(step: int) -> bool, so intents are a pure function of the step —
## the same contract the recorded ghost will satisfy.
func _run(level: LevelDef, seed_value: int, hold_pattern: Callable, max_steps: int) -> SimState:
	var clock := SimClock.new(seed_value)
	var state := _initial_state(level)
	var sim := PushSim.new()
	var scheduler := EventScheduler.new()
	scheduler.load_timeline(level.timeline)
	for _i in max_steps:
		if state.phase != SimState.Phase.PLAYING:
			break
		var intent := PlayerIntent.new()
		intent.holding = bool(hold_pattern.call(clock.step))
		scheduler.tick(clock, state)
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return state


# ---------------------------------------------------------------- tests

## The load-bearing test: two runs with the same seed and the same intent
## function land on an identical final state, field for field.
func test_same_seed_same_intents_reproduce_exactly() -> void:
	var pattern := func(step: int) -> bool: return (step % 30) < 22  # oscillate through all zones
	var a := _run(_make_level(), 1337, pattern, 600)
	var b := _run(_make_level(), 1337, pattern, 600)

	assert_eq(a.needle, b.needle, "needle diverged")
	assert_eq(a.needle_vel, b.needle_vel, "needle_vel diverged")
	assert_eq(a.relief, b.relief, "relief diverged")
	assert_eq(a.composure, b.composure, "composure diverged")
	assert_eq(a.discretion, b.discretion, "discretion diverged")
	assert_eq(a.cleanliness, b.cleanliness, "cleanliness diverged")
	assert_eq(a.flow_fill, b.flow_fill, "flow_fill diverged")
	assert_eq(a.total_fill, b.total_fill, "total_fill diverged")
	assert_eq(a.detection_count, b.detection_count, "detection_count diverged")
	# The oscillating pattern must actually exercise the systems, or "identical"
	# is a hollow pass.
	assert_gt(a.total_fill, 0.0, "run produced no Relief — pattern didn't exercise the sim")


## Composure hitting zero ends the run as a loss, not a win.
func test_composure_empty_is_a_loss() -> void:
	var level := _make_level()
	level.fill_dead = 0.0    # can never fill Relief...
	level.fill_flow = 0.0
	level.fill_red = 0.0
	level.composure_seconds = 2.0  # ...and Composure drains fast
	var never_hold := func(_step: int) -> bool: return false
	var state := _run(level, 1337, never_hold, 600)

	assert_eq(state.phase, SimState.Phase.LOST, "expected a Composure-out loss")
	assert_eq(state.composure, 0.0, "Composure should have bottomed out")


## A scripted METER event on the timeline changes a meter at its step, and not
## before. smell_rate is zeroed so the only Discretion change is the event.
func test_timeline_event_mutates_meter() -> void:
	var level := _make_level()
	level.smell_rate = 0.0
	var never_hold := func(_step: int) -> bool: return false

	# The grey-box smell event fires at t=11s (-22 Discretion). Sample before/after.
	var before := _run(level, 1337, never_hold, int(10.0 / SimClock.FIXED_DT))
	var after := _run(level, 1337, never_hold, int(13.0 / SimClock.FIXED_DT))

	assert_eq(before.discretion, 100.0, "Discretion should be untouched before the event")
	assert_eq(after.discretion, 78.0, "the -22 smell event should have applied by t=13s")
