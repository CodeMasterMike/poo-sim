class_name BowlChunk
extends RefCounted
## One lump, broken off and still in the air.
##
## Solid matter does not pour. It parts company with you in pieces, tumbles, and
## lands somewhere NEAR where you were aiming rather than exactly on it — and the
## scatter between "near" and "exactly" is most of what makes a chunky pile look
## like it was dropped rather than extruded.
##
## Plain floats, no Node references, RefCounted: it lives in SimState and has to
## snapshot for a ghost or a mirrored board like every other field there. Every
## value below is rolled ONCE, at break-off, from the match-seeded SimClock.rng —
## never from the global randf() — so the same seed drops the same lumps in the
## same places (spec §17).
##
## Runny matter never produces one of these. Below `LevelDef.chunk_thickness_floor`
## the deposit path stays the continuous drizzle it has always been, which is what
## keeps a loose stool reading as a smooth rope and a flat pool.

## How much matter it carries, in column-heights (the same unit as SimState.bowl).
## While it is in the air this mass is in NEITHER the bowl nor anywhere else, which
## is why SimState.chunk_mass() exists — the conservation check has to count it.
var mass: float = 0.0

## The consistency it broke off at. Carried with the lump rather than read at
## landing, for the same reason SimState.bowl_thickness exists at all: what you are
## producing now must not re-grade something that left you two seconds ago.
var thickness: float = 0.5

## Where it left (the stream's aim) and where it will land, both as a fraction
## across the bowl. They differ by the scatter roll — that gap IS the "it lands
## crooked" behaviour, and the view draws the drift between them.
var from_u: float = 0.5
var u: float = 0.5

## Half its footprint, in bowl-fractions. Sub-linear in mass (a lump of twice the
## matter is only ~1.4x as wide), so big chunks stack rather than smearing flat.
var half: float = 0.02

## 0 at the exit, 1 at the surface. Advanced by PushSim, and the view reads it to
## place the lump mid-air.
var fall: float = 0.0
var fall_rate: float = 4.0

## One 0..1 roll kept for the view: which way it tumbles, how oval it is, which of
## its blobs sits proud. It changes nothing in the sim — but it is rolled HERE,
## from the seeded clock, because a replay has to redraw the identical lump and
## the view has nowhere to keep per-chunk state of its own (a chunk is gone from
## SimState the instant it lands).
var grain: float = 0.0
