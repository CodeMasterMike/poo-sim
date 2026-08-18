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
	var span := SimState.span_of(level.flow_bands)
	return (span.x + span.y) * 0.5


## Hold for `seconds` at a fixed needle height, with the needle PINNED — the point
## is to isolate fill from the needle physics, so each step re-clamps it.
func _run_pinned(level: LevelDef, needle: float, seconds: float) -> SimState:
	return SimHarness.on(level).pinned_at(needle).seconds(seconds).state


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
	var s := SimState.for_level(level)
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
	var s := SimState.for_level(level)
	s.needle = 1.0
	assert_eq(PushSim.density_of(0.5, level), 1.0, "0.5 thickness must be a 1.0x multiplier")
	assert_eq(PushSim.flow_rate(s, level), level.fill_red, "needle 1.0 must pay fill_red")
	# The dead anchor is now the shape of the curve's bottom, not a rate you can
	# actually collect at rest — the push gate zeroes it. Checked just above the
	# cutoff, where the gate is fully open again.
	s.needle = level.fill_cutoff
	assert_true(PushSim.flow_rate(s, level) > 0.0, "past the cutoff, flow should resume")


# ------------------------------------------------------------------ the gate

## Needle on the floor means you aren't pushing, so nothing comes out — the same
## read a Knock freeze gives, but for the ordinary case of simply letting go.
func test_nothing_comes_out_with_the_needle_on_the_floor() -> void:
	var level := _level()
	var s := SimState.for_level(level)
	s.needle = 0.0
	assert_eq(PushSim.flow_rate(s, level), 0.0, "a resting needle must produce nothing")


## And a whole run of never pushing produces nothing at all — no Relief, and an
## empty bowl. Previously this trickled in at fill_dead the entire time.
func test_never_pushing_produces_nothing() -> void:
	var level := _level()
	var state := _run_pinned(level, 0.0, 10.0)

	assert_eq(state.relief, 0.0, "idling should not fill Relief")
	assert_eq(state.total_fill, 0.0, "idling should not register any fill")
	assert_eq(state.bowl_mass(), 0.0, "idling should put nothing in the bowl")


## It FADES rather than switching, so the stream doesn't pop on and off as the
## needle drifts across the line.
func test_the_gate_eases_in_rather_than_snapping() -> void:
	var level := _level()
	var s := SimState.for_level(level)
	var seen: Array[float] = []
	for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
		s.needle = level.fill_cutoff * f
		seen.append(PushSim.flow_rate(s, level))

	assert_eq(seen[0], 0.0, "closed at the floor")
	assert_gt(seen[4], seen[2], "and rising through the fade")
	assert_gt(seen[2], seen[1], "no single step should carry the whole opening")


## Setting the cutoff to 0 restores the old always-on behaviour, so a level that
## wants a permanently-leaking sitter can still have one.
func test_a_zero_cutoff_disables_the_gate() -> void:
	var level := _level()
	level.fill_cutoff = 0.0
	var s := SimState.for_level(level)
	s.needle = 0.0
	assert_eq(PushSim.flow_rate(s, level), level.fill_dead, "needle 0 should pay fill_dead again")


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
##
## `bowl_mass() + chunk_mass()` since chunking landed — a lump in the air, and the
## piece still forming at the exit, are both matter that Relief has already been
## billed for and that the heightfield has not received yet.
func test_the_settle_conserves_mass() -> void:
	var level := _level()
	var state := _run_pinned(level, 0.85, 10.0)
	var expected := state.relief / 100.0 * float(SimState.BOWL_COLUMNS)
	var held := state.bowl_mass() + state.chunk_mass()

	assert_true(absf(held - expected) < 0.001,
			"bowl + air hold %f, Relief says %f" % [held, expected])


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


# --------------------------------------------------- the bowl's own consistency

