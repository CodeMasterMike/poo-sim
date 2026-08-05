class_name Tuning
extends RefCounted
## Where a LevelDef base comes from — for the game AND for the tests.
##
## `LevelDef`'s @export defaults are the reference values, but they live in code,
## so tuning them means an edit-and-restart loop. `base_tuning.tres` is the same
## schema saved as a Resource: open it in the inspector, drag a number, replay.
##
## Everything routes through here for one reason. The moment a .tres exists, there
## are two candidate sources of tuning, and the guardrail this project has held
## since the vertical slice is that there is exactly ONE — a split source is what
## previously let the tests quietly validate different numbers than you were
## playing. So the tests call `Tuning.base()` too, and whatever you tune is what
## they check. If a tuning change breaks an invariant (runny stops levelling flat,
## the in-band gradient goes away), the suite is supposed to tell you.
##
## Missing or malformed file falls back to the code defaults rather than failing —
## a headless CI checkout with no imported resources still runs the suite.

const BASE_PATH := "res://data/levels/base_tuning.tres"


## A fresh LevelDef carrying the shared tuning. ALWAYS a new instance: LevelDef is
## a Resource, so handing out the loaded one would share it by reference and the
## timeline resolving its trigger points in place would corrupt every later run.
##
## The saved values are copied ONTO a fresh LevelDef rather than the loaded
## resource being duplicated. `duplicate()` does not carry the script's properties
## through intact — assigning a timeline to the copy fails outright — and copying
## field by field is better anyway: a newly added @export keeps its code default
## instead of silently reading as null until someone regenerates the .tres.
static func base() -> LevelDef:
	var level := LevelDef.new()
	if not ResourceLoader.exists(BASE_PATH):
		return level
	var res := ResourceLoader.load(BASE_PATH)
	if res == null:
		return level
	for prop in level.get_property_list():
		# @export vars carry STORAGE; a plain script var (LevelDef.timeline, which
		# is runtime-only) does not, so this copies exactly the tuning surface.
		if not (prop.usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = res.get(prop.name)
		if value != null:
			level.set(prop.name, value)
	return level
