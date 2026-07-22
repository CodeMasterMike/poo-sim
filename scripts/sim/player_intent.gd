class_name PlayerIntent
extends RefCounted
## The single input layer (spec §17 guardrail 4). The view produces exactly one
## of these per fixed step by draining its input buffer; the sim reads only this,
## never live input. A recorded ghost or a remote player can produce identical
## PlayerIntents, which is the whole point — the sim can't tell where they came
## from.
##
## `holding` is level state (is the push held this step). The reaction fields are
## edges (a tap/swipe that happened during this step) — reserved for hazards, and
## the reason intent must be sampled per step rather than read live: an edge has
## to belong to exactly one step or it won't reproduce on replay.

var holding: bool = false
var tap: bool = false
var swipe: Vector2 = Vector2.ZERO
