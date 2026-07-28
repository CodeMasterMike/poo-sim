class_name LevelRave
extends RefCounted
## The Rave — the Church's inverse, and proof the cover-window system is a polarity,
## not a one-off. Here the bass is pounding, so the room is COVERED by default: push
## as hard as you like, nobody hears a thing. The danger is the HUSH — the drop
## between songs, when the crowd goes quiet and every sound you're making is suddenly
## audible. Bear down through a hush and Discretion craters.
##
## Mechanically identical to the Church (same silence penalty, same acoustic-window
## hazard) with `baseline_exposed = false`, so a window EXPOSES you instead of
## shielding you. It plays completely differently, though: you push most of the time
## and react to brief hushes, where the Church has you waiting for brief cover. Same
## system, opposite feel — the pair the environment doc pitched.
##
## A full LevelDef factory (tuning + timeline). Content only; nothing reaches into
## scripts/sim/.

static func build() -> LevelDef:
	var level := LevelDef.new()

	# Covered by default — the whole room is a wall of bass.
	level.baseline_exposed = false
	level.silence_noise_rate = 14.0
	level.silence_push_cap = 0.50
	level.flow_bands = [Vector2(0.50, 0.72)]

	# You're pushing most of the sit, so it's a quicker, more forgiving level than
	# the Church. Easing off through a hush is correct, so the anti-turtle dead-zone
	# drain is softened (but less than the Church's — hushes are brief).
	level.composure_seconds = 85.0
	level.composure_drain_dead = 1.2

	level.timeline = _timeline()
	return level


static func _timeline() -> Array[SimEvent]:
	var t: Array[SimEvent] = []

	# OPEN — set the vibe and teach the rule: push freely, the bass covers you.
	t.append(SimEvent.prompt(0.5, "BASS IS PUMPING — push freely", 2.2))
	# The first hush is heavily telegraphed (the track winding down) and short.
	t.append(SimEvent.hush(6.0, 1.5, 2.5))

	# MIDDLE — the drops keep coming. Fixed cadence, no jitter: it's music, and it
	# stays deterministic. Long stretches of safe bass between brief hushes.
	var when := 13.5
	for _i in 6:
		t.append(SimEvent.hush(when, 1.2, 2.5))
		when += 7.5

	# THE LAST DROP — a final hush right as the player closes it out (the pinch).
	t.append(SimEvent.prompt(0.0, "THE LAST DROP — ease off and coast in", 2.0).on_relief(85.0))
	t.append(SimEvent.hush(0.0, 1.2, 3.0).on_relief(88.0))

	return t