## THE regression this exists for. Build a firm mound, then let go — and because
## letting go drives the EXIT to runny, the settle used to re-grade the whole pile
## and melt it flat. Matter already in the bowl does not change consistency because
## you stopped pushing.
## Note what is NOT asserted: that the peak is unchanged. A mound built by
## deposition is steeper than its own angle of repose — matter lands faster than
## the settle relaxes it — so when you stop, it finishes settling. That is the
## sandpile working. The bug was that it kept going all the way to FLAT, because a
## runny exit re-graded the whole bowl.
func test_a_mound_survives_letting_go() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var kept := _run_pinned(solid, _band_mid(solid), 10.0)
	assert_gt(kept.bowl_peak(), 0.0, "nothing was built to test with")

	# The identical pile, but with the bowl mis-graded runny — precisely what the
	# old code did the moment the exit went runny.
	var melted := _run_pinned(solid, _band_mid(solid), 10.0)
	melted.bowl_thickness = 0.0

	var level := _level()
	_idle(kept, level, 10.0)
	_idle(melted, level, 10.0)

	assert_true(kept.thickness < 0.15, "the exit should have gone runny (it did not)")
	assert_true(kept.bowl_thickness > 0.85, "the BOWL should still be firm")
	assert_gt(kept.bowl_peak(), melted.bowl_peak() * 1.5,
			"a firm bowl should hold its mound where a mis-graded one slumps flat")

	# And it settles to its repose angle and STOPS, rather than creeping flat.
	var settled := kept.bowl_peak()
	_idle(kept, level, 20.0)
	assert_true(kept.bowl_peak() > settled * 0.97,
			"the firm pile should have converged, went %f -> %f" % [settled, kept.bowl_peak()])


## Tick a state forward with the needle held on the floor — nothing coming out, so
## whatever moves is the settle alone.
func _idle(state: SimState, level: LevelDef, seconds: float) -> void:
	SimHarness.continuing(state, level).pinned_at(0.0).seconds(seconds)


## The mean is mass-weighted, so a brief dribble can't re-grade a big firm pile.
func test_the_bowl_consistency_is_mass_weighted() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var state := _run_pinned(solid, _band_mid(solid), 12.0)
	var firm := state.bowl_thickness

	var runny := _level(0.0)
	runny.thickness_push_gain = 0.0
	state.thickness = 0.0
	# One second of runny dribble onto the firm pile that is already there.
	SimHarness.continuing(state, runny).pinned_at(_band_mid(runny)).seconds(1.0)

	assert_true(state.bowl_thickness < firm, "the dribble should have counted for something")
	assert_true(state.bowl_thickness > firm * 0.7,
			"a short dribble should not re-grade the whole pile (%f -> %f)"
					% [firm, state.bowl_thickness])


## A uniform run leaves the bowl at exactly the consistency it was fed.
func test_a_uniform_run_matches_what_was_deposited() -> void:
	var level := _level(0.8)
	level.thickness_push_gain = 0.0
	var state := _run_pinned(level, _band_mid(level), 8.0)

	assert_true(absf(state.bowl_thickness - 0.8) < 0.01,
			"fed 0.8 throughout, the bowl reads %f" % state.bowl_thickness)


# ------------------------------------------------------------------- the line

## The run ends when the PILE REACHES THE LINE, not when a mass counter tops out.
func test_the_run_ends_when_the_pile_reaches_the_line() -> void:
	var level := _level()
	var state := _run_pinned(level, _band_mid(level), 120.0)

	assert_eq(state.phase, SimState.Phase.WON, "the sit should have been won")
	assert_true(state.bowl_peak() >= level.goal_height * 0.99,
			"won at a peak of %f, short of the %f line" % [state.bowl_peak(), level.goal_height])
	assert_true(state.relief < 100.0,
			"should have finished on height, with mass to spare — relief was %f" % state.relief)


## The payoff for the whole consistency model: a firm pile stacks and reaches the
## line on less mass than a runny one that spreads flat.
func test_a_firm_pile_reaches_the_line_on_less_than_a_runny_one() -> void:
	var firm := _level(1.0)
	firm.thickness_push_gain = 0.0
	var runny := _level(0.0)
	runny.thickness_push_gain = 0.0
	# Both get an unlimited clock. This is about SHAPE — how much mass each needs
	# to reach the line — and at the shipped 60s a fully-runny level genuinely
	# can't get there, which would make this fail for an unrelated reason.
	firm.composure_seconds = 1000.0
	runny.composure_seconds = 1000.0

	var a := _run_pinned(firm, _band_mid(firm), 200.0)
	var b := _run_pinned(runny, _band_mid(runny), 200.0)
	assert_eq(a.phase, SimState.Phase.WON, "the firm run should have finished")
	assert_eq(b.phase, SimState.Phase.WON, "the runny run should have finished")

	assert_gt(b.relief, a.relief * 1.2,
			"runny needed %f mass, firm only %f — the shape should matter" % [b.relief, a.relief])


