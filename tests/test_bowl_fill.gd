@tool
extends McpTestSuite
## Guards the consistency model and the bowl's settle.
##
## Two things are load-bearing here. First, fill rate is no longer flat: where the
## needle sits INSIDE the Flow band changes how fast you fill, and thicker matter
## fills faster than runny. Second, the settle only ever MOVES matter — the pile is
## a redistribution of the Relief you earned, never a source of it, so a lumpy pile
## can't win the run early.


func suite_name() -> String:
	return "bowl"


## The SHARED tuning, not LevelDef's code defaults — these assertions are meant to
## hold for whatever is actually tuned in base_tuning.tres. If a tuning change
## breaks one (runny stops levelling flat, the in-band gradient goes to zero) that
## is the suite doing its job, not a stale fixture.
func _level(base_thickness: float = 0.5) -> LevelDef:
	var l := Tuning.base()
	l.thickness_base = base_thickness
	return l


## The middle of the level's OWN Flow band. Read off the level under test, never
## off a fresh LevelDef — otherwise tuning the band in the shared .tres would pin
## the needle somewhere the band no longer is.
func _band_mid(level: LevelDef) -> float:
	if level.flow_bands.is_empty():
		return 0.5
	var band: Vector2 = level.flow_bands[0]
	return (band.x + band.y) * 0.5


func _state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	s.thickness = level.thickness_base
	return s


## Hold for `seconds` at a fixed needle height, with the needle PINNED — the point
## is to isolate fill from the needle physics, so each step re-clamps it.
func _run_pinned(level: LevelDef, needle: float, seconds: float) -> SimState:
	var state := _state(level)
	var clock := SimClock.new(1337)
	var sim := PushSim.new()
	var intent := PlayerIntent.new()
	var steps := int(seconds / SimClock.FIXED_DT)
	for _i in steps:
		if state.phase != SimState.Phase.PLAYING:
			break
		state.needle = needle
		state.needle_vel = 0.0
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return state


# ------------------------------------------------------------------ fill rate

## The complaint that started this: a flat band meant scraping the floor of the
## Flow Zone filled exactly as fast as riding its ceiling.
func test_position_inside_the_flow_band_changes_the_rate() -> void:
	var level := _level()
	var band: Vector2 = level.flow_bands[0]
	var low := _run_pinned(level, band.x + 0.005, 6.0)
	var high := _run_pinned(level, band.y - 0.005, 6.0)

	assert_gt(high.relief, low.relief * 1.15,
			"riding the top of the band should fill meaningfully faster than its floor")
	# ...and both must still be genuine flow-zone fill, not a red-zone leak.
	assert_eq(PushSim.zone_of(low), PushSim.ZONE_FLOW, "low sample left the band")
	assert_eq(PushSim.zone_of(high), PushSim.ZONE_FLOW, "high sample left the band")


## The rate curve is continuous and rising: dead < band floor < band ceiling < red.
func test_fill_rate_rises_monotonically_with_the_needle() -> void:
	var level := _level()
	var band: Vector2 = level.flow_bands[0]
	var s := _state(level)
	var samples := [0.0, band.x * 0.5, band.x, (band.x + band.y) * 0.5, band.y, 1.0]
	var prev := -1.0
	for n in samples:
		s.needle = n
		var rate := PushSim.flow_rate(s, level)
		assert_gt(rate, prev, "rate should rise with the needle (broke at %f)" % n)
		prev = rate


## A level that leaves thickness neutral must fill at exactly the old anchors, or
## every pacing number in LevelDef (the 80s Composure, the 45-75s sit) is invalid.
func test_neutral_thickness_preserves_the_tuned_anchors() -> void:
	var level := _level(0.5)
	var s := _state(level)
	s.needle = 1.0
	assert_eq(PushSim.density_of(0.5, level), 1.0, "0.5 thickness must be a 1.0x multiplier")
	assert_eq(PushSim.flow_rate(s, level), level.fill_red, "needle 1.0 must pay fill_red")
	s.needle = 0.0
	assert_eq(PushSim.flow_rate(s, level), level.fill_dead, "needle 0 must pay fill_dead")


## The headline of the change: thicker fills faster, on identical inputs.
func test_thicker_fills_faster() -> void:
	var mid := _band_mid(_level())
	# thickness_push_gain is zeroed so the ONLY difference is the level baseline.
	var runny := _level(0.1)
	runny.thickness_push_gain = 0.0
	var solid := _level(0.9)
	solid.thickness_push_gain = 0.0

	var a := _run_pinned(runny, mid, 8.0)
	var b := _run_pinned(solid, mid, 8.0)
	assert_gt(b.relief, a.relief * 1.5, "solid should fill far faster than runny")


## Thickness must LAG the needle. A flick into the red gets the rate curve but not
## the density bonus — you only get thick by committing to the push.
func test_thickness_lags_the_needle() -> void:
	var level := _level()
	var flick := _run_pinned(level, 1.0, 0.2)
	var committed := _run_pinned(level, 1.0, 4.0)

	assert_gt(committed.thickness, flick.thickness, "sustained pressure should thicken it")
	assert_true(flick.thickness < level.thickness_base + 0.1,
			"a 0.2s flick should barely move thickness (was %f)" % flick.thickness)


# --------------------------------------------------------------------- settle

