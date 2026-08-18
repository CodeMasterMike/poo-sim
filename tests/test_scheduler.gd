@tool
extends McpTestSuite
## The two timeline arms nothing else covers: FLOW_ZONE, which moves the Flow band
## (optionally easing it into place), and PROMPT, which holds text in the band for
## a while and then takes it away.
##
## The hazard arms have a suite each, and test_event_triggers covers the trigger
## families and the seeded jitter. What was left unguarded was the part the
## grey-box timeline leans on hardest — it moves the band four times in a run —
## plus `_ramp_flow_bands`, whose snap-on-a-band-count-change branch had never been
## executed by anything.


func suite_name() -> String:
	return "scheduler"


## A ready-to-tick rig — SimHarness, which is where this shape ended up living for
## every suite. Kept as a local factory because these tests read BOTH the state and
## the scheduler (`last_prompt` lives on the latter), and because a rig that steps
## incrementally is the only way to assert on the moment an event fires.
func _rig(level_def: LevelDef, seed_value: int = 1337) -> SimHarness:
	return SimHarness.on(level_def, seed_value)


const OPENING := Vector2(0.50, 0.72)


## A bare level whose only content is the events handed in — nothing scheduled,
## nothing ambient, so anything that changes is the event under test.
func _level(events: Array[SimEvent]) -> LevelDef:
	var l := LevelDef.new()
	l.flow_bands = [OPENING] as Array[Vector2]
	l.smell_rate = 0.0
	l.red_noise_rate = 0.0
	l.timeline = events
	return l


# ------------------------------------------------------------------- FLOW_ZONE

## A ramp of 0 means "be there now".
func test_a_flow_zone_event_with_no_ramp_snaps_the_band() -> void:
	var moved := Vector2(0.20, 0.30)
	# t=0.5s ⇒ fires on step 30.
	var rig := _rig(_level([SimEvent.flow_zone(0.5, [moved] as Array[Vector2], 0.0)]))

	rig.step(29)
	assert_eq(rig.state.flow_bands[0], OPENING, "the band moved before its event fired")
	rig.step(5)
	assert_eq(rig.state.flow_bands[0], moved, "a ramp of 0 should put the band there outright")


## A ramp eases: the band has to be genuinely in transit a step after the event,
## not already parked on the target.
func test_a_ramped_flow_zone_eases_rather_than_jumping() -> void:
	var moved := Vector2(0.20, 0.30)
	var rig := _rig(_level([SimEvent.flow_zone(0.5, [moved] as Array[Vector2], 2.0)]))

	rig.step(32)   # just past the trigger
	var mid: Vector2 = rig.state.flow_bands[0]
	assert_eq(rig.state.flow_target_bands[0], moved, "the TARGET should be set immediately")
	assert_true(mid.x < OPENING.x and mid.x > moved.x,
			"the band should be in transit, not at either end (x was %f)" % mid.x)

	# ...and it does arrive. The ease is exponential, so this checks "near enough",
	# which is what the player sees.
	rig.step(600)   # 10s, five ramp lengths
	assert_true(absf(rig.state.flow_bands[0].x - moved.x) < 0.005,
			"the band should have settled on its target (x was %f)" % rig.state.flow_bands[0].x)


## Splitting one band into two can't be a lerp — there is no pairing between a
## one-band set and a two-band one — so it snaps, ramp or no ramp. This is the
## branch that had never run.
func test_a_change_in_band_count_snaps_even_with_a_ramp() -> void:
	var split: Array[Vector2] = [Vector2(0.30, 0.42), Vector2(0.62, 0.74)]
	var rig := _rig(_level([SimEvent.flow_zone(0.5, split, 2.0)]))

	rig.step(32)
	assert_eq(rig.state.flow_bands.size(), 2, "the split should have taken effect at once")
	assert_eq(rig.state.flow_bands[0], split[0], "first band should be exactly as authored")
	assert_eq(rig.state.flow_bands[1], split[1], "second band should be exactly as authored")


# ---------------------------------------------------------------------- PROMPT

## A prompt goes up when its event fires and comes down `hold` seconds later.
func test_a_prompt_shows_then_expires() -> void:
	# t=0.5s ⇒ up on step 30; hold 2.0s ⇒ 120 steps ⇒ down on step 150.
	var rig := _rig(_level([SimEvent.prompt(0.5, "THE FINAL PUSH", 2.0)]))

	rig.step(25)
	assert_eq(rig.scheduler.last_prompt, "", "nothing should be showing before the event")
	rig.step(10)
	assert_eq(rig.scheduler.last_prompt, "THE FINAL PUSH", "the prompt should be up")
	rig.step(100)   # step ~135, still inside the hold
	assert_eq(rig.scheduler.last_prompt, "THE FINAL PUSH", "it should still be up mid-hold")
	rig.step(30)    # past step 150
	assert_eq(rig.scheduler.last_prompt, "", "the prompt should have expired")


# ----------------------------------------------------------------------- METER

## Relief is no longer a meter, and a scripted METER event must not be able to
## pretend otherwise. It is mass in the bowl now, and the run finishes on the
## pile's HEIGHT — so a bare `relief +=` writes a number the bowl doesn't back, and
## since the win also trips at `relief >= 100`, a scripted +100 used to end the sit
## instantly over an empty bowl.
func test_a_meter_event_cannot_grant_relief() -> void:
	expect_script_error_containing("RELIEF is not directly settable")
	var rig := _rig(_level([SimEvent.meter(0.5, SimState.Meter.RELIEF, 100.0)]))

	rig.step(60)
	assert_eq(rig.state.relief, 0.0, "the event must not have granted any Relief")
	assert_eq(rig.state.bowl_mass(), 0.0, "and nothing should have appeared in the bowl")
	assert_eq(rig.state.phase, SimState.Phase.PLAYING, "the sit must not have been won outright")


## The meters that ARE meters still take a delta, so refusing Relief didn't break
## the arm it lives on.
func test_a_meter_event_still_moves_a_real_meter() -> void:
	var rig := _rig(_level([SimEvent.meter(0.5, SimState.Meter.CLEANLINESS, -30.0)]))

	rig.step(25)
	assert_eq(rig.state.cleanliness, 100.0, "untouched before the event")
	rig.step(10)
	assert_eq(rig.state.cleanliness, 70.0, "the -30 should have applied exactly once")
