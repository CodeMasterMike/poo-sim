@tool
extends McpTestSuite
## The acoustic-window mechanic end to end, both polarities. A COVER-kind window
## flips the room's audibility from its baseline for its duration; while the room is
## exposed, bearing down above the cap bleeds Discretion. Church (baseline exposed) =
## a window shields you; Rave (baseline covered) = a window exposes you. Same sim,
## opposite feel. Deterministic; no engine/scene needed.
##
## The isolation level zeroes smell_rate/red_noise_rate so the ONLY thing that can
## move Discretion is the silence penalty — every assertion is then about exposure.
##
## Window cover(0.5, 0.5, 4.0): armed at step 30 (t=0.5), telegraph 0.5s ⇒ ACTIVE at
## step 60, duration 4.0s ⇒ resolves ~step 300.


func suite_name() -> String:
	return "cover_window"


## One isolation room. `baseline_exposed` picks the polarity (Church true / Rave
## false); a scheduled window is a COVER slot either way.
func _make_room(baseline_exposed: bool, with_window: bool, cap: float) -> LevelDef:
	var level := LevelDef.new()
	level.smell_rate = 0.0        # isolate Discretion changes to the silence penalty
	level.red_noise_rate = 0.0
	level.silence_noise_rate = 20.0
	level.silence_push_cap = cap
	level.baseline_exposed = baseline_exposed
	var tl: Array[SimEvent] = []
	if with_window:
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


# ---------------------------------------------------------------- Church polarity

## Pushing above the cap in silence is audible: Discretion bleeds at the silence rate.
func test_church_pushing_in_silence_bleeds_discretion() -> void:
	var always := func(_s: int) -> bool: return true
	var level := _make_room(true, false, 0.0)  # cap 0 ⇒ any push is audible
	var state := _run(level, 1337, always, 60)  # ~1s of audible silence

	assert_true(state.discretion < 95.0,
			"a full second of audible silence should bleed Discretion (got %f)" % state.discretion)
	assert_true(state.discretion > 70.0,
			"one second at 20/s shouldn't wipe more than ~20 (got %f)" % state.discretion)


## Staying below the cap in silence is safe — idle low and Discretion is untouched.
func test_church_below_cap_in_silence_is_safe() -> void:
	var never := func(_s: int) -> bool: return false
	var level := _make_room(true, false, 0.9)  # never holding ⇒ needle 0 < 0.9
	var state := _run(level, 1337, never, 120)

	assert_eq(state.discretion, 100.0, "below the cap makes no noise, even in silence")


## A Cover Window suppresses the silence penalty: Discretion stops falling for the
## whole ACTIVE stretch even while pushing hard.
func test_church_cover_suppresses_the_silence_penalty() -> void:
	var always := func(_s: int) -> bool: return true
	# Measure at the last silent step before cover (59) vs deep inside cover (200).
	var at_cover_start := _run(_make_room(true, true, 0.0), 1337, always, 60)
	var deep_in_cover := _run(_make_room(true, true, 0.0), 1337, always, 200)

	assert_true(at_cover_start.discretion < 100.0,
			"the silence before cover should have cost some Discretion (got %f)" % at_cover_start.discretion)
	assert_true(absf(deep_in_cover.discretion - at_cover_start.discretion) < 0.01,
			"no further Discretion should be lost under cover (delta=%f)" %
			(deep_in_cover.discretion - at_cover_start.discretion))


# ------------------------------------------------------------------ Rave polarity

## The inversion: with a covered baseline (the bass), bearing down hard is SAFE by
## default — the exact opposite of the Church's silent room.
func test_rave_default_bass_is_safe_while_pushing() -> void:
	var always := func(_s: int) -> bool: return true
	var level := _make_room(false, false, 0.0)  # covered baseline, no hush
	var state := _run(level, 1337, always, 120)

	assert_eq(state.discretion, 100.0, "under the bass, pushing hard costs no Discretion")


## A hush EXPOSES the covered room: once it goes active, pushing hard bleeds
## Discretion — while before it (still covered) the same push was free.
func test_rave_hush_exposes_the_room() -> void:
	var always := func(_s: int) -> bool: return true
	var before_hush := _run(_make_room(false, true, 0.0), 1337, always, 50)   # still covered
	var during_hush := _run(_make_room(false, true, 0.0), 1337, always, 200)  # hush active

	assert_eq(before_hush.discretion, 100.0, "before the hush the bass still covers you")
	assert_true(during_hush.discretion < 95.0,
			"a hush should expose you: pushing through it bleeds Discretion (got %f)" % during_hush.discretion)


# --------------------------------------------------------------- window lifecycle

## The window toggles the acoustic state for its duration, then off — and retires
## unscored, since a soundscape change is not a reaction the player passes or fails.
func test_window_toggles_then_retires_unscored() -> void:
	var never := func(_s: int) -> bool: return false

	var mid := _run(_make_room(true, true, 0.5), 1337, never, 120)  # inside [60, 300)
	assert_true(Hazards.acoustic_window_active(mid), "the window should be active mid-duration")

	var after := _run(_make_room(true, true, 0.5), 1337, never, 340)  # clear of the window
	assert_false(Hazards.acoustic_window_active(after), "the window should be gone after it ends")
	assert_true(after.hazards.is_empty(), "the resolved window must be retired")
	assert_eq(after.hazards_passed, 0, "an acoustic window is unscored — no pass tallied")
	assert_eq(after.hazard_resolve_pulse, 0, "an unscored window fires no resolution pulse")


# ------------------------------------------------------------------- level builds

## The Church factory builds a coherent exposed-baseline room with windows scheduled.
func test_church_level_builds() -> void:
	var level := LevelChurch.build()
	assert_true(level.silence_noise_rate > 0.0, "the Church must be a quiet room")
	assert_true(level.baseline_exposed, "the Church is exposed by default (silence)")
	assert_true(_count_windows(level) >= 3, "the Church should schedule several cover windows")


## The Rave factory builds a coherent covered-baseline room with hushes scheduled.
func test_rave_level_builds() -> void:
	var level := LevelRave.build()
	assert_true(level.silence_noise_rate > 0.0, "the Rave must be a quiet room")
	assert_false(level.baseline_exposed, "the Rave is covered by default (the bass)")
	assert_true(_count_windows(level) >= 3, "the Rave should schedule several hushes")


func _count_windows(level: LevelDef) -> int:
	var n := 0
	for ev in level.timeline:
		if ev.kind == SimEvent.Kind.COVER:
			n += 1
	return n
