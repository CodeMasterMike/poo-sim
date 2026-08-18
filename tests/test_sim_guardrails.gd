@tool
extends McpTestSuite
## The spec §17 guardrails, enforced instead of merely asserted in comments.
##
## Everything in scripts/sim/ is promised to be engine-pure and deterministic: no
## Node references, no live input, no global RNG, no wall clock. That promise is
## what makes ghost replay and a mirrored 1v1 board possible later, and until now
## it was held up by nothing but discipline and the docstrings saying so. None of
## these properties fail loudly — a stray `randf()` in the sim costs you nothing
## today and quietly makes replays undeterministic forever.
##
## So these read the source. That is unusual for a test suite and deliberate: the
## guardrails are statements ABOUT the code, not about its behaviour, and there is
## no runtime moment at which "nobody imported a Node" is observable.
##
## Comments are stripped before matching, or the suite would trip over its own
## subject matter — SimClock's docstring says "never use the global randf()", and
## PushSim's says it "holds NO Node references". Stripping is a plain cut at the
## first `#`, which is safe here only because nothing under scripts/sim/ puts a `#`
## inside a string literal (the colour tokens live in scripts/ui/palette.gd).


func suite_name() -> String:
	return "guardrails"


const SIM_DIR := "res://scripts/sim"
const VIEW := "res://scripts/systems/push_prototype.gd"


func _gd_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			out.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out


