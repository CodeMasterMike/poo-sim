@tool
extends McpTestSuite
## Split Flow Zones — two bands with a dead notch between them.
##
## `zone_of()` and `_curve_rate()` each carry a branch for this, SimState's comment
## promises "a split is simply two elements — no reshape needed later", and no
## level has ever authored one. So the whole feature shipped built and unexercised.
## These are the assertions that keep it honest until a level uses it.
##
## The load-bearing rule is the notch: a gap that paid the flow rate would make
## splitting the zone free, and the split would stop being a difficulty at all.


func suite_name() -> String:
	return "split_zone"


const LOW := Vector2(0.30, 0.42)
const HIGH := Vector2(0.62, 0.74)
const GAP := 0.52     ## squarely between the two bands


func _level() -> LevelDef:
	var l := Tuning.base()
	l.flow_bands = [LOW, HIGH] as Array[Vector2]
	return l


func _at(level: LevelDef, needle: float) -> SimState:
	var s := SimState.for_level(level)
	s.needle = needle
	return s


# --------------------------------------------------------------------- the zones

func test_either_band_counts_as_flow() -> void:
	var level := _level()
	for needle in [LOW.x, 0.36, LOW.y, HIGH.x, 0.68, HIGH.y]:
		assert_eq(PushSim.zone_of(_at(level, needle)), PushSim.ZONE_FLOW,
				"needle %f sits in a band and should read as FLOW" % needle)


func test_outside_both_bands_reads_red_above_and_dead_below() -> void:
	var level := _level()
	assert_eq(PushSim.zone_of(_at(level, 0.90)), PushSim.ZONE_RED,
			"above the TOP band is the red zone")
	assert_eq(PushSim.zone_of(_at(level, 0.10)), PushSim.ZONE_DEAD,
			"below the bottom band is the dead zone")


## The notch is dead, not a quiet stretch of flow.
func test_the_gap_between_the_bands_is_dead() -> void:
	assert_eq(PushSim.zone_of(_at(_level(), GAP)), PushSim.ZONE_DEAD,
			"the gap between two bands must not count as flow")


# ---------------------------------------------------------------------- the rate

## And it pays the dead rate, which is what makes a split worth avoiding. The push
## gate is wide open this far up the needle, so the rate is the dead anchor exactly.
func test_the_gap_pays_the_dead_rate() -> void:
	var level := _level()
	var rate := PushSim.flow_rate(_at(level, GAP), level)

	assert_true(absf(rate - level.fill_dead) < 0.0001,
			"the notch should pay fill_dead (%f), paid %f" % [level.fill_dead, rate])


## The point of the shape: dropping into the notch is a real loss, so a split zone
## asks the player to pick a band and hold it.
func test_falling_into_the_notch_costs_you() -> void:
	var level := _level()
	var in_band := PushSim.flow_rate(_at(level, 0.36), level)
	var in_gap := PushSim.flow_rate(_at(level, GAP), level)

	assert_gt(in_band, in_gap * 2.0,
			"the notch (%f/s) should be far worse than a band (%f/s)" % [in_gap, in_band])


# --------------------------------------------------------------------- the span

## The span is the outer edges of the whole set, not of the first band.
func test_the_span_covers_both_bands() -> void:
	var span := SimState.span_of([LOW, HIGH] as Array[Vector2])
	assert_eq(span.x, LOW.x, "the span's floor is the lowest band's floor")
	assert_eq(span.y, HIGH.y, "the span's ceiling is the highest band's ceiling")


## The sharp edge of a split: the reference "neutral push" is the middle of the
## SPAN, which here lands in the notch. That is correct for what band_centre is for
## — consistency and sway want a fixed reference that doesn't jump between bands —
## and is exactly why it must not be used to place the needle.
func test_the_band_centre_of_a_split_falls_in_the_notch() -> void:
	var level := _level()
	var centre := PushSim.band_centre(_at(level, 0.0))

	assert_true(centre > LOW.y and centre < HIGH.x,
			"the span's midpoint (%f) is expected to sit in the notch" % centre)
	assert_eq(PushSim.zone_of(_at(level, centre)), PushSim.ZONE_DEAD,
			"...which means the reference push is a DEAD one on a split level")


## ...so anything that PUTS the needle somewhere asks for the nearest band instead,
## and lands in flow from either side of the notch.
func test_the_nearest_band_centre_lands_in_flow_from_either_side() -> void:
	var level := _level()
	for needle in [0.0, 0.20, LOW.x, 0.40, 0.46]:
		var target := PushSim.nearest_band_centre(_at(level, needle))
		assert_eq(target, (LOW.x + LOW.y) * 0.5, "from %f the lower band is nearer" % needle)
	for needle in [0.58, HIGH.x, 0.70, 1.0]:
		var target := PushSim.nearest_band_centre(_at(level, needle))
		assert_eq(target, (HIGH.x + HIGH.y) * 0.5, "from %f the upper band is nearer" % needle)
	assert_eq(PushSim.zone_of(_at(level, PushSim.nearest_band_centre(_at(level, 0.0)))),
			PushSim.ZONE_FLOW, "the re-centre target must be inside a band")


## A jolt that throws you low must not recover you into the notch.
func test_a_jolt_recentre_does_not_land_in_the_notch() -> void:
	var level := _level()
	level.jolt_recenter = 1.0        # full drag, so the target is exactly where you land
	var state := _at(level, 0.02)    # thrown to the floor
	var slot := HazardSlot.new()
	slot.kind = SimEvent.Kind.JOLT
	slot.phase = HazardSlot.Phase.ACTIVE
	slot.active_len = 1.5
	slot.timer = 1.5
	state.hazards.append(slot)

	var intent := PlayerIntent.new()
	intent.swipe = Vector2(level.swipe_min + 10.0, 0.0)
	# Through the registry, not a direct class call: the operator this drives must be
	# the one the sim actually dispatches, or the test could pass against an operator
	# no longer wired to SimEvent.Kind.JOLT.
	Hazards.operator_for(SimEvent.Kind.JOLT).tick(
			state, slot, intent, level, SimClock.new(1337), SimClock.FIXED_DT)

	assert_eq(slot.phase, HazardSlot.Phase.RESOLVED, "the swipe should have answered the jolt")
	assert_eq(PushSim.zone_of(state), PushSim.ZONE_FLOW,
			"recovered to %f, which is not in a band" % state.needle)


## On every level that ships — one band — the two agree exactly, which is why this
## distinction could sit unnoticed and why making it changes no current behaviour.
func test_on_a_single_band_the_two_centres_agree() -> void:
	var level := Tuning.base()
	for needle in [0.0, 0.3, 0.61, 1.0]:
		var s := _at(level, needle)
		assert_eq(PushSim.nearest_band_centre(s), PushSim.band_centre(s),
				"they must not diverge on a single band (needle %f)" % needle)
