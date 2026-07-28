@tool
extends McpTestSuite
## The Cover Window hazard end to end through the sim: a scheduled COVER event lifts
## the quiet-room silence penalty for its duration. In silence (no active cover) a
## needle above the cap bleeds Discretion; under cover it doesn't. Deterministic; no
## engine/scene needed.
##
## The isolation level zeroes smell_rate/red_noise_rate so the ONLY thing that can
## move Discretion is the silence penalty — every assertion is then about cover.
##
## Cover event cover(0.5, 0.5, 4.0): armed at step 30 (t=0.5), telegraph 0.5s ⇒
## ACTIVE at step 60, duration 4.0s ⇒ back to silence at step 240.


func suite_name() -> String:
	return "cover_window"


func _make_quiet_level(with_cover: bool, cap: float) -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0        # isolate Discretion changes to the silence penalty
	level.red_noise_rate = 0.0
	level.silence_noise_rate = 20.0
	level.silence_push_cap = cap
	var tl: Array[SimEvent] = []
	if with_cover:
		tl.append(SimEvent.cover(0.5, 0.5, 4.0))
	level.timeline = tl
	return level


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	return s


func _run(level: LevelDef, seed_value: int, hold_pattern: Callable, steps: int) -> SimState:
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


## Pushing above the cap in silence is audible: Discretion bleeds at the silence rate.
func test_pushing_in_silence_bleeds_discretion() -> void:
	var always := func(_s: int) -> bool: return true
	var level := _make_quiet_level(false, 0.0)  # cap 0 ⇒ any push is audible
	var state := _run(level, 1337, always, 60)  # ~1s of audible silence

	assert_true(state.discretion < 95.0,
			"a full second of audible silence should bleed Discretion (got %f)" % state.discretion)
	assert_true(state.discretion > 70.0,
			"one second at 20/s shouldn't wipe more than ~20 (got %f)" % state.discretion)


## Staying below the cap in silence is safe — idle low and Discretion is untouched.
func test_below_cap_in_silence_is_safe() -> void:
	var never := func(_s: int) -> bool: return false
	var level := _make_quiet_level(false, 0.9)  # never holding ⇒ needle 0 < 0.9
	var state := _run(level, 1337, never, 120)

	assert_eq(state.discretion, 100.0, "below the cap makes no noise, even in silence")


## A Cover Window suppresses the silence penalty: Discretion stops falling for the
## whole ACTIVE stretch even while pushing hard.
func test_cover_suppresses_the_silence_penalty() -> void:
	var always := func(_s: int) -> bool: return true
	# Measure at the last silent step before cover (59) vs deep inside cover (200).
	var at_cover_start := _run(_make_quiet_level(true, 0.0), 1337, always, 60)
	var deep_in_cover := _run(_make_quiet_level(true, 0.0), 1337, always, 200)

	assert_true(at_cover_start.discretion < 100.0,
			"the silence before cover should have cost some Discretion (got %f)" % at_cover_start.discretion)
	assert_true(absf(deep_in_cover.discretion - at_cover_start.discretion) < 0.01,
			"no further Discretion should be lost under cover (delta=%f)" %
			(deep_in_cover.discretion - at_cover_start.discretion))


## The window toggles cover on for its duration, then off — and retires unscored,
## since a hymn ending is not a reaction the player passes or fails.
func test_cover_window_toggles_then_retires_unscored() -> void:
	var never := func(_s: int) -> bool: return false

	var mid := _run(_make_quiet_level(true, 0.5), 1337, never, 120)  # inside [60, 240)
	assert_true(Hazards.under_cover(mid), "cover should be active mid-window")

	var after := _run(_make_quiet_level(true, 0.5), 1337, never, 340)  # clear of the window
	assert_false(Hazards.under_cover(after), "cover should be gone after the window ends")
	assert_true(after.hazards.is_empty(), "the resolved window must be retired")
	assert_eq(after.hazards_passed, 0, "a cover window is unscored — no pass tallied")
	assert_eq(after.hazard_resolve_pulse, 0, "an unscored window fires no resolution pulse")


## The Church factory builds a coherent quiet room with cover windows scheduled.
func test_church_level_builds_with_cover() -> void:
	var level := LevelChurch.build()
	assert_true(level.silence_noise_rate > 0.0, "the Church must be a quiet room")
	assert_false(level.timeline.is_empty(), "the Church needs a timeline")
	var covers := 0
	for ev in level.timeline:
		if ev.kind == SimEvent.Kind.COVER:
			covers += 1
	assert_true(covers >= 3, "the Church should schedule several cover windows (got %d)" % covers)
