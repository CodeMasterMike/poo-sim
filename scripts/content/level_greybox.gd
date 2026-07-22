class_name LevelGreybox
extends RefCounted
## The grey-box "prove the systems" level. Its only job is a timeline that visibly
## exercises the machinery: the Flow Zone narrows and drifts, and a scripted beat
## drops Discretion with a prompt — so you can watch the event stream modify the
## session. This is content, not schema: swap it for real levels later without
## touching scripts/sim/.
##
## Scalar tuning (physics, fill, meter rates) lives on the view's live-tune
## exports for now; this factory owns the authored event sequence.

static func timeline() -> Array[SimEvent]:
	var t: Array[SimEvent] = []

	# ~8s: the Flow Zone narrows and drifts upward — a "stubborn stretch" that
	# forces a firmer push (and flirts with the red zone's noise/splash risk).
	t.append(SimEvent.flow_zone(8.0, [Vector2(0.58, 0.72)], 1.5))

	# ~11s: a scripted pressure beat — a smell cloud craters Discretion, with a
	# prompt so the player reads why. (Later this becomes a real Smell hazard.)
	t.append(SimEvent.prompt(11.0, "SMELL CLOUD", 2.0))
	t.append(SimEvent.meter(11.0, SimState.Meter.DISCRETION, -22.0))

	# ~17s: the zone shifts back down and widens — relief, and a chance to recover.
	t.append(SimEvent.flow_zone(17.0, [Vector2(0.46, 0.70)], 2.0))

	return t
