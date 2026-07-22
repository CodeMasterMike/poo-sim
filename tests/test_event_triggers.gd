@tool
extends McpTestSuite
## The scheduling layer: Relief-keyed triggers (pacing follows player progress,
## per the spec's three-act micro-curve) and seeded jitter (a sit varies by seed
## but replays identically for a given seed — fair mirrored boards, reproducible
## ghosts). This is the first thing in the sim that actually pulls from the
## match-seeded RNG.


func suite_name() -> String:
	return "triggers"


## Resolve a single jittered event and report the step it landed on.
func _resolved_step(seed_value: int, jitter: float) -> int:
	var level := LevelDef.new()
	var tl: Array[SimEvent] = [SimEvent.knock(6.0, 1.0, 2.0, 40.0).with_jitter(jitter)]
	level.timeline = tl
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	level.resolve_timeline(SimClock.FIXED_DT, rng)
	return level.timeline[0].step


## Jitter is rolled once from the match seed: the same seed must roll the same
## schedule, a different seed should reshuffle it, and the result must stay
## inside the authored window.
func test_jitter_is_seeded_and_bounded() -> void:
	var a := _resolved_step(1337, 1.5)
	var b := _resolved_step(1337, 1.5)
	var c := _resolved_step(9001, 1.5)

	assert_eq(a, b, "same seed must roll the same schedule")
	assert_ne(a, c, "a different seed should reshuffle the schedule")
	var lo := int((6.0 - 1.5) / SimClock.FIXED_DT)
	var hi := int((6.0 + 1.5) / SimClock.FIXED_DT)
	assert_true(a >= lo and a <= hi, "jittered step %d must land inside the +/-1.5s window" % a)


## Without jitter the trigger is exactly where it was authored, seed regardless.
func test_no_jitter_is_exact_and_seed_independent() -> void:
	var expected := int(6.0 / SimClock.FIXED_DT)
	assert_eq(_resolved_step(1337, 0.0), expected, "an unjittered event must not move")
	assert_eq(_resolved_step(9001, 0.0), expected, "and must not depend on the seed")


## A RELIEF-triggered event fires when progress crosses its threshold, not on a
## clock — so the curve tracks how the player is actually doing.
func test_relief_trigger_fires_on_progress_not_time() -> void:
	var level := LevelDef.new()
	level.smell_rate = 0.0      # only the event may move Discretion
	level.red_noise_rate = 0.0
	var tl: Array[SimEvent] = [SimEvent.meter(0.0, SimState.Meter.DISCRETION, -30.0).on_relief(20.0)]
	level.timeline = tl
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	level.resolve_timeline(SimClock.FIXED_DT, rng)

	var clock := SimClock.new(1337)
	var state := SimState.new()
	state.flow_bands = level.flow_bands.duplicate()
	state.flow_target_bands = level.flow_bands.duplicate()
	var sim := PushSim.new()
	var scheduler := EventScheduler.new()
	scheduler.load_timeline(level.timeline)

	var relief_when_fired := -1.0
	for _i in 6000:
		if state.phase != SimState.Phase.PLAYING:
			break
		var intent := PlayerIntent.new()
		intent.holding = true  # push so Relief climbs
		scheduler.tick(clock, state)
		if state.discretion < 100.0:
			relief_when_fired = state.relief
			break
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()

	assert_gt(relief_when_fired, 19.9, "event fired before Relief reached the 20% threshold")
	assert_true(relief_when_fired < 21.0,
			"event fired late, at %f%% Relief" % relief_when_fired)
	assert_eq(state.discretion, 70.0, "the -30 event should have applied exactly once")