## Raising the line asks for more.
func test_the_line_height_sets_how_much_is_needed() -> void:
	var low := _level()
	low.goal_height = 0.5
	var high := _level()
	high.goal_height = 1.0

	var a := _run_pinned(low, _band_mid(low), 200.0)
	var b := _run_pinned(high, _band_mid(high), 200.0)
	assert_eq(a.phase, SimState.Phase.WON, "the low line should have been reached")
	assert_eq(b.phase, SimState.Phase.WON, "the high line should have been reached")
	assert_gt(b.relief, a.relief, "a higher line should demand more")


## Progress never runs backwards, even though the pile settles when you stop.
func test_progress_is_a_high_water_mark() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var state := _run_pinned(solid, _band_mid(solid), 8.0)
	var reached := state.progress
	assert_gt(reached, 0.0, "nothing to test with")

	_idle(state, _level(), 10.0)
	assert_true(state.progress >= reached,
			"progress fell from %f to %f while resting" % [reached, state.progress])


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


## Where the stream landed on each step. Sampled a step at a time rather than in one
## run, because the whole question is how the landing point MOVES over the stretch.
func _drop_samples(level: LevelDef, needle: float, seconds: float) -> Array:
	var run := SimHarness.on(level).pinned_at(needle)
	var out := []
	for _i in int(seconds / SimClock.FIXED_DT):
		run.step(1)
		out.append(PushSim.drop_u(run.state, level))
	return out


# ------------------------------------------------------------------- chunking

## The consistency split that the whole look rests on: runny pours, solid breaks
## off. If this ever stops being true, the stream and the pile silently go back to
## describing one material.
func test_runny_pours_and_solid_breaks_off() -> void:
	var runny := _level(0.0)
	runny.thickness_push_gain = 0.0
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var mid := _band_mid(solid)

	assert_eq(PushSim.chunk_size(SimState.for_level(runny), runny), 0.0,
			"runny must never form a lump")
	assert_gt(PushSim.chunk_size(SimState.for_level(solid), solid), 0.0,
			"solid must form lumps")

	var poured := _run_pinned(runny, mid, 6.0)
	assert_eq(poured.chunk_mass(), 0.0, "a runny run left matter stuck at the exit")
	assert_gt(poured.bowl_mass(), 0.0, "a runny run put nothing in the bowl")


## A lump is heavy enough to be a countable event, not a per-tick drizzle wearing a
## costume. Both bounds matter: too few and the pile grows in visible jumps you
## can't aim between, too many and the emission loop is allocating a BowlChunk
## several times a frame (which is exactly what an early cut did — see
## PushSim.CHUNK_MIN_FRACTION).
func test_solid_leaves_in_a_countable_number_of_lumps() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var run := SimHarness.on(solid).pinned_at(_band_mid(solid))
	var lumps := 0
	var seen := 0
	for _i in int(10.0 / SimClock.FIXED_DT):
		run.step(1)
		var now: int = run.state.chunks.size()
		if now > seen:
			lumps += now - seen
		seen = now

	assert_gt(lumps, 8, "a whole solid run broke off only %d lumps" % lumps)
	assert_true(lumps < 200, "%d lumps in ten seconds is a drizzle, not chunks" % lumps)


