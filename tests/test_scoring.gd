@tool
extends McpTestSuite
## Scoring — the star gates and the 1000-point breakdown (spec: clear 100 +
## Discretion 300 + Cleanliness 300 + Flow 150 + Speed 150).
##
## Pure and deterministic: it reads end-of-run state and returns numbers, with no
## engine, no scene and no display strings. That made it the easiest thing in
## scripts/sim/ to test and, until now, the only file there with no suite at all —
## so nothing would have noticed a star gate moving.
##
## Every test spoils exactly one axis of a flawless run, so what each is measuring
## is the difference that one thing makes.


func suite_name() -> String:
	return "scoring"


## An end-of-run state with every axis maxed: cleared, all three meters full, every
## drop of Relief earned inside the Flow band, never detected.
func _perfect(won: bool = true) -> SimState:
	var s := SimState.new()
	s.phase = SimState.Phase.WON if won else SimState.Phase.LOST
	s.discretion = 100.0
	s.cleanliness = 100.0
	s.composure = 100.0
	s.total_fill = 80.0
	s.flow_fill = 80.0        # a Flow Ratio of exactly 1.0
	s.detection_count = 0
	return s


## The level argument is unused by Scoring; passed so the call reads like the real one.
func _score(state: SimState) -> Dictionary:
	return Scoring.evaluate(state, LevelDef.new())


# --------------------------------------------------------------- the full board

func test_a_flawless_clear_scores_the_full_thousand() -> void:
	var r := _score(_perfect())
	var bd: Dictionary = r["breakdown"]

	assert_eq(int(bd["clear"]), 100, "a clear is worth 100")
	assert_eq(int(bd["discretion"]), 300, "full Discretion is worth 300")
	assert_eq(int(bd["cleanliness"]), 300, "full Cleanliness is worth 300")
	assert_eq(int(bd["flow"]), 150, "a Flow Ratio of 1.0 is worth 150")
	assert_eq(int(bd["speed"]), 150, "full Composure left is worth 150")
	assert_eq(int(r["base"]), 1000, "the axes should add up to the spec's 1000")
	assert_eq(int(r["stars"]), 3, "a flawless run is three stars")


## The headline number is only ever the sum of the five axes — no bonus hiding in
## the total, no axis quietly left out of it.
func test_the_breakdown_always_sums_to_the_base() -> void:
	var spoiled := _perfect()
	spoiled.discretion = 37.0
	spoiled.cleanliness = 61.5
	spoiled.composure = 12.0
	spoiled.flow_fill = 30.0    # ratio 0.375

	for state in [_perfect(), _perfect(false), spoiled]:
		var r := _score(state)
		var bd: Dictionary = r["breakdown"]
		var summed: int = int(bd["clear"]) + int(bd["discretion"]) + int(bd["cleanliness"]) \
				+ int(bd["flow"]) + int(bd["speed"])
		assert_eq(int(r["base"]), summed, "base %d != the axes' sum %d" % [int(r["base"]), summed])


# -------------------------------------------------------------------- the gates

## Losing costs the clear bonus AND the whole Speed axis — Composure left over only
## counts if you actually got up. And no score, however high, earns a star.
func test_a_loss_scores_no_clear_no_speed_and_no_stars() -> void:
	var r := _score(_perfect(false))
	var bd: Dictionary = r["breakdown"]

	assert_false(bool(r["cleared"]), "the run was not cleared")
	assert_eq(int(bd["clear"]), 0, "no clear bonus on a loss")
	assert_eq(int(bd["speed"]), 0, "Speed is only paid on a clear")
	assert_eq(int(r["base"]), 750, "the three earned axes should still pay (300+300+150)")
	assert_eq(int(r["stars"]), 0, "stars require a clear, whatever the score")


## Being detected even once is a hard ceiling of two stars, at any score.
func test_being_detected_caps_the_run_at_two_stars() -> void:
	var s := _perfect()
	s.detection_count = 1
	var r := _score(s)

	assert_eq(int(r["base"]), 1000, "detection costs no points directly")
	assert_false(bool(r["never_detected"]), "one dip past the threshold counts")
	assert_eq(int(r["stars"]), 2, "a perfect score still can't buy the third star")


## The "no major mess" gate on ★★★, which is very nearly redundant: Cleanliness
## pays 3 points per percent, so clearing the 850 threshold at all already implies
## roughly 49.83% Cleanliness. The gate only actually bites in the sliver between
## that and the stated 50% — which is exactly where this test sits, because a gate
## that is never the deciding condition is a gate nobody would notice breaking.
func test_a_mess_caps_the_run_at_two_stars() -> void:
	var s := _perfect()
	s.cleanliness = 49.9      # pays round(149.7) = 150, so the score still reaches 850
	var r := _score(s)

	assert_eq(int(r["base"]), 850, "the state should sit exactly on the score threshold")
	assert_false(bool(s.cleanliness >= Scoring.NO_MAJOR_MESS_MIN), "...but under the mess line")
	assert_eq(int(r["stars"]), 2, "a mess should hold the third star back")


## The second star is inclusive at 600. Clear + Discretion + Flow come to 550 here,
## so Speed alone decides it — and Speed is round(Composure × 1.5), which puts 33%
## Composure exactly on the gate and 32% just under.
func test_the_two_star_gate_is_inclusive_at_600() -> void:
	var on_gate := _perfect()
	on_gate.cleanliness = 0.0
	on_gate.composure = 33.0
	var r := _score(on_gate)
	assert_eq(int(r["base"]), 600, "expected this state to land exactly on the gate")
	assert_eq(int(r["stars"]), 2, "600 should be worth the second star")

	var below := _perfect()
	below.cleanliness = 0.0
	below.composure = 32.0
	var r2 := _score(below)
	assert_eq(int(r2["base"]), 598, "expected this state to land just under the gate")
	assert_eq(int(r2["stars"]), 1, "under the gate, a clear is worth one star")


# --------------------------------------------------------------------- the edges

## A run that produced nothing must not divide by zero on the way to a Flow score.
func test_flow_scores_zero_when_nothing_was_produced() -> void:
	var s := _perfect()
	s.total_fill = 0.0
	s.flow_fill = 0.0

	assert_eq(s.flow_ratio(), 0.0, "an empty run has no Flow Ratio")
	assert_eq(int(_score(s)["breakdown"]["flow"]), 0, "and earns nothing for it")


## Meters are clamped into their award, so a value that strayed outside 0..100
## can neither overpay nor go negative.
func test_meters_outside_the_range_are_clamped_into_the_award() -> void:
	var over := _perfect()
	over.discretion = 140.0
	assert_eq(int(_score(over)["breakdown"]["discretion"]), 300, "over 100 must not overpay")

	var under := _perfect()
	under.cleanliness = -20.0
	assert_eq(int(_score(under)["breakdown"]["cleanliness"]), 0, "below 0 must not go negative")