## The load-bearing invariant: the settle redistributes, it never creates. If this
## fails, a loose pile could reach the rim on less Relief than it should.
func test_the_settle_conserves_mass() -> void:
	var level := _level()
	var state := _run_pinned(level, 0.85, 10.0)
	var expected := state.relief / 100.0 * float(SimState.BOWL_COLUMNS)

	assert_true(absf(state.bowl_mass() - expected) < 0.001,
			"bowl holds %f, Relief says %f" % [state.bowl_mass(), expected])


## Runny self-levels into a flat pool; solid holds a mound where it landed. This
## is the angle of repose doing its job, and it's the whole visual payoff.
func test_runny_levels_flat_and_solid_stacks() -> void:
	var mid := _band_mid(_level())

	var runny := _level(0.0)
	runny.thickness_push_gain = 0.0
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0

	var a := _run_pinned(runny, mid, 12.0)
	var b := _run_pinned(solid, mid, 12.0)

	# Peak-to-average: 1.0 is perfectly flat, higher is a mound. Runny can't reach
	# a dead-flat 1.0 here — the needle is pinned, so every drop lands on the same
	# column and that column always carries one tick of un-slumped deposit. A
	# stream dimpling its own landing point is correct; anything under ~1.2 reads
	# as a pool.
	var a_ratio := a.bowl_peak() / (a.bowl_mass() / float(SimState.BOWL_COLUMNS))
	var b_ratio := b.bowl_peak() / (b.bowl_mass() / float(SimState.BOWL_COLUMNS))

	assert_true(a_ratio < 1.20, "runny should be near-flat, peak/mean was %f" % a_ratio)
	assert_gt(b_ratio, 1.6, "solid should hold a mound, peak/mean was %f" % b_ratio)
	# The contrast is the point, not either number on its own.
	assert_gt(b_ratio, a_ratio * 1.5, "runny and solid should settle visibly differently")


# ------------------------------------------------------------------------ aim

## The landing point must stay CENTRED however hard you push. An earlier version
## mapped needle height onto lateral position, so a hard run built its whole pile
## against one wall and never touched the other — this is the guard against that
## coming back.
func test_the_landing_point_stays_centred_however_hard_you_push() -> void:
	var level := _level()
	for needle in [0.05, 0.55, 1.0]:
		var mean := _mean_drop(level, needle, 12.0)
		assert_true(absf(mean - 0.5) < 0.03,
				"pushing at %f drifted the mean landing point to %f" % [needle, mean])


## Force buys amplitude, not direction: bear down and the stream hunts wider.
func test_a_harder_push_widens_the_wander() -> void:
	var level := _level()
	assert_gt(_drop_span(level, 1.0, 12.0), _drop_span(level, 0.55, 12.0) * 1.4,
			"a full-force push should wander noticeably wider than a gentle one")


## The environment gets the same handle — this is what an airplane level cranks.
func test_turbulence_widens_the_wander_further() -> void:
	var level := _level()
	var calm := _drop_span(level, 0.55, 12.0)

	var shaken := _level()
	shaken.sway_ambient += shaken.sway_turbulence  # what an ACTIVE Jolt adds
	var rough := _drop_span(shaken, 0.55, 12.0)

	assert_gt(rough, calm * 1.5, "a shaking room should throw the stream much wider")


## An ACTIVE Jolt is what supplies that turbulence, scaled by its impulse.
func test_an_active_jolt_reports_turbulence() -> void:
	var state := SimState.new()
	assert_eq(Hazards.turbulence(state), 0.0, "a calm room should report no turbulence")

	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.JOLT
	slot.phase = HazardSlot.Phase.TELEGRAPH
	slot.cost = JoltHazard.FULL_SHAKE_IMPULSE
	state.hazards.append(slot)
	assert_eq(Hazards.turbulence(state), 0.0, "a telegraphing Jolt isn't shaking you yet")

	slot.phase = HazardSlot.Phase.ACTIVE
	assert_eq(Hazards.turbulence(state), 1.0, "a landed Jolt should shake you")

	# ...and a gentler shove shakes you proportionally less, which is the whole
	# reason this is a 0..1 scale rather than a flag.
	slot.cost = JoltHazard.FULL_SHAKE_IMPULSE * 0.5
	assert_eq(Hazards.turbulence(state), 0.5, "a half-strength jolt should half-shake you")


## Walk a pinned run and report the mean landing point across it.
func _mean_drop(level: LevelDef, needle: float, seconds: float) -> float:
	var total := 0.0
	var n := 0
	for u in _drop_samples(level, needle, seconds):
		total += u
		n += 1
	return 0.5 if n == 0 else total / float(n)


## ...and the peak-to-peak spread, which is what "wander" means.
func _drop_span(level: LevelDef, needle: float, seconds: float) -> float:
	var lo := 1.0
	var hi := 0.0
	for u in _drop_samples(level, needle, seconds):
		lo = minf(lo, u)
		hi = maxf(hi, u)
	return hi - lo


func _drop_samples(level: LevelDef, needle: float, seconds: float) -> Array:
	var state := _state(level)
	var clock := SimClock.new(1337)
	var sim := PushSim.new()
	var intent := PlayerIntent.new()
	var out := []
	for _i in int(seconds / SimClock.FIXED_DT):
		state.needle = needle
		state.needle_vel = 0.0
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
		out.append(PushSim.drop_u(state, level))
	return out
