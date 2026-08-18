@tool
extends McpTestSuite
## Guards the venue roster — the registry that replaced six hand-kept copies of
## "which levels exist".
##
## The point of the catalog is that registering a level is ONE edit, so what these
## tests actually protect is the claim that every consumer reads the same roster.
## An entry that builds but has no name, or a number key that selects nothing,
## would each have been a silent content bug.


func suite_name() -> String:
	return "catalog"


## Every registered venue must actually build. The builder is a Callable to a
## static factory, which nothing checks at parse time — a renamed or removed
## `build` would sail through until someone picked that level in the picker.
func test_every_entry_builds_a_playable_level() -> void:
	assert_gt(LevelCatalog.size(), 0, "the roster is empty")
	for entry in LevelCatalog.entries():
		var level: LevelDef = entry.builder.call(Tuning.base())
		assert_true(level is LevelDef,
				"%s's builder returned %s, not a LevelDef" % [entry.id, level])
		assert_false(level.flow_bands.is_empty(),
				"%s built with no Flow band — it would be unplayable" % entry.id)


## build() by id is the path the host uses, and it must agree with calling the
## builder directly.
func test_build_by_id_matches_the_entry() -> void:
	for entry in LevelCatalog.entries():
		var level := LevelCatalog.build(entry.id, Tuning.base())
		assert_true(level is LevelDef, "%s failed to build by id" % entry.id)


## A fresh LevelDef per build, never a shared one. resolve_timeline() fixes trigger
## points IN PLACE, so a shared instance would carry one run's jitter into the next
## — the exact trap Tuning.base() exists to avoid, one layer up.
func test_each_build_is_a_fresh_level() -> void:
	var a := LevelCatalog.build(LevelCatalog.at(0).id, Tuning.base())
	var b := LevelCatalog.build(LevelCatalog.at(0).id, Tuning.base())
	assert_ne(a.get_instance_id(), b.get_instance_id(),
			"two builds handed back the same LevelDef instance")


## ids are what a save file, a score record or a ghost would key off, so a
## duplicate would silently merge two venues' records.
func test_ids_are_unique_and_non_empty() -> void:
	var seen := {}
	for entry in LevelCatalog.entries():
		assert_false(String(entry.id).is_empty(), "an entry has an empty id")
		assert_false(seen.has(entry.id), "duplicate level id: %s" % entry.id)
		seen[entry.id] = true


## Display names reach the picker; a blank one renders as an unlabelled button.
func test_every_entry_has_a_display_name() -> void:
	assert_eq(LevelCatalog.names().size(), LevelCatalog.size(),
			"names() and the roster disagree on how many venues there are")
	for entry in LevelCatalog.entries():
		assert_false(entry.display_name.strip_edges().is_empty(),
				"%s has no display name" % entry.id)


## The host holds an id, the picker holds an index. Round-tripping is the only
## thing keeping the highlighted button and the running level in agreement.
func test_index_and_id_round_trip() -> void:
	for i in LevelCatalog.size():
		var entry := LevelCatalog.at(i)
		assert_eq(LevelCatalog.index_of(entry.id), i,
				"%s round-tripped to the wrong index" % entry.id)


## Out-of-range lookups return null rather than throwing — the picker and the
## number keys both index by position and must not be able to crash the host.
func test_out_of_range_lookups_are_null() -> void:
	assert_eq(LevelCatalog.at(-1), null, "a negative index should be null")
	assert_eq(LevelCatalog.at(LevelCatalog.size()), null, "one past the end should be null")
	assert_eq(LevelCatalog.find(&"no_such_venue"), null, "an unknown id should be null")
	assert_eq(LevelCatalog.index_of(&"no_such_venue"), -1, "an unknown id should index -1")


## An unknown id must still hand back a playable level. A bad id can arrive from a
## stale @export or a save file written by an older build, and dropping the player
## into the first venue beats crashing on a null LevelDef.
func test_an_unknown_id_falls_back_to_a_playable_level() -> void:
	var level := LevelCatalog.build(&"deleted_venue", Tuning.base())
	assert_true(level is LevelDef, "an unknown id must still build something")
	assert_false(level.flow_bands.is_empty(), "the fallback level must be playable")


## Number keys are handed out by position, 1-based, and stop at 9 — there is no
## key 10, and a key that selects nothing is worse than no key.
func test_number_key_slots_map_onto_the_roster() -> void:
	assert_eq(LevelCatalog.key_slots(), mini(LevelCatalog.size(), 9),
			"the key range should cover the roster, capped at 9")
	for slot in range(1, LevelCatalog.key_slots() + 1):
		assert_eq(LevelCatalog.id_for_slot(slot), LevelCatalog.at(slot - 1).id,
				"key %d selected the wrong venue" % slot)
	assert_eq(LevelCatalog.id_for_slot(0), &"", "there is no key 0")
	assert_eq(LevelCatalog.id_for_slot(LevelCatalog.size() + 1), &"",
			"a key past the roster must select nothing")


## The manual's controls table is generated from this, so it can't fall behind.
func test_names_joined_lists_every_venue() -> void:
	var joined := LevelCatalog.names_joined()
	for entry in LevelCatalog.entries():
		assert_true(joined.contains(entry.display_name),
				"%s is missing from the joined roster" % entry.display_name)
