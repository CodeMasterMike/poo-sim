class_name LevelCatalog
extends RefCounted
## The venue roster — the ONE place a level is registered.
##
## A level used to be spelled out in six places: an enum on the Sit, a `match` that
## built it, a second `match` that named it, the 1/2/3 key handlers, the HUD's
## footer hint, and a sentence in the field manual. Adding the fourth venue meant
## finding all six, and the two that are prose would have been found last — by a
## player reading a manual that lists three levels on a screen showing four.
##
## So the roster is data. Register an entry here and the venue appears in the
## picker, on a number key, in the manual's controls list and in the HUD hint, with
## no other edit anywhere. The catalog owns identity (id, display name) and how to
## build the thing; LevelDef still owns the tuning and the timeline.
##
## Levels stay GDScript factories rather than .tres files on purpose — a timeline is
## a piece of writing, and SimEvent is RefCounted so it can't be @exported anyway
## (see LevelDef.timeline). The catalog is the index over those factories, not a
## replacement for them.
##
## `id` is the stable name — it is what a save file, a score record or a ghost
## would key off, so NEVER rename one to fix a typo in the display name. Order is
## presentation only (the picker's order, and which number key selects it); it is
## safe to reorder, and nothing may persist an index.
##
## Content only: nothing here reaches into scripts/sim/.


## One registered venue: what to call it, and how to build it.
##
## `builder` takes the shared tuning base and returns a finished LevelDef, which is
## the signature every level factory already had — so registering one is naming it,
## not adapting it.
class Entry extends RefCounted:
	var id: StringName
	var display_name: String
	var builder: Callable

	func _init(entry_id: StringName, name_shown: String, build_fn: Callable) -> void:
		id = entry_id
		display_name = name_shown
		builder = build_fn


## Built once, on first use. A plain `const` can't hold a Callable, and rebuilding
## the array per call would hand out fresh Entry objects that compare unequal.
static var _entries: Array = []


## THE roster. Append to register a venue.
static func entries() -> Array:
	if _entries.is_empty():
		_entries = [
			Entry.new(&"greybox", "Prototype", Callable(LevelGreybox, "build")),
			Entry.new(&"church", "Church", Callable(LevelChurch, "build")),
			Entry.new(&"rave", "Rave", Callable(LevelRave, "build")),
		]
	return _entries


static func size() -> int:
	return entries().size()


## The entry at a presentation index, or null if it is out of range.
static func at(index: int) -> Entry:
	var all := entries()
	if index < 0 or index >= all.size():
		return null
	return all[index]


static func find(id: StringName) -> Entry:
	for entry in entries():
		if entry.id == id:
			return entry
	return null


## The presentation index of an id, or -1. The host holds an id, the picker holds
## an index, and this is the only place the two are converted.
static func index_of(id: StringName) -> int:
	var all := entries()
	for i in all.size():
		if all[i].id == id:
			return i
	return -1


## Display names in roster order — what the picker renders.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in entries():
		out.append(entry.display_name)
	return out


## The roster as one readable phrase, for prose that lists the venues (the field
## manual's controls table). Generated so the copy can't fall behind the roster.
static func names_joined(separator: String = " · ") -> String:
	return separator.join(names())


## Build a venue by id, on top of the shared tuning `base`. An unknown id falls back
## to the first entry rather than returning null — a bad id in a save file or an
## @export should drop you into a playable level, not a crash on a null LevelDef.
static func build(id: StringName, base: LevelDef) -> LevelDef:
	var entry := find(id)
	if entry == null:
		entry = at(0)
	return entry.builder.call(base)


## The id a given number key selects. Key 1 is the first entry. Returns an empty
## StringName past the end of the roster, so a venue without a key is simply
## unreachable that way rather than an error.
static func id_for_slot(slot: int) -> StringName:
	var entry := at(slot - 1)
	return entry.id if entry != null else &""


## How many number keys the roster actually uses — 1..9, since there is no key 10.
## The HUD's hint reads this so it can't promise keys that select nothing.
static func key_slots() -> int:
	return mini(size(), 9)
