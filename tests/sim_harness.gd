class_name SimHarness
extends RefCounted
## A headless match, assembled and stepped exactly the way the game assembles and
## steps one.
##
## Seven suites had each grown their own `_run()`: build the level, seed a clock,
## resolve the timeline, then `for step: scheduler.tick; sim.tick; clock.advance`.
## Same fifteen lines seven times, differing only in which intent fields the test
## drove — and every new hazard suite added an eighth copy. Worse, they had already
## started to drift: some resolved the timeline from the match clock's RNG and one
## from a separate generator, which is a different schedule.
##
## That matters more here than ordinary duplication would. These loops ARE the
## determinism contract — the order of scheduler-then-sim-then-advance is what the
## whole §17 guardrail set rests on — and seven copies of a contract is seven
## chances to guard a sequence the game doesn't actually run.
##
## Named `sim_harness.gd`, not `test_*.gd`, so the runner treats it as a helper
## rather than trying to run it as a suite.
##
## Intents are a pure function of the step number, which is the same contract a
## recorded ghost will satisfy — so a pattern written here is, in principle, a
## replayable input stream.

var level: LevelDef
var clock: SimClock
var state: SimState
var sim := PushSim.new()
var scheduler := EventScheduler.new()

## Intent patterns. Each is either a Callable(step: int) taking the step number, or
## a constant of the right type — `holding(true)` is far commoner than a pattern
## and shouldn't have to be spelled as a closure.
var _holds: Variant = false
var _taps: Variant = false
var _swipes: Variant = Vector2.ZERO

## When >= 0, the needle is re-pinned to this before every tick, and its velocity
## zeroed. Isolates fill from the needle physics — the bowl suite's whole method,
## since it measures rate at a known height rather than wherever gravity put you.
var _pin: float = -1.0


## Build a match on `level_def`. The level is resolved IN PLACE (that is what
## resolve_timeline does), so hand in a fresh one per harness — a level reused
## across two harnesses would have its jitter rolled twice.
func _init(level_def: LevelDef, seed_value: int = 1337, existing: SimState = null) -> void:
	level = level_def
	clock = SimClock.new(seed_value)
	var timeline: Array[SimEvent] = []
	if existing == null:
		# From the match clock's own RNG, before the first tick — the order the game
		# uses, and the reason a given seed reproduces a given schedule.
		level.resolve_timeline(SimClock.FIXED_DT, clock.rng)
		state = SimState.for_level(level)
		timeline = level.timeline
	else:
		# A continuation runs no timeline at all — see `continuing()`.
		state = existing
	scheduler.load_timeline(timeline)


## Chainable factory, so a whole run reads as one sentence:
##   SimHarness.on(level).holding(pattern).seconds(6.0).state
static func on(level_def: LevelDef, seed_value: int = 1337) -> SimHarness:
	return SimHarness.new(level_def, seed_value)


## Keep ticking a state that ALREADY EXISTS — a pile already built, matter already
## graded — instead of opening a fresh sit. The bowl suite's method: arrange a
## state, then measure what one more stretch of a different level does to it.
##
## Runs NO timeline, deliberately. A continuation has no meaningful step zero, so
## loading the level's events would fire the entire schedule from the top against a
## state that is already halfway through a run. This is for isolating the physics —
## the settle, the mass-weighted grading, where the stream lands — on state you
## arranged yourself, and the levels it is used with have no timeline anyway.
static func continuing(existing: SimState, level_def: LevelDef,
		seed_value: int = 1337) -> SimHarness:
	return SimHarness.new(level_def, seed_value, existing)


# ------------------------------------------------------------------- the intent

## Whether the push is held. Pass a bool for a constant, or Callable(step) -> bool.
func holding(pattern: Variant) -> SimHarness:
	_holds = pattern
	return self


## Whether a tap fires this step. Bool, or Callable(step) -> bool.
func tapping(pattern: Variant) -> SimHarness:
	_taps = pattern
	return self


## The drag this step. Vector2, or Callable(step) -> Vector2.
func swiping(pattern: Variant) -> SimHarness:
	_swipes = pattern
	return self


## Hold the needle at a fixed height, re-pinned every step. Use when the thing
## under test is the fill curve rather than the physics that gets you there.
func pinned_at(needle: float) -> SimHarness:
	_pin = needle
	return self


## What the patterns say for a given step. Exposed because it is exactly the
## PlayerIntent a ghost would have recorded, and a test may want to assert on it.
func intent_at(step: int) -> PlayerIntent:
	var intent := PlayerIntent.new()
	intent.holding = bool(_resolve(_holds, step))
	intent.tap = bool(_resolve(_taps, step))
	intent.swipe = _resolve(_swipes, step)
	return intent


static func _resolve(pattern: Variant, step: int) -> Variant:
	return pattern.call(step) if pattern is Callable else pattern


# ---------------------------------------------------------------- the step loop

## Advance `count` steps, stopping early if the run ends. THE loop — the one the
## game runs, written once.
func step(count: int) -> SimHarness:
	for _i in count:
		if state.phase != SimState.Phase.PLAYING:
			break
		if _pin >= 0.0:
			state.needle = _pin
			state.needle_vel = 0.0
		var intent := intent_at(clock.step)
		scheduler.tick(clock, state)
		sim.tick(state, intent, clock, level, SimClock.FIXED_DT)
		clock.advance()
	return self


## Advance a duration, in sim seconds. The conversion was written out at nearly
## every call site as `int(6.0 / SimClock.FIXED_DT)`.
func seconds(duration: float) -> SimHarness:
	return step(int(duration / SimClock.FIXED_DT))


## Advance until `predicate` holds, or `limit` steps have passed. Returns the step
## it stopped on, or -1 if it never held — checked BEFORE each tick, so a predicate
## true at the start stops immediately without stepping.
func step_until(predicate: Callable, limit: int) -> int:
	for _i in limit:
		if predicate.call(self):
			return clock.step
		if state.phase != SimState.Phase.PLAYING:
			return -1
		step(1)
	return -1
