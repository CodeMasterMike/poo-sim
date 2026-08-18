extends Control
## The Sit — the controller.
##
## This node owns NO gameplay state and paints nothing. It builds a MatchConfig,
## runs the sim on a fixed timestep, turns input into one PlayerIntent per step,
## and hands the model to two renderers. All rules live in scripts/sim/
## (deterministic, seeded, UI-decoupled) so the same core can later drive a ghost
## replay or a mirrored 1v1 board (spec §17).
##
## The screen is four collaborators:
##   SitScene   the room, the man, the bowl        (style guide register A)
##   SitHud     the gauges and the results card    (register B)
##   SitFrame   what the view is doing ABOUT the model — flashes, shake, the clock
##   VectorDraw the primitives both renderers paint in
##
## Hold ANYWHERE to raise the needle; release to let it fall. Keep the needle in
## the green Flow Zone to fill cleanly. The Flow Zone shifts and narrows mid-run —
## that's the timeline talking — and the hazards arrive on top of it. Camp the red
## and you splash (Cleanliness) and get loud (Discretion). Let Composure run out and
## you lose. You WIN when the pile in the bowl reaches the goal line: how much that
## takes depends on how it settled, so a firm, well-aimed pile gets there on less.
## Tap or press R to retry.
##
## Tuning lives in exactly ONE place: LevelDef (scripts/sim/level_def.gd), a
## Resource with @export fields. Leave `tuning_override` empty to use its
## defaults — the same values the test suites read — or assign a .tres to
## experiment without editing code.
## Which venue to run, named by its LevelCatalog id.
##
## The roster lives in scripts/content/level_catalog.gd and is the only place a
## level is registered: add an entry there and it appears in the picker, on a
## number key, in the field manual and in the HUD hint with no edit here. An
## unknown id falls back to the first entry rather than failing to build.
@export var level_id: StringName = &"greybox"

## Leave EMPTY for normal play: tuning then comes from data/levels/base_tuning.tres
## via Tuning.base(), which is also what the test suites read — one source, so the
## suite checks the numbers you're actually playing. Assign a .tres here only to
## try something on this scene alone, knowing the tests won't see it.
@export var tuning_override: LevelDef

## The per-match seed. Everything random — currently the jitter on when hazards
## fire — is rolled from this, so one seed always replays the same sit. Change it
## to reshuffle the schedule.
@export var match_seed: int = 1337

## Start with the debug auto-player attached (see scripts/debug/auto_player.gd).
## Toggle at runtime with B. Off in normal play.
@export var auto_play: bool = false

# (The palette aliases went with the drawing. This node paints nothing now — it
# owns the loop, the input and the overlays, and hands the model to two renderers.)

# --- Sim (the model + systems; the view only reads state) ---
var _level: LevelDef
var _match: MatchConfig
var _clock: SimClock
var _state: SimState
var _sim: PushSim
var _scheduler: EventScheduler

# --- Fixed-timestep loop ---
var _accum: float = 0.0
const MAX_STEPS_PER_FRAME: int = 8   ## avoids a spiral of death after a hitch

# --- Input buffer (drained into a PlayerIntent once per fixed step) ---
var _mouse_down: bool = false
var _key_down: bool = false
var _touches: Dictionary = {}
var _tap_queued: bool = false
var _swipe_queued: Vector2 = Vector2.ZERO
## A tap is a SHORT press. It has to be distinguished from the press that begins
## a hold, or every push would dismiss The Buzz by accident.
const TAP_MAX_SECONDS: float = 0.25
var _press_started: float = 0.0
var _auto_hold: bool = false      ## set by the debug auto-player, if attached
var _auto_swipe: Vector2 = Vector2.ZERO
var _auto_tap: bool = false
var _auto_player: AutoPlayer = null

## View-only feedback — flashes, shake, the view clock. Never feeds back into the
## sim; see SitFrame, which owns both the values and the edge detection that
## derives them from the model.
var _frame := SitFrame.new()

## The room, the man and the bowl. Built in _ready() because it paints into this
## node, and rebuilt on nothing else — the match seed it carries drives the pile's
## surface noise, and that seed doesn't change within a session.
var _scene: SitScene

## The instrument panel, over the scene. Holds the scene too — the loss screen
## composites the sitter back over its own scrim.
var _hud: SitHud

# --- Overlays (pure view; the sim pauses while either is open) ---
var _manual: ManualOverlay
var _picker: LevelPicker
## Edge tracker for the overlay pause. The input buffer is flushed on BOTH edges —
## see _clear_input_buffer for why that is load-bearing rather than tidy.
var _overlay_was_open: bool = false


func _ready() -> void:
	# The root must not pick up mouse events: gameplay input arrives through
	# _unhandled_input, which only fires for events no Control took first. Leaving
	# this at the Control default (STOP) would have the root swallow every click
	# during the GUI pass, and the HUD buttons would never get one.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene = SitScene.new(self, match_seed)
	_hud = SitHud.new(self, _scene)
	_reset()
	_manual = ManualOverlay.new()
	add_child(_manual)
	_picker = LevelPicker.new()
	add_child(_picker)
	_picker.setup(LevelCatalog.names(), _current_level_index())
	_picker.level_chosen.connect(_on_level_chosen)
	if auto_play:
		_set_auto_play(true)


