class_name LevelChurch
extends RefCounted
## The Church — the first cover-window level, and the debut of the "quiet room"
## rule: the room is silent, so you can only push under cover of ambient noise (an
## organ swell, a hymn). Between those windows, any real push is heard and
## Discretion bleeds (see PushSim's silence penalty + CoverWindowHazard). The Push
## becomes a timing game — bank Relief in the swells, ease off in the hush.
##
## The quiet-room machinery is shared with the Rave (see QuietRoom) — they are one
## rule at opposite polarity. What lives HERE is only what makes it the Church: the
## pacing, and the timeline that assumes it.
##
## Content only: nothing here reaches into scripts/sim/.

## A longer, tenser sit: you spend real time waiting for cover, so this stays the
## most generous clock of the three — a careful Church run is ~64s against the
## grey-box's ~39s, and waiting for cover is the CORRECT play, not dawdling.
##
## 85 lands that careful line at ~25% remaining. The Church's real threat was
## never the clock (a hard push finishes in ~19s and walks away with ~71% in
## hand); it's Discretion. The clock is only here to stop you waiting forever.
const COMPOSURE_SECONDS: float = 85.0
## Easing off in the hush is the CORRECT play here, so the anti-turtle dead-zone
## drain is neutered entirely — otherwise the level would punish you for playing
## it right.
const DEAD_DRAIN: float = 1.0


## `base` is the shared tuning (see Tuning.base()); omit it and the LevelDef
## defaults are used. Build a fresh one per run — never share an instance, since
## the timeline resolves its trigger points in place.
static func build(base: LevelDef = null) -> LevelDef:
	var level: LevelDef = base if base != null else LevelDef.new()

	# Exposed by default: silence is the baseline and a swell shields you.
	QuietRoom.apply_tuning(level, true)

	level.composure_seconds = COMPOSURE_SECONDS
	level.composure_drain_dead = DEAD_DRAIN

	level.timeline = _timeline()
	return level


static func _timeline() -> Array[SimEvent]:
	var t: Array[SimEvent] = []

	# OPEN — teach the rule: silence is the default; wait for the swell to push.
	t.append(SimEvent.prompt(0.5, "SILENCE — wait for cover", 2.2))
	# The first swell is heavily telegraphed (the organ warming up) and generous —
	# a window you basically can't miss, per the curriculum's "introduce safe".
	t.append(QuietRoom.window(3.0, 1.8, 5.0))

	# MIDDLE — a steady rhythm of hymn swells with quiet hushes between.
	t.append_array(QuietRoom.run(11.0, 8, 7.0, 1.2, 4.0))

	# THE FINAL VERSE — a last, long swell to finish on, keyed to progress so the
	# closing window lands as the player nears the goal (the "so close" pinch).
	t.append(SimEvent.prompt(0.0, "THE FINAL VERSE — ride the swell", 2.0).on_progress(85.0))
	t.append(QuietRoom.window(0.0, 1.2, 6.0).on_progress(87.0))

	return t
