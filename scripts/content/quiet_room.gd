class_name QuietRoom
extends RefCounted
## Shared construction for the acoustic-window pair — the Church and the Rave.
##
## These are ONE rule at two polarities, not two levels. The window machinery is
## literally identical: `SimEvent.cover()` and `SimEvent.hush()` are the same
## constructor under two names, and `Hazards.room_exposed` resolves the meaning as
## `baseline_exposed XOR window_active`. The Church is exposed by default so a
## window shields you; the Rave is covered by default so a window exposes you.
## That single bit is the entire difference.
##
## Both levels were nonetheless written out longhand, which meant the shared
## numbers lived in two files and could drift apart independently — most sharply
## the quiet-room cap, which is the Flow band's floor for a stated reason and was
## repeated as a literal `0.50` in both.
##
## Deliberately composable helpers rather than one timeline template: each venue's
## timeline is a piece of writing (an organ's rhythm, a DJ's set) and should still
## read as one. The catalog's next quiet-room levels combine a window with a Knock,
## which a rigid template would fight.
##
## Content only: nothing here reaches into scripts/sim/.

## Discretion lost per second while audible. Shared on purpose — the pair is meant
## to be the same rule at opposite polarity, so the penalty must not differ between
## them, or the comparison stops being about the polarity.
const NOISE_RATE: float = 14.0


## The bottom of the Flow band — the level's own definition of "a real push".
static func flow_floor(level: LevelDef) -> float:
	if level.flow_bands.is_empty():
		return 0.5
	var lowest: float = level.flow_bands[0].x
	for band in level.flow_bands:
		lowest = minf(lowest, band.x)
	return lowest


## Turn a LevelDef into a quiet room of the given polarity.
##
## `exposed_by_default`: true = the Church (silent room, windows shield you),
## false = the Rave (bass-covered room, windows expose you).
##
## The cap is DERIVED from the Flow floor rather than repeated as a literal. The
## rule is "in silence you may idle low, but any flow-level push is audible", so if
## the band moves — including from the shared .tres — the cap has to move with it
## or the level quietly stops meaning what its comment says.
static func apply_tuning(level: LevelDef, exposed_by_default: bool) -> void:
	level.baseline_exposed = exposed_by_default
	level.silence_noise_rate = NOISE_RATE
	level.silence_push_cap = flow_floor(level)


## One acoustic window. Polarity-free by design: a window is a window, and the
## level's `baseline_exposed` decides whether it is cover or a hush.
static func window(at: float, telegraph: float, length: float) -> SimEvent:
	return SimEvent.cover(at, telegraph, length)


## A run of windows on a fixed cadence.
##
## No jitter, in either venue: the groove is the point — an organ has a rhythm and
## a set has a tracklist — and a fixed cadence keeps the middle deterministic
## without spending the match seed on it.
static func run(first_at: float, count: int, cadence: float,
		telegraph: float, length: float) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	var when := first_at
	for _i in count:
		out.append(window(when, telegraph, length))
		when += cadence
	return out
