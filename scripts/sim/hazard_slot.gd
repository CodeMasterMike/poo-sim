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
var cost: float = 0.0            ## meter damage applied on failure
var failed: bool = false         ## did the player blow the reaction?
var stalls_relief: bool = false  ## while ACTIVE, does this hazard freeze The Push?
