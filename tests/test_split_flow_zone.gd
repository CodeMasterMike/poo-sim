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


## Documents the one sharp edge of a split, so it can't surprise anyone later: the
## reference "neutral push" is the middle of the SPAN, which for a split lands in
## the notch. That is fine where it is used today (consistency and sway both want a
## fixed reference point) and wrong as a re-centre target — see PushSim.band_centre.
func test_the_band_centre_of_a_split_falls_in_the_notch() -> void:
	var level := _level()
	var centre := PushSim.band_centre(_at(level, 0.0))

	assert_true(centre > LOW.y and centre < HIGH.x,
			"the span's midpoint (%f) is expected to sit in the notch" % centre)
	assert_eq(PushSim.zone_of(_at(level, centre)), PushSim.ZONE_DEAD,
			"...which means the reference push is a DEAD one on a split level")
