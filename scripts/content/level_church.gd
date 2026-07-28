class_name LevelChurch
extends RefCounted
## The Church — the first cover-window level, and the debut of the "quiet room"
## rule: the room is silent, so you can only push under cover of ambient noise (an
## organ swell, a hymn). Between those windows, any real push is heard and
## Discretion bleeds (see PushSim's silence penalty + CoverWindowHazard). The Push
## becomes a timing game — bank Relief in the swells, ease off in the hush.
##
## Unlike the timeline-only greybox, this is a FULL LevelDef factory: the silence
## penalty and its cap are level tuning, so they belong here with the timeline that
## assumes them. Build a fresh one per run (it's cheap) — never share one, since
## the timeline resolves its trigger points in place.
##
## Content only: nothing here reaches into scripts/sim/. To retune, edit the
## numbers below and replay.

static func build() -> LevelDef:
	var level := LevelDef.new()

	# The quiet room. The cap sits at the Flow floor, so in silence you can idle low
	# for free but any flow-level push is audible — that's the whole rule.
	level.silence_noise_rate = 14.0
	level.silence_push_cap = 0.50
	level.flow_bands = [Vector2(0.50, 0.72)]

	# A longer, tenser sit: you spend real time waiting for cover. Easing off in the
	# hush is the CORRECT play here, so the anti-turtle dead-zone drain is neutered
	# to 1.0 — otherwise the level would punish you for playing it right.
	level.composure_seconds = 105.0
	level.composure_drain_dead = 1.0

	level.timeline = _timeline()
	return level


static func _timeline() -> Array[SimEvent]:
	var t: Array[SimEvent] = []

	# OPEN — teach the rule: silence is the default; wait for the swell to push.
	t.append(SimEvent.prompt(0.5, "SILENCE — wait for cover", 2.2))
	# The first swell is heavily telegraphed (the organ warming up) and generous —
	# a window you basically can't miss, per the curriculum's "introduce safe".
	t.append(SimEvent.cover(3.0, 1.8, 5.0))

	# MIDDLE — a steady rhythm of hymn swells with quiet hushes between. Fixed
	# cadence, no jitter: the groove is the point, and it stays deterministic.
	var when := 11.0
	for _i in 8:
		t.append(SimEvent.cover(when, 1.2, 4.0))
		when += 7.0

	# THE FINAL VERSE — a last, long swell to finish on, keyed to progress so the
	# closing window lands as the player nears the goal (the "so close" pinch).
	t.append(SimEvent.prompt(0.0, "THE FINAL VERSE — ride the swell", 2.0).on_relief(85.0))
	t.append(SimEvent.cover(0.0, 1.2, 6.0).on_relief(87.0))

	return t
