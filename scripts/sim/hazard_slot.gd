class_name HazardSlot
extends RefCounted
## One in-flight hazard. Every hazard in the catalog shares this shape — a
## telegraphed warning, an active reaction window, then resolution — so adding
## hazards #3..#14 costs a payload plus an operator, NOT another five fields on
## SimState (which is where the first draft was heading).
##
## Pure data: references no other sim class, so SimState can hold these without
## forming a class cycle. Behaviour lives in the per-hazard operators under
## scripts/sim/hazards/, dispatched by Hazards.

enum Phase { TELEGRAPH, ACTIVE, RESOLVED }

var kind: int = 0                ## SimEvent.Kind of the hazard that owns this slot
var phase: int = Phase.TELEGRAPH
var timer: float = 0.0           ## seconds left in the current phase
var active_len: float = 0.0      ## length of the ACTIVE (reaction) window
## The magnitude of the bad thing, in whatever unit the hazard deals in: meter
## damage on failure for most, needle impulse for the Jolt.
var cost: float = 0.0
## Per-second bleed applied for as long as the hazard is unresolved (The Buzz's
## distraction). Zero for hazards that only bite at the end.
var drain: float = 0.0
var failed: bool = false         ## did the player blow the reaction?
var stalls_relief: bool = false  ## while ACTIVE, does this hazard freeze The Push?
## Forgiveness at the START of the ACTIVE window, in seconds. Human reaction time
## is ~200ms; without this, being mid-push on the very first frame of a freeze is
## an instant fail with no window at all. Tighten it in later worlds (the
## difficulty curve wants generous windows early, tight ones late).
var grace: float = 0.0