## A file's source with every comment removed, so a docstring naming a banned
## symbol doesn't read as a use of it.
func _code_lines(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	for line in f.get_as_text().split("\n"):
		var hash_at := line.find("#")
		out.append(line if hash_at < 0 else line.substr(0, hash_at))
	return out


## Every (file, line) under scripts/sim/ whose code matches `pattern`.
func _offenders(pattern: String) -> PackedStringArray:
	var re := RegEx.new()
	var err := re.compile(pattern)
	assert_eq(err, OK, "the guard's own regex failed to compile: %s" % pattern)
	var hits := PackedStringArray()
	for path in _gd_files(SIM_DIR):
		var lines := _code_lines(path)
		for i in lines.size():
			if re.search(lines[i]) != null:
				hits.append("%s:%d  %s" % [path.get_file(), i + 1, lines[i].strip_edges()])
	return hits


func _assert_absent(pattern: String, why: String) -> void:
	var hits := _offenders(pattern)
	assert_eq(hits.size(), 0, "%s\n    %s" % [why, "\n    ".join(hits)])


# ------------------------------------------------------------------ engine purity

## The sim holds no Node references, so a SimState is a thing you can snapshot,
## serialize and hand to a replay. The moment anything in here reaches for the tree
## it stops being portable.
func test_the_sim_touches_no_scene_tree() -> void:
	_assert_absent(r"\b(get_node|add_child|queue_redraw|get_tree|get_viewport|get_window)\s*\(",
			"scripts/sim/ reached into the scene tree (spec 17, guardrail 3):")
	_assert_absent(r"\$\w", "scripts/sim/ used a $NodePath shorthand:")


## Every sim class is a RefCounted or a Resource — never a Node. This is the same
## guarantee as above stated positively, and it is the one that would catch someone
## "just" making a hazard a Node so it could have a timer.
##
## HazardOp is admitted as a base because the hazard operators extend it, and the
## test below pins HazardOp itself to RefCounted — so the chain still terminates
## somewhere pure. Add a name here ONLY alongside that kind of proof; an unchecked
## entry turns this guard into a list of exceptions.
func test_every_sim_class_is_refcounted_or_resource() -> void:
	var allowed := ["RefCounted", "Resource", "HazardOp"]
	var bad := PackedStringArray()
	for path in _gd_files(SIM_DIR):
		var base := ""
		for line in _code_lines(path):
			if line.begins_with("extends "):
				base = line.substr(8).strip_edges()
				break
		if not allowed.has(base):
			bad.append("%s extends %s" % [path.get_file(), base if base != "" else "<nothing>"])
	assert_eq(bad.size(), 0, "sim classes must be RefCounted or Resource:\n    %s" % "\n    ".join(bad))


## The base the hazard operators extend, pinned to RefCounted — the proof the
## allowlist above leans on. Without this, admitting "HazardOp" as a base would let
## someone make HazardOp a Node and take all five hazards out of the sim with it,
## and the guard above would still pass.
func test_the_hazard_base_is_itself_refcounted() -> void:
	var base := ""
	for line in _code_lines("res://scripts/sim/hazards/hazard_op.gd"):
		if line.begins_with("extends "):
			base = line.substr(8).strip_edges()
			break
	assert_eq(base, "RefCounted",
			"HazardOp extends %s — the allowlist's exemption is no longer safe" % base)


# ------------------------------------------------------------------- determinism

## All gameplay randomness comes from the match-seeded SimClock.rng. A bare
## `randf()` is the classic way to lose reproducibility: it costs nothing today and
## silently makes every replay and mirrored board diverge.
##
## Calls THROUGH the seeded generator (`clock.rng.randf()`) are the correct form, so
## the guard only rejects the global ones — the pattern requires no `.` before the
## name.
func test_the_sim_never_pulls_from_the_global_rng() -> void:
	_assert_absent(r"(^|[^.\w])(randf|randi|randf_range|randi_range|randomize)\s*\(",
			"scripts/sim/ used the GLOBAL rng instead of the match-seeded clock.rng:")


## ...and never reads a wall clock. Sim time is SimClock.step and nothing else, or
## two machines stepping the same intents drift apart.
func test_the_sim_never_reads_a_wall_clock() -> void:
	_assert_absent(r"\b(Time|OS)\s*\.", "scripts/sim/ read a wall clock or the OS:")


## The view produces exactly one PlayerIntent per fixed step; the sim reads only
## that. Reading live input inside the sim would make a ghost unable to reproduce a
## run, because there'd be state the intent stream doesn't carry.
func test_the_sim_never_reads_live_input() -> void:
	_assert_absent(r"\bInput(Map|EventKey|EventMouse)?\s*\.",
			"scripts/sim/ read live input rather than the PlayerIntent (guardrail 4):")


# ---------------------------------------------------------------- the view's half

## The view only READS SimState. It may swap the whole object on a reset — that is
## how a new run begins — but it must never poke a field, because then the model's
## mutation order stops being auditable in one place and determinism goes with it.
func test_the_view_never_writes_into_sim_state() -> void:
	var re := RegEx.new()
	assert_eq(re.compile(r"_state\.\w+\s*(\+=|-=|\*=|/=|=[^=])"), OK, "guard regex failed")
	var hits := PackedStringArray()
	var lines := _code_lines(VIEW)
	for i in lines.size():
		if re.search(lines[i]) != null:
			hits.append("%s:%d  %s" % [VIEW.get_file(), i + 1, lines[i].strip_edges()])
	assert_eq(hits.size(), 0,
			"the view wrote into SimState (guardrail 3):\n    %s" % "\n    ".join(hits))


## And SimState itself carries no Node — the property that makes it snapshottable.
func test_sim_state_holds_no_node() -> void:
	var s := SimState.new()
	for prop in s.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = s.get(prop.name)
		assert_false(value is Node, "SimState.%s holds a Node" % prop.name)


## THE test that keeps the rest of this suite honest.
##
## Every "must not appear" check above passes trivially if the scan reads nothing —
## a bad res:// path, a DirAccess that returns null under some future runner, and
## the whole suite goes quietly green while guarding air. So: assert it really found
## the sim, really read it, and really stripped comments.
func test_the_scan_actually_reads_the_sim() -> void:
	var files := _gd_files(SIM_DIR)
	assert_gt(files.size(), 10, "expected the whole sim, found %d files" % files.size())

	var names := PackedStringArray()
	for f in files:
		names.append(f.get_file())
	for expected in ["push_sim.gd", "sim_state.gd", "sim_clock.gd", "knock.gd", "cover_window.gd"]:
		assert_true(names.has(expected), "the scan missed %s — it isn't covering the sim" % expected)

	# The files have content, and the comment stripper leaves the code behind.
	var code := "\n".join(_code_lines("res://scripts/sim/push_sim.gd"))
	assert_true(code.contains("static func zone_of"), "push_sim.gd read back without its code")
	assert_false(code.contains("guardrail"), "comments should have been stripped out")

	# And the view file the last guard reads is really there.
	assert_gt(_code_lines(VIEW).size(), 100, "the view read back as %d lines" % _code_lines(VIEW).size())


## The guards have to be able to fail, or they are decoration. This runs each
## pattern against a line that SHOULD trip it.
func test_the_guards_actually_match_something() -> void:
	var cases := {
		r"\b(get_node|add_child|queue_redraw|get_tree|get_viewport|get_window)\s*\(": "\tadd_child(thing)",
		r"(^|[^.\w])(randf|randi|randf_range|randi_range|randomize)\s*\(": "\tvar x := randf()",
		r"\b(Time|OS)\s*\.": "\tvar t := Time.get_ticks_msec()",
		r"\bInput(Map|EventKey|EventMouse)?\s*\.": "\tif Input.is_action_pressed(\"push\"):",
		r"_state\.\w+\s*(\+=|-=|\*=|/=|=[^=])": "\t_state.relief = 50.0",
	}
	for pattern in cases:
		var re := RegEx.new()
		assert_eq(re.compile(pattern), OK, "pattern failed to compile: %s" % pattern)
		assert_ne(re.search(cases[pattern]), null,
				"guard never matches its own bad example: %s" % pattern)

	# ...and the seeded form must NOT trip the RNG guard, or the guard is unusable.
	var rng_re := RegEx.new()
	rng_re.compile(r"(^|[^.\w])(randf|randi|randf_range|randi_range|randomize)\s*\(")
	assert_eq(rng_re.search("\tvar dir := clock.rng.randf()"), null,
			"the seeded rng must not read as a violation")