## The landing point is scattered off the aim — this is the randomness the pile's
## shape is built from. Asserted as a SPREAD, not as a fixed offset: the roll is
## seeded, so what has to hold is that lumps go to different places, not that any
## particular one goes anywhere in particular.
func test_lumps_land_scattered_around_the_aim() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var run := SimHarness.on(solid).pinned_at(_band_mid(solid))
	# Identified by instance rather than by a zero fall time: a lump emitted this
	# step has ALREADY been advanced by _fall_chunks before the step returns, so it
	# is never observable at fall == 0.
	var seen := {}
	var offsets: Array[float] = []
	for _i in int(10.0 / SimClock.FIXED_DT):
		run.step(1)
		for c in run.state.chunks:
			var id: int = c.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				offsets.append(c.u - c.from_u)

	assert_gt(offsets.size(), 5, "no lumps to measure")
	var lo := 1.0
	var hi := -1.0
	for o in offsets:
		lo = minf(lo, o)
		hi = maxf(hi, o)
	assert_gt(hi - lo, solid.chunk_scatter, "lumps all broke off in the same direction")
	assert_true(hi <= solid.chunk_scatter + 0.001 and lo >= -solid.chunk_scatter - 0.001,
			"a lump scattered further than the level allows (%f..%f)" % [lo, hi])

## Matter ARRIVES IN LUMPS. This is the behavioural core of the whole change, and
## the thing every other part of it sits on: the pile grows in visible steps, the
## drawn cobbles have discrete landings to sit on, and `progress` therefore advances
## in jumps rather than as a smooth ramp.
##
## Asserted as the shape of the arrivals, not as surface roughness. Roughness looked
## like the obvious measure and is a bad one: a lump lands over a squashed footprint
## several columns wide, so it is actually a SMOOTHER deposit than the pour's
## two-column trickle, and which of the two reads rougher flips depending on when
## you sample. What is unambiguously true is that the bowl spends most of its ticks
## receiving nothing at all, and then takes a whole lump at once.
func test_matter_arrives_in_lumps_not_as_a_trickle() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var run := SimHarness.on(solid).pinned_at(_band_mid(solid))
	var quiet := 0
	var arrivals := 0
	var biggest := 0.0
	var held := 0.0
	for _i in int(8.0 / SimClock.FIXED_DT):
		run.step(1)
		var now: float = run.state.bowl_mass()
		var gained := now - held
		held = now
		if gained < 0.0001:
			quiet += 1
		else:
			arrivals += 1
			biggest = maxf(biggest, gained)

	assert_gt(arrivals, 4, "nothing ever landed")
	assert_gt(quiet, arrivals * 3,
			"the bowl received something on %d of %d ticks — that is a trickle, not lumps"
					% [arrivals, arrivals + quiet])
	# And each arrival is a real piece of the bowl, not a rounding error.
	assert_gt(biggest, 0.05, "the biggest single arrival was only %f" % biggest)


## The pour path is unchanged, and that is what keeps runny reading as it always
## did: a loose stool trickles in every tick it is producing.
func test_runny_still_arrives_every_tick() -> void:
	var runny := _level(0.0)
	runny.thickness_push_gain = 0.0
	var run := SimHarness.on(runny).pinned_at(_band_mid(runny))
	var quiet := 0
	var held := 0.0
	for _i in 240:
		run.step(1)
		var now: float = run.state.bowl_mass()
		if now - held < 0.0000001:
			quiet += 1
		held = now

	assert_true(quiet < 12, "a runny stream skipped %d of 240 ticks" % quiet)


## Matter in the air is matter that has left you and not arrived. It must be
## counted, and it must not sit there: a consistency change that stranded the
## pending lump at the exit would leak Relief the bowl never receives.
func test_nothing_is_stranded_at_the_exit_when_the_consistency_drops() -> void:
	var solid := _level(1.0)
	solid.thickness_push_gain = 0.0
	var state := _run_pinned(solid, _band_mid(solid), 5.0)
	assert_gt(state.chunk_mass(), 0.0, "nothing was in flight or forming to strand")

	# Now feed it runny — which takes the pour path and must flush what was pending.
	var runny := _level(0.0)
	runny.thickness_push_gain = 0.0
	state.thickness = 0.0
	SimHarness.continuing(state, runny).pinned_at(_band_mid(runny)).seconds(2.0)

	assert_eq(state.chunk_pending, 0.0, "the half-formed lump was left at the exit")
	var expected := state.relief / 100.0 * float(SimState.BOWL_COLUMNS)
	var held := state.bowl_mass() + state.chunk_mass()
	assert_true(absf(held - expected) < 0.001,
			"bowl + air hold %f, Relief says %f" % [held, expected])
