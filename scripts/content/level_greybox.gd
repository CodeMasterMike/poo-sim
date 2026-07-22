class_name LevelGreybox
extends RefCounted
## The grey-box "prove the systems" level. Its job is a timeline that exercises
## the machinery end to end: both trigger families and seeded randomness.
##
## Shape follows the spec's three-act micro-curve — a calm open, escalation
## through the middle, and a Final Push spike near the end — but the escalation
## beats are keyed to **Relief**, not the clock, so the curve tracks how the
## player is actually doing rather than a stopwatch.
##
## Content only: swap this for real levels without touching scripts/sim/.

static func timeline() -> Array[SimEvent]:
	var t: Array[SimEvent] = []

	# OPEN — a calm stretch to read the Flow Zone, then the first reaction test.
	# The knock lands somewhere in 4.5-7.5s: jitter is rolled once from the match
	# seed, so it varies run to run but is identical for a given seed.
	# Generous 0.35s grace on the first one — it's the teaching knock.
	t.append(SimEvent.knock(6.0, 1.5, 2.0, 40.0, 0.35).with_jitter(1.5))

	# MIDDLE — escalation paced by progress, not the clock.
	# At ~30% Relief the zone narrows and drifts up: a stubborn stretch that
	# demands a firmer push, flirting with the red zone's noise and splash risk.
	t.append(SimEvent.flow_zone(0.0, [Vector2(0.58, 0.72)], 1.5).on_relief(30.0))

	# NOTE: the Smell Cloud used to be faked here as a prompt plus a flat -22
	# Discretion hit on the clock. It's now a real emergent hazard emitted by
	# pushing in the red (see SmellCloudHazard), so it belongs to how you play
	# rather than to the timeline, and there's nothing to schedule.

	# A second, tighter knock (shorter telegraph, steeper cost) somewhere around
	# the halfway mark — proof that multiple knocks per sit work, and that a
	# hazard can be scheduled off progress.
	# Tighter: shorter telegraph, steeper cost, and only 0.15s of grace.
	t.append(SimEvent.knock(0.0, 1.0, 2.0, 45.0, 0.15).on_relief(55.0).with_jitter(8.0))

	# A breather: the zone widens and settles back down.
	t.append(SimEvent.flow_zone(0.0, [Vector2(0.48, 0.70)], 2.0).on_relief(68.0))

	# THE FINAL PUSH — at ~85% Relief the zone narrows hard for the last stretch,
	# the deliberate "so close" spike.
	t.append(SimEvent.prompt(0.0, "THE FINAL PUSH", 2.5).on_relief(85.0))
	t.append(SimEvent.flow_zone(0.0, [Vector2(0.62, 0.74)], 1.0).on_relief(85.0))

	return t
