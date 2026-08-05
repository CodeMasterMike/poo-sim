@tool
extends McpTestSuite
## Guards the tuning plumbing itself.
##
## `Tuning.base()` falls back to LevelDef's code defaults when the resource is
## missing or unreadable, which is the right behaviour (a fresh checkout still
## runs) and also a silent failure mode: base_tuning.tres currently holds the same
## values as those defaults, so a resource that never loads would look identical
## and nothing else in the suite would notice. These tests are what notice.


func suite_name() -> String:
	return "tuning"


## The file is there, parses, and actually carries LevelDef's script. Without the
## script attached every field reads back null and the copy loop quietly serves
## code defaults forever.
func test_the_shared_tuning_resource_loads() -> void:
	assert_true(ResourceLoader.exists(Tuning.BASE_PATH),
			"data/levels/base_tuning.tres is missing")
	var res := ResourceLoader.load(Tuning.BASE_PATH)
	assert_ne(res, null, "base_tuning.tres failed to load")
	assert_ne(res.get("fill_flow"), null,
			"the resource isn't carrying LevelDef's script — every field reads null")


## What base() hands out is what the FILE says, not what the code says. This is the
## assertion that fails if the load path breaks.
func test_base_reflects_the_resource() -> void:
	var res := ResourceLoader.load(Tuning.BASE_PATH)
	var base := Tuning.base()
	for key in ["fill_flow", "fill_red", "thickness_base", "density_swing",
			"repose_solid", "sway_push", "composure_seconds"]:
		assert_eq(base.get(key), res.get(key), "%s did not come from the resource" % key)


## Every call is a fresh instance. LevelDef is a Resource, so a shared one would be
## handed out by reference — and `resolve_timeline()` fixes trigger points IN PLACE,
## so one run's jitter would leak into the next and determinism would rot.
func test_base_hands_out_a_fresh_instance() -> void:
	var a := Tuning.base()
	var b := Tuning.base()
	assert_ne(a.get_instance_id(), b.get_instance_id(), "base() returned a shared instance")

	a.fill_flow = 99.0
	assert_ne(b.fill_flow, 99.0, "mutating one base leaked into another")
	assert_ne(Tuning.base().fill_flow, 99.0, "mutating a base leaked into the resource")


## An @export added to LevelDef but not yet written into the .tres must keep its
## code default rather than reading back as null. That's what lets the resource be
## a partial file instead of something that has to be regenerated on every change.
func test_a_field_absent_from_the_resource_keeps_its_default() -> void:
	var res := ResourceLoader.load(Tuning.BASE_PATH)
	var base := Tuning.base()
	# `timeline` is a plain script var, never serialised — it must survive as an
	# empty typed array, not arrive as null.
	assert_eq(base.timeline.size(), 0, "timeline should start empty")
	assert_eq(res.get("timeline"), null, "timeline should not be stored in the .tres")
	# And the copy must not have blanked a real tuning field on the way through.
	assert_true(base.fill_flow > 0.0, "fill_flow came through as zero/absent")