func _holding_now() -> bool:
	return _auto_hold or _mouse_down or _key_down or not _touches.is_empty()


func _overlays_open() -> bool:
	return (_manual != null and _manual.is_open()) or (_picker != null and _picker.is_open())


## Drop every held key, button and finger, and any queued edge.
##
## Called on both edges of the overlay pause, because a press and its release can
## straddle one. _unhandled_input returns early while an overlay is open, and an
## open overlay's panel eats mouse and touch events during the GUI pass — so the
## RELEASE never arrives, and the flag stayed set forever. Holding Space and
## pressing H, then letting go and pressing H again, left the sitter pushing at
## full force with nothing held: the needle pinned to the top of the red zone and
## the run played itself out. Same trap on touch, with a second finger on "?".
##
## Flushing on the way IN matters too: the sit is paused under an overlay, so
## resuming mid-push would hand back a needle the player let go of a menu ago.
func _clear_input_buffer() -> void:
	_mouse_down = false
	_key_down = false
	_touches.clear()
	_tap_queued = false
	_swipe_queued = Vector2.ZERO


## Read-only access to the model for debug tooling. The view itself only ever
## reads _state; nothing outside the sim may mutate it.
func sim_state() -> SimState:
	return _state


## Read-only access to the active level, for the debug auto-player (it needs the
## silence tuning to play a quiet room). Never mutated from outside the sim.
func current_level() -> LevelDef:
	return _level


## Input hook for the debug auto-player — deliberately routed through the same
## intent path as a human hold, so a bot run is a real run.
func set_auto_hold(value: bool) -> void:
	_auto_hold = value


## Queue a swipe for the next simulation step, as a drag would. Debug-only.
func set_auto_swipe(value: Vector2) -> void:
	_auto_swipe = value


## Queue a tap for the next simulation step, as a short press would. Debug-only.
func set_auto_tap(value: bool) -> void:
	_auto_tap = value


func _set_auto_play(enabled: bool) -> void:
	auto_play = enabled
	if enabled and _auto_player == null:
		_auto_player = AutoPlayer.new()
		_auto_player.name = "AutoPlayer"
		_auto_player.sit = self
		add_child(_auto_player)
	elif not enabled and _auto_player != null:
		_auto_player.queue_free()
		_auto_player = null
		_auto_hold = false


## Gameplay input, and deliberately _unhandled_input rather than _input.
##
## _input runs BEFORE the GUI pass, so the HUD buttons ("?" and "LEVEL") used to
## leak: a press on either also began a push, its release queued a tap that
## dismissed a live Buzz for free, and after a run had ended the same press both
## retried the run and opened the overlay it was aimed at. _unhandled_input only
## sees what no Control claimed, so a button press is now a button press.
func _unhandled_input(event: InputEvent) -> void:
	# An open overlay (manual or level picker) owns input: H/Esc close it, everything
	# else is swallowed so a menu tap can't leak into a push, tap, or retry.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_manual.toggle()
			return
		if event.keycode == KEY_ESCAPE:
			if _manual.is_open():
				_manual.close()
				return
			if _picker.is_open():
				_picker.close()
				return
	if _manual.is_open() or _picker.is_open():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
		if event.pressed:
			_press_started = _frame.t
		elif _frame.t - _press_started <= TAP_MAX_SECONDS:
			_tap_queued = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			_press_started = _frame.t
		else:
			_touches.erase(event.index)
			if _frame.t - _press_started <= TAP_MAX_SECONDS:
				_tap_queued = true
	elif event is InputEventScreenDrag:
		_swipe_queued += event.relative
	elif event is InputEventMouseMotion and _mouse_down:
		# Desktop equivalent of a thumb swipe: drag while holding to waft.
		_swipe_queued += event.relative
	elif event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			_key_down = event.pressed
		elif event.keycode == KEY_R and event.pressed:
			_reset()
		elif event.keycode == KEY_B and event.pressed:
			_set_auto_play(not auto_play)
		elif event.pressed:
			# Number keys select a venue by its position in the roster. Derived from
			# the catalog rather than a key per level, so registering the fourth
			# venue puts it on the 4 key without an edit here — and a roster longer
			# than nine simply stops handing out keys instead of misfiring.
			var slot: int = event.keycode - KEY_0
			if slot >= 1 and slot <= LevelCatalog.key_slots():
				_switch_level(LevelCatalog.id_for_slot(slot))

	# When the run is over, any fresh press retries.
	if _state != null and _state.phase != SimState.Phase.PLAYING:
		var pressed_now: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed_now:
			_reset()


