class_name LevelRave
extends RefCounted
## The Rave — the Church's inverse, and proof the cover-window system is a polarity,
## not a one-off. Here the bass is pounding, so the room is COVERED by default: push
## as hard as you like, nobody hears a thing. The danger is the HUSH — the drop
## between songs, when the crowd goes quiet and every sound you're making is suddenly
## audible. Bear down through a hush and Discretion craters.
##
## Mechanically identical to the Church — same silence penalty, same acoustic-window
## hazard, same shared QuietRoom construction — with `baseline_exposed = false`, so
## a window EXPOSES you instead of shielding you. That one bit is the whole
## difference, and it plays completely differently: you push most of the time and
## react to brief hushes, where the Church has you waiting for brief cover.
##
## Content only: nothing here reaches into scripts/sim/.

## You're pushing most of the sit, so it's a quicker, more forgiving level.
const COMPOSURE_SECONDS: float = 85.0
## Easing off through a hush is correct, so the anti-turtle dead-zone drain is
## softened — but less than the Church's, because hushes are brief.
const DEAD_DRAIN: float = 1.2


## `base` is the shared tuning (see Tuning.base()); omit it and the LevelDef
## defaults are used. Build a fresh one per run — never share an instance, since
## the timeline resolves its trigger points in place.
static func build(base: LevelDef = null) -> LevelDef:
	var level: LevelDef = base if base != null else LevelDef.new()

	# Covered by default — the whole room is a wall of bass, and a window is the
	# hush that strips it away.
	QuietRoom.apply_tuning(level, false)

	level.composure_seconds = COMPOSURE_SECONDS
	level.composure_drain_dead = DEAD_DRAIN

	level.timeline = _timeline()
	return level


static func _timeline() -> Array[SimEvent]:
	var t: Array[SimEvent] = []

	# OPEN — set the vibe and teach the rule: push freely, the bass covers you.
	t.append(SimEvent.prompt(0.5, "BASS IS PUMPING — push freely", 2.2))
	# The first hush is heavily telegraphed (the track winding down) and short.
	t.append(QuietRoom.window(6.0, 1.5, 2.5))

	# MIDDLE — the drops keep coming. Long stretches of safe bass between brief hushes.
	t.append_array(QuietRoom.run(13.5, 6, 7.5, 1.2, 2.5))

	# THE LAST DROP — a final hush right as the player closes it out (the pinch).
	t.append(SimEvent.prompt(0.0, "THE LAST DROP — ease off and coast in", 2.0).on_relief(85.0))
	t.append(QuietRoom.window(0.0, 1.2, 3.0).on_relief(88.0))

	return t