func _process(delta: float) -> void:
	# The view clock runs even while paused: the input layer times taps against it,
	# and freezing it would make a press that spans a menu read as a tap.
	_frame.t += delta

	# An open overlay pauses the sitting — no clock drain, no hazards advancing.
	# (_accum only grows inside _advance_sim, so time can't pile up while paused.)
	#
	# Watched as an EDGE, and flushed on both of them. Every route in and out of an
	# overlay lands here — the H/Esc keys, the "?" and "LEVEL" buttons, and the
	# panels' own CLOSE buttons — so this one check covers them all, where hooking
	# the individual callers would miss whichever one was added next.
	var overlay_open := _overlays_open()
	if overlay_open != _overlay_was_open:
		_overlay_was_open = overlay_open
		_clear_input_buffer()
	if overlay_open:
		return
	_advance_sim(delta)

	# View feedback, driven by (never driving) the model. AFTER the step, so the
	# flashes are edge-detected against the state about to be drawn.
	_frame.advance(_state, delta, _holding_now())

	queue_redraw()


## Advance the sim in whole FIXED_DT chunks. Leftover time stays in the
## accumulator — a partial step must never reach the sim, or determinism breaks.
func _advance_sim(real_dt: float) -> void:
	_accum += real_dt
	var steps := 0
	while _accum >= SimClock.FIXED_DT and steps < MAX_STEPS_PER_FRAME:
		if _state.phase != SimState.Phase.PLAYING:
			_accum = 0.0
			break
		var intent := _drain_intent()
		_scheduler.tick(_clock, _state)
		_sim.tick(_state, intent, _clock, _level, SimClock.FIXED_DT)
		_clock.advance()
		_accum -= SimClock.FIXED_DT
		steps += 1
	# DROP whatever the step cap couldn't take. Capping the steps alone is only half
	# the guard: below ~7.5fps a frame arrives with more than MAX_STEPS_PER_FRAME
	# worth of time in it, the remainder stays banked, and the sim falls further
	# behind wall-clock every frame while never catching up. Sim time is allowed to
	# run slow on a struggling device; it is not allowed to owe an unpayable debt.
	_accum = minf(_accum, SimClock.FIXED_DT * float(MAX_STEPS_PER_FRAME))


## Build exactly one intent for this step, consuming any queued edges so each tap
## belongs to a single step (the contract that makes replay reproducible).
func _drain_intent() -> PlayerIntent:
	var intent := PlayerIntent.new()
	intent.holding = _holding_now()
	intent.tap = _tap_queued or _auto_tap
	intent.swipe = _swipe_queued + _auto_swipe
	_tap_queued = false
	_swipe_queued = Vector2.ZERO
	_auto_swipe = Vector2.ZERO
	_auto_tap = false
	return intent


## Every venue is built the same way: take the shared tuning base, hand it to the
## level's factory, let the factory specialise it. The base used to reach only the
## grey-box, so tuning it left the Church and the Rave on the code defaults.
##
## WHICH factory is the catalog's business, not this node's. The `match` that used
## to stand here was the second of six places a venue had to be named, and the one
## most likely to be updated correctly while the other five drifted.
func _build_level() -> LevelDef:
	return LevelCatalog.build(level_id, _tuning_base())


## The shared tuning, or this scene's experiment override if one is assigned.
## Always a fresh copy — the timeline resolves its trigger points in place, so a
## shared instance would carry one run's jitter into the next.
func _tuning_base() -> LevelDef:
	return tuning_override.duplicate() if tuning_override != null else Tuning.base()


func _reset() -> void:
	_level = _build_level()
	_match = MatchConfig.single_player(_level, match_seed)
	_clock = SimClock.new(_match.match_seed)
	# Roll the schedule's randomness from the match seed, before the first tick.
	_level.resolve_timeline(SimClock.FIXED_DT, _clock.rng)
	_state = SimState.for_level(_level)
	_sim = PushSim.new()
	_scheduler = EventScheduler.new()
	_scheduler.load_timeline(_level.timeline)

	_accum = 0.0
	_frame.reset()


# ------------------------------------------------------------------ rendering

## Two layers and a shake. Everything either layer needs arrives as arguments —
## this node keeps no drawing state of its own.
func _draw() -> void:
	var vp := get_viewport_rect().size
	# The shake is applied here, once, so the scene and the panel rattle together.
	# Applying it per-layer would let them slide against each other.
	draw_set_transform(_frame.shake, 0.0, Vector2.ONE)
	_scene.draw(_state, _level, _frame, vp.x, vp.y)
	_hud.draw(_state, _level, _clock, _scheduler, _frame, auto_play, vp.x, vp.y)


## Where the currently-running venue sits in the roster — the one place the host's
## id and the picker's index are converted into each other.
func _current_level_index() -> int:
	return LevelCatalog.index_of(level_id)


## Switch venue and restart, keeping the picker button/highlight in sync. The one
## path used by both the number keys and a picker tap.
##
## An empty id is ignored rather than reset to the first venue: it means a key was
## pressed for a slot the roster doesn't fill, and the honest response to that is
## to keep playing the level you were on.
func _switch_level(id: StringName) -> void:
	if id.is_empty():
		return
	level_id = id
	_reset()
	if _picker != null:
		_picker.set_current(_current_level_index())


func _on_level_chosen(index: int) -> void:
	_manual.close()
	var entry := LevelCatalog.at(index)
	if entry != null:
		_switch_level(entry.id)
