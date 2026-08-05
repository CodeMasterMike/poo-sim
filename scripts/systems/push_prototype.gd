extends Control
## The Sit — view + controller (grey-box).
##
## This node owns NO gameplay state. It builds a MatchConfig, runs the sim on a
## fixed timestep, and renders whatever the SimState says. All rules live in
## scripts/sim/ (deterministic, seeded, UI-decoupled) so the same core can later
## drive a ghost replay or a mirrored 1v1 board (spec §17).
##
## Hold ANYWHERE to raise the needle; release to let it fall. Keep the needle in
## the green Flow Zone to fill Relief cleanly. The Flow Zone shifts mid-run and a
## scripted event drops Discretion — that's the timeline talking. Camp the red and
## you splash (Cleanliness) and get loud (Discretion). Let Composure run out and
## you lose. Fill Relief to 100% to win. Tap or press R to retry.
##
## Tuning lives in exactly ONE place: LevelDef (scripts/sim/level_def.gd), a
## Resource with @export fields. Leave `tuning_override` empty to use its
## defaults — the same values the test suites read — or assign a .tres to
## experiment without editing code.
## Which level content to run. GREYBOX runs the shared tuning unmodified, so it's
## the level that shows you what a tuning change did; CHURCH and RAVE are the two
## cover-window levels (same system at opposite polarity). All three are built the
## same way, from the same tuning base. Switch at runtime with the 1 / 2 / 3 keys.
enum LevelKind { GREYBOX, CHURCH, RAVE }
@export var level_kind: LevelKind = LevelKind.GREYBOX

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

# --- Colours: aliased from the locked Palette (docs/specs/poo-sim-style-guide.html)
#     so every screen draws from one source and can't drift. Local names keep the
#     draw code terse. ---
const BG := Palette.BG
const PANEL := Palette.PANEL
const DEAD := Palette.DEAD
const FLOW := Palette.FLOW
const FLOW_DIM := Palette.FLOW_DIM
const RED := Palette.RED
const RED_DIM := Palette.RED_DIM
const AMBER := Palette.AMBER
const ORANGE := Palette.ORANGE
const NEEDLE := Palette.NEEDLE
const TEXT := Palette.TEXT
const TEXT_DIM := Palette.TEXT_DIM
const GOAL := Palette.GOAL
const MATTER := Palette.MATTER
const MATTER_DARK := Palette.MATTER_DARK
const WATER := Palette.WATER

## The room's ground plane, as a fraction of screen height. Sits below both the
## gauge and the bowl so the whole scene stands on one floor. Everything under it
## is HUD apron: the prompt band and the footer readouts.
const FLOOR_Y := 0.735

## How many render samples the bowl's heightfield is drawn at, per simulated
## column. The sim settles 24 columns; drawing them raw reads as 24 visible
## steps, so the silhouette is resampled finer and roughened on top.
const PILE_SUBDIV: int = 3

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

# --- View-only feedback (never feeds back into the sim) ---
var _t: float = 0.0
var _splash_flash: float = 0.0
var _last_splash_pulse: int = 0
var _milestone_flash: float = 0.0
var _next_milestone: int = 25
var _shake: Vector2 = Vector2.ZERO
var _last_hazard_pulse: int = 0
var _knock_flash: float = 0.0
var _knock_flash_good: bool = false

# --- Overlays (pure view; the sim pauses while either is open) ---
var _manual: ManualOverlay
var _picker: LevelPicker


func _ready() -> void:
	_reset()
	_manual = ManualOverlay.new()
	add_child(_manual)
	_picker = LevelPicker.new()
	add_child(_picker)
	_picker.setup(_level_names(), _current_level_index())
	_picker.level_chosen.connect(_on_level_chosen)
	if auto_play:
		_set_auto_play(true)


func _holding_now() -> bool:
	return _auto_hold or _mouse_down or _key_down or not _touches.is_empty()


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


func _input(event: InputEvent) -> void:
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
			_press_started = _t
		elif _t - _press_started <= TAP_MAX_SECONDS:
			_tap_queued = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			_press_started = _t
		else:
			_touches.erase(event.index)
			if _t - _press_started <= TAP_MAX_SECONDS:
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
		elif event.keycode == KEY_1 and event.pressed:
			_switch_level(LevelKind.GREYBOX)
		elif event.keycode == KEY_2 and event.pressed:
			_switch_level(LevelKind.CHURCH)
		elif event.keycode == KEY_3 and event.pressed:
			_switch_level(LevelKind.RAVE)

	# When the run is over, any fresh press retries.
	if _state != null and _state.phase != SimState.Phase.PLAYING:
		var pressed_now: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed_now:
			_reset()


func _process(delta: float) -> void:
	_t += delta
	# An open overlay pauses the sitting — no clock drain, no hazards advancing.
	# (_accum only grows inside _advance_sim, so time can't pile up while paused.)
	if (_manual != null and _manual.is_open()) or (_picker != null and _picker.is_open()):
		return
	_advance_sim(delta)

	# View feedback, driven by (never driving) the model.
	if _state.splash_pulse != _last_splash_pulse:
		_last_splash_pulse = _state.splash_pulse
		_splash_flash = 0.4
	while _state.relief >= float(_next_milestone) and _next_milestone < 100:
		_milestone_flash = 0.5
		_next_milestone += 25

	# The pile used to be sampled here, one layer per 3.3% of Relief. It is now
	# simulated — PushSim deposits and settles a heightfield every fixed step —
	# so there is nothing for the view to record. _draw() reads state.bowl.

	_splash_flash = maxf(0.0, _splash_flash - delta)
	_milestone_flash = maxf(0.0, _milestone_flash - delta)
	var shake_mag := 0.0
	if _splash_flash > 0.0:
		shake_mag = 7.0 * (_splash_flash / 0.4)
	# Turbulence keeps rattling the whole time it's on you.
	var jolt := Hazards.find(_state, SimEvent.Kind.JOLT)
	if jolt != null and jolt.phase == HazardSlot.Phase.ACTIVE:
		shake_mag = maxf(shake_mag, 5.0)
	if shake_mag > 0.0:
		_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_mag
	else:
		_shake = Vector2.ZERO

	# Hazard resolution feedback — edge-detected off the model, purely visual.
	if _state.hazard_resolve_pulse != _last_hazard_pulse:
		_last_hazard_pulse = _state.hazard_resolve_pulse
		_knock_flash = 0.8
		_knock_flash_good = not _state.last_hazard_failed
	_knock_flash = maxf(0.0, _knock_flash - delta)

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
func _build_level() -> LevelDef:
	var base := _tuning_base()
	match level_kind:
		LevelKind.CHURCH:
			# Quiet room, exposed by default — a swell shields you.
			return LevelChurch.build(base)
		LevelKind.RAVE:
			# The Church's inverse — covered by default, hushes expose you.
			return LevelRave.build(base)
		_:
			return LevelGreybox.build(base)


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
	_state = _initial_state(_level)
	_sim = PushSim.new()
	_scheduler = EventScheduler.new()
	_scheduler.load_timeline(_level.timeline)

	_accum = 0.0
	_splash_flash = 0.0
	_last_splash_pulse = 0
	_milestone_flash = 0.0
	_next_milestone = 25
	_shake = Vector2.ZERO
	_last_hazard_pulse = 0
	_knock_flash = 0.0


func _initial_state(level: LevelDef) -> SimState:
	var s := SimState.new()
	s.flow_bands = level.flow_bands.duplicate()
	s.flow_target_bands = level.flow_bands.duplicate()
	# Start at the level's own consistency, not the neutral default — otherwise
	# every sit opens the same and eases into its character a second later.
	s.thickness = level.thickness_base
	s.composure = 100.0
	s.composure_start = 100.0
	s.discretion = 100.0
	s.cleanliness = 100.0
	return s


# ------------------------------------------------------------------ rendering

func _draw() -> void:
	var vp := get_viewport_rect().size
	var w := vp.x
	var h := vp.y
	var font := ThemeDB.fallback_font
	draw_set_transform(_shake, 0.0, Vector2.ONE)

	# The scene, back to front: he sits behind the bowl, the bowl occludes his
	# lap so you can see into it, then his knees and hands come back over the
	# front rim. The stink rises off the bowl last.
	_draw_backdrop(w, h)
	_draw_sitter(w, h)
	_draw_bowl(w, h)
	_draw_sitter_legs(w, h)
	_draw_stink(w, h)

	# The venue name lives in the LEVEL button (top-left); keep the title clean.
	_text(font, "The Push", 0, int(h * 0.045), w, int(h * 0.026), TEXT)

	_draw_meters_top(font, w, h)
	_draw_quiet_status(font, w, h)
	_draw_gauge(font, w, h)
	_draw_relief_readout(font, w, h)
	_draw_smell(w, h)
	_draw_buzz(w, h)
	_draw_prompt(font, w, h)

	# Footer readouts.
	var fr := _state.flow_ratio()
	_text(font, "Flow %d%%   ·   %.1fs" % [int(round(fr * 100.0)), _clock.elapsed],
			0, int(h * 0.88), w, int(h * 0.022), TEXT_DIM)
	_text(font, "HOLD push  ·  release relax  ·  R restart  ·  1/2/3 level  ·  H manual  ·  B autoplay",
			0, int(h * 0.93), w, int(h * 0.018), TEXT_DIM)
	if auto_play:
		_text(font, "· AUTOPLAY ·", 0, int(h * 0.85), w, int(h * 0.020), GOAL)

	# Splash flash tint.
	if _splash_flash > 0.0:
		var tint := RED
		tint.a = 0.35 * (_splash_flash / 0.4)
		draw_rect(Rect2(-40, -40, w + 80, h + 80), tint)
		_text(font, "SPLASH!", 0, int(h * 0.44), w, int(h * 0.045), NEEDLE)

	# Knock resolution banner (brief).
	if _knock_flash > 0.0:
		var kcol := FLOW if _knock_flash_good else RED
		var kt := kcol
		kt.a = 0.22 * (_knock_flash / 0.8)
		draw_rect(Rect2(-40, -40, w + 80, h + 80), kt)
		var ktxt := "STAYED QUIET" if _knock_flash_good else "THEY HEARD YOU!"
		_text(font, ktxt, 0, int(h * 0.40), w, int(h * 0.040), kcol)

	_draw_overlay(font, w, h)


## The room behind the HUD: a vertical wash, a faked vignette, and a floor line.
## Oversized on every side so the splash/jolt shake can never reveal an edge.
func _draw_backdrop(w: float, h: float) -> void:
	var full := Rect2(-40, -40, w + 80, h + 80)
	_vgrad(full, BG.lightened(0.07), BG.darkened(0.30))

	_draw_room(w, h)

	# Vignette. Draw calls have no blur, so stack thin translucent frames that
	# fade as they march inward. Keep the per-step alpha low and the steps many,
	# or the falloff shows its seams.
	var steps := 16
	var bw := h * 0.016
	for i in steps:
		var inset := float(i) * bw + bw * 0.5
		var frame := Rect2(full.position.x + inset, full.position.y + inset,
				full.size.x - inset * 2.0, full.size.y - inset * 2.0)
		var fade := 1.0 - float(i) / float(steps - 1)
		draw_rect(frame, Color(0.0, 0.0, 0.0, 0.045 * fade * fade), false, bw)


## The cubicle: tiled wall, floor, skirting. Deliberately almost invisible —
## pillar 2 says the meters win every contrast fight, so this is atmosphere at
## the very edge of legibility, not scenery competing for the read.
func _draw_room(w: float, h: float) -> void:
	var fy := h * FLOOR_Y

	var grout := Palette.BORDER
	grout.a = 0.16
	var tile := w * 0.115
	var x := tile
	while x < w:
		draw_line(Vector2(x, 0.0), Vector2(x, fy), grout, 1.0)
		x += tile
	var y := tile
	while y < fy:
		draw_line(Vector2(0.0, y), Vector2(w, y), grout, 1.0)
		y += tile

	# Floor, a touch darker than the wall, and the skirting line where they meet.
	draw_rect(Rect2(-40.0, fy, w + 80.0, h - fy + 40.0), BG.darkened(0.22))
	draw_line(Vector2(-40.0, fy), Vector2(w + 40.0, fy), Palette.BORDER.darkened(0.40), 3.0)


## The sitter — the only representational art on the screen, and deliberately in
## the OTHER register (style guide §1): flat fills, one shadow tone, thick ink
## outlines, no gradients. The contrast with the glossy HUD is the joke.
##
## He is a silhouette rather than a coloured character on purpose: §6 forbids
## repurposing the semantic colours as decoration, and every warm hue in the
## palette (AMBER, ORANGE, RED, GOAL) already means something load-bearing. So
## he is built from the neutral surface tones and reads as a shape.
##
## He is drawn FRONT-ON, not in profile: a side view puts the knees and cistern
## in a line and needs width the layout can't spare, and front-on the bowl can be
## drawn straight over his lap as a cutaway so the contents are visible.
##
## This function is his UPPER body only — everything behind the bowl. His knees
## and hands come back over the front rim in _draw_sitter_legs().
func _draw_sitter(w: float, h: float) -> void:
	var cx := _scene_cx(w)
	var ink := BG.darkened(0.62)
	var iw := maxf(2.0, w * 0.005)          # §5: outlines are ~0.5% of screen width
	var cera := DEAD.lightened(0.28)
	var cera_sh := DEAD.lightened(0.02)
	var figure := PANEL.lightened(0.20)
	var figure_sh := PANEL.darkened(0.10)

	# Three poses, all view-only — read off the input buffer and the phase, never
	# fed back into the sim. Idle breathes; pushing hunches; losing slumps.
	var lost: bool = _state != null and _state.phase == SimState.Phase.LOST
	var bob := sin(_t * (0.9 if lost else 2.2)) * h * (0.002 if lost else 0.004)
	var strain := h * 0.022 if (_holding_now() and not lost) else 0.0
	var slump := h * 0.030 if lost else 0.0

	# --- the toilet's back: cistern, then the neck that carries it down onto the
	# bowl. The neck is not decoration — without it the cistern and the bowl were
	# positioned independently and the tank floated with a screen-height's worth
	# of nothing between them. It runs behind his torso, which is where the back
	# of a toilet actually is, and overlaps the bowl's top edge so they join. ---
	_rrect(Rect2(cx - w * 0.100, h * 0.310, w * 0.20, h * 0.195), cera_sh, 6, ink, int(iw))
	_rrect(Rect2(cx - w * 0.135, h * 0.203, w * 0.27, h * 0.125), cera, 8, ink, int(iw))
	_rrect(Rect2(cx - w * 0.122, h * 0.286, w * 0.244, h * 0.034), cera_sh, 5)
	_rrect(Rect2(cx - w * 0.100, h * 0.222, w * 0.075, h * 0.018), cera_sh, 4)  # the flush plate

	# --- the man ---
	# The slump drops the head furthest, the shoulders less, the hips not at all,
	# and lolls the head off-centre — a straight-down drop just reads as a shorter
	# man. Beaten posture is a curve, not a translation.
	var head := Vector2(cx + slump * 0.55, h * 0.272 + strain * 0.9 + slump + bob)
	var neck := Vector2(cx + slump * 0.25, h * 0.340 + strain * 0.7 + slump * 0.75 + bob)
	var hip := Vector2(cx, h * 0.470)
	var shoulder_l := Vector2(cx - w * 0.115 + slump * 0.10,
			h * 0.352 + strain * 0.5 + slump * 0.60 + bob)
	var shoulder_r := Vector2(cx + w * 0.115 + slump * 0.10,
			h * 0.352 + strain * 0.5 + slump * 0.60 + bob)
	var elbow_l := Vector2(cx - w * 0.160, h * 0.436 + slump * 0.55)
	var elbow_r := Vector2(cx + w * 0.160, h * 0.436 + slump * 0.55)

	# Every outline is laid down before any fill, so he reads as one silhouette
	# with a single thick outline rather than a stack of separately-inked tubes.
	var limbs := [
		[hip, neck, w * 0.072],
		[shoulder_l, shoulder_r, w * 0.052],
		[shoulder_l, elbow_l, w * 0.032], [shoulder_r, elbow_r, w * 0.032],
		[head, head, w * 0.070],
	]
	_shade_limbs(limbs, ink, figure, figure_sh, iw)


## Knees and forearms, drawn AFTER the bowl so they come back over its front rim.
## Without them he reads as a torso sunk into a basin; the knees are what say
## "seated astride this thing".
func _draw_sitter_legs(w: float, h: float) -> void:
	var cx := _scene_cx(w)
	var ink := BG.darkened(0.62)
	var iw := maxf(2.0, w * 0.005)
	var figure := PANEL.lightened(0.20)
	var lost: bool = _state != null and _state.phase == SimState.Phase.LOST
	var slump := h * 0.030 if lost else 0.0

	# No knees or legs: the bowl is drawn as a cutaway across his lap, so it
	# honestly occludes them. Drawing them anyway put two detached discs either
	# side of the basin that read as wheels, and hanging them off the hands made
	# the arms read as a scarecrow's. Torso, arms and hands on the rim is enough.
	var elbow_l := Vector2(cx - w * 0.160, h * 0.436 + slump * 0.55)
	var elbow_r := Vector2(cx + w * 0.160, h * 0.436 + slump * 0.55)
	# Hands rest on the rim; beaten, they slide off it and just hang.
	var hand_l := Vector2(cx - w * 0.212, h * 0.508)
	var hand_r := Vector2(cx + w * 0.212, h * 0.508)
	if lost:
		hand_l = Vector2(cx - w * 0.222, h * 0.556)
		hand_r = Vector2(cx + w * 0.222, h * 0.556)

	var limbs := [
		[elbow_l, hand_l, w * 0.028], [elbow_r, hand_r, w * 0.028],
	]
	_shade_limbs(limbs, ink, figure, PANEL.darkened(0.10), iw)


func _scene_cx(w: float) -> float:
	return w * 0.62


## The bowl's outer porcelain, and the cavity you can see into. Kept as two
## functions' worth of geometry in one place so the readout, the stink lines and
## the deposits can't drift out of register with the art.
func _bowl_rect(w: float, h: float) -> Rect2:
	var cx := _scene_cx(w)
	return Rect2(cx - w * 0.245, h * 0.487, w * 0.49, h * 0.228)


func _bowl_cavity(w: float, h: float) -> Rect2:
	var cx := _scene_cx(w)
	return Rect2(cx - w * 0.205, h * 0.505, w * 0.41, h * 0.190)


## The bowl — and the whole point of it, which is that Relief is no longer an
## abstract green tube. What you produced is IN there, laid down layer by layer,
## each layer as wide as the needle was at the moment it came out. A clean run
## builds an even column; a run spent bouncing off the red zone builds a lumpy
## mess. The bowl is the meter and the record at the same time.
func _draw_bowl(w: float, h: float) -> void:
	var ink := BG.darkened(0.62)
	var iw := maxf(2.0, w * 0.005)
	var cera := DEAD.lightened(0.28)
	var cera_sh := DEAD.lightened(0.02)
	var outer := _bowl_rect(w, h)
	var cav := _bowl_cavity(w, h)

	# Tight at the rim, deeply round at the base — a basin, not a bucket.
	_rrect_c(outer, cera, int(w * 0.045), int(w * 0.045), int(w * 0.20), int(w * 0.20),
			ink, int(iw))
	# The rim, as its own darker ring (§5: flat, 2-tone — no gradient).
	_rrect(Rect2(outer.position.x + w * 0.018, outer.position.y + h * 0.008,
			outer.size.x - w * 0.036, h * 0.020), cera_sh, int(h * 0.010))
	# The cavity: a hole, not a surface. Everything below is inside the bowl.
	_rrect_c(cav, PANEL.darkened(0.52), int(w * 0.030), int(w * 0.030),
			int(w * 0.17), int(w * 0.17))

	# Water first, so anything that lands displaces it visually. It goes off as
	# the bowl fills — clean at the start, and by the end you would not put your
	# hand in it.
	var foul := clampf(_state.relief / 100.0, 0.0, 1.0)
	var water := Rect2(cav.position.x + w * 0.012, cav.end.y - h * 0.052,
			cav.size.x - w * 0.024, h * 0.044)
	_rrect(water, WATER.lerp(MATTER_DARK, 0.75 * foul), int(h * 0.018))

	_draw_streaks(cav)
	_draw_pile(cav)
	_draw_stream(h, cav)

	# Splatter. The red zone costs Cleanliness, which the streaks above record
	# permanently; this is the moment it happens, thrown up onto the rim.
	if _splash_flash > 0.0:
		var spread := _splash_flash / 0.4
		for i in 9:
			var fx: float = outer.position.x + outer.size.x * (0.10 + 0.80 * _lump(i, 211))
			var fy: float = cav.position.y - h * 0.004 * _lump(i, 213) \
					- h * 0.030 * spread * _lump(i, 217)
			draw_circle(Vector2(fx, fy), maxf(1.5, w * 0.008 * _lump(i, 219)), MATTER)

	# The goal: a full bowl is 100%. Marked in gold on the cavity's top edge, the
	# same language the old tube used.
	var glow := GOAL
	glow.a = 0.20
	_rrect(Rect2(cav.position.x - w * 0.012, cav.position.y - h * 0.008,
			cav.size.x + w * 0.024, h * 0.014), glow, 6)
	_rrect(Rect2(cav.position.x - w * 0.006, cav.position.y - h * 0.004,
			cav.size.x + w * 0.012, h * 0.006), GOAL, 3)


## Skid marks down the porcelain. Cleanliness is the meter that already tracks
## how much you splashed, so the bowl simply wears it: the lower it drops, the
## more the walls show for it. No new state — the mess IS the score, drawn.
func _draw_streaks(cav: Rect2) -> void:
	var filth := clampf(1.0 - _state.cleanliness / 100.0, 0.0, 1.0)
	var count := int(filth * 9.0)
	for i in count:
		var sx: float = cav.position.x + cav.size.x * (0.07 + 0.86 * _lump(i, 101))
		var sy: float = cav.position.y + cav.size.y * (0.04 + 0.30 * _lump(i, 103))
		var run: float = cav.size.y * (0.10 + 0.30 * _lump(i, 107))
		var rad: float = cav.size.x * (0.010 + 0.016 * _lump(i, 109))
		_limb(Vector2(sx, sy), Vector2(sx, sy + run), rad, MATTER_DARK)
		_limb(Vector2(sx, sy), Vector2(sx, sy + run * 0.55), rad * 0.45,
				MATTER_DARK.lerp(MATTER, 0.45))


## Read the sim's heightfield at a fractional position across the bowl (0..1),
## in rim-fractions. The pile is no longer the view's invention — this is a
## straight lookup into state.bowl.
func _sample_bowl(u: float) -> float:
	var cols := _state.bowl.size()
	if cols == 0:
		return 0.0
	var p := clampf(u, 0.0, 1.0) * float(cols - 1)
	var i := clampi(int(floor(p)), 0, cols - 1)
	var a: float = _state.bowl[i]
	if i + 1 >= cols:
		return a
	return lerpf(a, _state.bowl[i + 1], p - float(i))


## The pile, drawn straight off the settled heightfield.
##
## This replaced a stack of fixed-cost layers, and the difference is the whole
## point of the change: the silhouette is now the *shape the matter settled into*.
## Runny slumps to a flat pool because the sim's angle of repose is near zero at
## low thickness; solid holds a steep mound under wherever you were aiming.
##
## Surface roughness is a pure function of (sample index, match_seed) — NOTHING
## here calls randf(). _draw() re-runs every frame, so live noise would make the
## pile crawl and shimmer instead of sitting there, and a seeded replay has to
## redraw the identical pile.
func _draw_pile(cav: Rect2) -> void:
	var cols := _state.bowl.size()
	if cols == 0:
		return
	# Sub-pixel traces are skipped, not clamped: a crest flattened onto the floor
	# line makes a zero-area polygon and draw_colored_polygon fails to triangulate.
	if _state.bowl_peak() * cav.size.y < 1.5:
		return
	var samples := cols * PILE_SUBDIV
	var flash := _milestone_flash > 0.0

	# The crest, left to right. Roughness scales with thickness (a pool is
	# smooth, a solid mass is lumpy) and fades out where the pile is thin, so
	# the first traces don't erupt into spikes over an empty bowl.
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for s in samples + 1:
		var u := float(s) / float(samples)
		var hgt := _sample_bowl(u)
		# Roughness grades off what's IN the bowl, not what's at the exit — the pile
		# shouldn't visibly smooth out just because you stopped pushing.
		var rough := (_lump(s, 401) - 0.5) * 0.10 * _state.bowl_thickness \
				* minf(1.0, hgt * 5.0)
		xs.append(cav.position.x + cav.size.x * u)
		ys.append(minf(cav.end.y - cav.size.y * clampf(hgt + rough, 0.0, 1.10), cav.end.y))

	var body := MATTER_DARK
	var crust := MATTER
	if flash:
		var k := 0.30 * (_milestone_flash / 0.5)
		body = body.lerp(NEEDLE, k)
		crust = crust.lerp(NEEDLE, k)

	# One trapezoid per interval, each trivially convex.
	#
	# NOT one polygon spanning the bowl, which is the obvious way to do this and is
	# wrong: wherever the pile runs out the crest sits exactly on the floor line, so
	# the outline doubles back along its own base edge and Godot's triangulator
	# discards most of the shape. That rendered as a spike and a smear with no
	# relation to the heightfield behind it.
	var lift := maxf(1.5, cav.size.y * 0.055)
	var quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for s in samples:
		var y0: float = ys[s]
		var y1: float = ys[s + 1]
		if minf(y0, y1) >= cav.end.y - 0.75:
			continue   # nothing here — an empty strip, not a flat one
		var x0: float = xs[s]
		var x1: float = xs[s + 1]
		# Two tones, flat, no gradient (§5), varied per strip so the mass has some
		# grain instead of reading as one poured slab. Keep the variation SMALL —
		# at a wider spread each strip resolves as its own vertical band and a
		# shallow pool starts to read as decking.
		quad[0] = Vector2(x0, y0)
		quad[1] = Vector2(x1, y1)
		quad[2] = Vector2(x1, cav.end.y)
		quad[3] = Vector2(x0, cav.end.y)
		draw_colored_polygon(quad, body.lerp(crust, 0.10 + 0.09 * _lump(s, 419)))
		# The lit crust riding the surface.
		quad[2] = Vector2(x1, minf(y1 + lift, cav.end.y))
		quad[3] = Vector2(x0, minf(y0 + lift, cav.end.y))
		draw_colored_polygon(quad, crust)

	# Wet sheen. The one thing that separates "fresh" from "a brown shape", and
	# the reason the product gets a third tone — a recorded exception to §5, see
	# the style guide. Scattered along the crest, never on every sample: an even
	# stripe of highlight reads as flaky pastry rather than something wet.
	for s in samples + 1:
		if _lump(s, 409) <= 0.62:
			continue
		if ys[s] >= cav.end.y - cav.size.y * 0.04:
			continue
		var p := Vector2(xs[s], ys[s] + lift * 0.45)
		var run := cav.size.x / float(samples) * (0.7 + 0.9 * _lump(s, 411))
		_limb(p - Vector2(run, 0.0), p + Vector2(run * 0.6, 0.0),
				maxf(1.0, lift * 0.22), Palette.MATTER_LIT)


## What's actually coming out, falling to where the sim is depositing it.
##
## Thin, quick and near-straight when it's runny; a fat, slow, wavering rope when
## it's solid. Width tracks the live fill rate, so the stream is a direct readout
## of how fast you're filling — push harder and you can see it thicken.
func _draw_stream(h: float, cav: Rect2) -> void:
	if _state.phase != SimState.Phase.PLAYING:
		return
	# Nothing is moving during a Knock freeze or the stall after a splash.
	if Hazards.relief_stalled(_state) or _state.splash_stall > 0.0:
		return
	var rate := PushSim.flow_rate(_state, _level) * PushSim.density_of(_state.thickness, _level)
	var vol := clampf(rate / maxf(0.1, _level.fill_red), 0.0, 1.3)
	if vol <= 0.03:
		return

	var thick := _state.thickness
	# Asked of the sim, not recomputed here — the stream has to land on the column
	# it is actually feeding.
	var u := PushSim.drop_u(_state, _level)
	var x := cav.position.x + cav.size.x * u
	var top := cav.position.y - h * 0.012          # emerges from behind the rim
	var land := cav.end.y - cav.size.y * clampf(_sample_bowl(u), 0.0, 1.08)
	if land <= top:
		return

	# Solid wavers on the way down; runny falls straight and fast.
	var wave := cav.size.x * 0.020 * thick
	var speed := lerpf(11.0, 4.0, thick)
	var wid := cav.size.x * (0.012 + 0.038 * vol) * (0.65 + 0.8 * thick)
	var segs := 6
	var prev := Vector2(x, top)
	for s in range(1, segs + 1):
		var f := float(s) / float(segs)
		var pt := Vector2(x + sin(_t * speed + f * 5.5) * wave * f, lerpf(top, land, f))
		# Tapers slightly toward the landing — it's stretching as it falls.
		_limb(prev, pt, wid * (1.0 - 0.18 * f), MATTER)
		prev = pt
	_limb(Vector2(x, top), Vector2(x, top + (land - top) * 0.55), wid * 0.30,
			Palette.MATTER_LIT)

	# Where it lands. Runny spreads on impact; solid just plops.
	var splat := wid * (1.6 - 0.7 * thick)
	draw_circle(prev, splat, MATTER)
	if thick < 0.5:
		var spread := splat * (1.0 + 1.4 * (0.5 - thick))
		_limb(prev - Vector2(spread, 0.0), prev + Vector2(spread, 0.0),
				maxf(1.0, wid * 0.35), MATTER)


## Deterministic 0..1 noise from a layer index and a salt, mixed with the match
## seed so a different seed grows a different pile — but the SAME seed always
## grows the same one.
func _lump(i: int, salt: int) -> float:
	var x: int = i * 73856093 ^ match_seed * 19349663 ^ salt * 83492791
	x = (x ^ (x >> 13)) * 1274126177
	return float(absi(x) % 100003) / 100003.0


## Stink lines. §5 names the squiggle as the sanctioned comedic flourish, so the
## Smell hazard gets one: three wavering lines rising out of the sitter through
## the clear gap above him. Faint and slow while the cloud is still drifting in,
## bright and fast once it's on you — the same telegraph→active read the prompt
## band and the gauge already use.
##
## They live between the columns and stop short of the pills, so they never cross
## a meter. Drawn as part of the scene, before the HUD.
func _draw_stink(w: float, h: float) -> void:
	if _state.phase != SimState.Phase.PLAYING:
		return
	var slot := Hazards.find(_state, SimEvent.Kind.SMELL)
	if slot == null:
		return
	var arrived := slot.phase == HazardSlot.Phase.ACTIVE

	var bx := _scene_cx(w)
	var base := h * 0.50                    # the bowl rim, where it's coming from
	var tip := h * 0.28
	var speed := 5.2 if arrived else 2.4
	var peak := 0.85 if arrived else 0.38
	var col := Color(0.55, 0.66, 0.24)      # the smell cloud's own green
	var steps := 16

	# Two either side of him rather than three in a line: he's centred now, so a
	# centre squiggle would just run up his chest.
	for i in 4:
		var ox: float = [-0.235, -0.155, 0.155, 0.235][i] * w
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in steps + 1:
			var f := float(k) / float(steps)
			# The wobble is scaled by f so the line stays anchored at the base
			# and only writhes as it rises.
			var wobble := sin(f * TAU * 1.5 + _t * speed + float(i) * 2.1) * w * 0.020 * f
			pts.append(Vector2(bx + ox + wobble, base + (tip - base) * f))
			# Fade out towards the tip: a squiggle that just stops looks cut off.
			var c := col
			c.a = peak * (1.0 - f) * (1.0 - f)
			cols.append(c)
		draw_polyline_colors(pts, cols, maxf(2.0, w * 0.006), true)


## Ink, shadow, then lit core — the three passes that turn a list of limbs into
## one cel-shaded silhouette. Every outline is laid down before any fill so he
## reads as a single shape rather than a stack of separately-inked tubes.
##
## The shadow is the §5 "one shadow tone", applied as a RIM: the whole figure is
## painted in the shadow tone, then the lit colour goes back on top, shrunk and
## shifted up-and-right. It used to be a couple of hand-placed blobs offset
## inside the torso and head, which on a narrow torso covered half of it and read
## as a stripe down his front rather than as light coming from anywhere.
##
## The shrink and the offset are both proportional to each limb's own radius. A
## fixed offset works on the torso and pushes the lit core straight out through
## the outline on something as thin as a forearm.
func _shade_limbs(limbs: Array, ink: Color, lit: Color, shadow: Color, iw: float) -> void:
	for limb in limbs:
		_limb(limb[0], limb[1], limb[2] + iw, ink)
	for limb in limbs:
		_limb(limb[0], limb[1], limb[2], shadow)
	for limb in limbs:
		var r: float = limb[2]
		var off := Vector2(r * 0.14, -r * 0.10)
		_limb(limb[0] + off, limb[1] + off, r * 0.80, lit)


## One round-capped bar. draw_line has no round caps, so each end gets a circle.
## Passing the same point twice draws a plain disc — that is how the head is done.
func _limb(a: Vector2, b: Vector2, r: float, col: Color) -> void:
	if a != b:
		draw_line(a, b, col, r * 2.0)
	draw_circle(a, r, col)
	draw_circle(b, r, col)


func _draw_meters_top(font: Font, w: float, h: float) -> void:
	var mx := w * 0.06
	var mw := w * 0.88

	# Composure — the master clock, full-width up top.
	_text(font, "COMPOSURE", mx, int(h * 0.072), mw, int(h * 0.016), TEXT_DIM)
	var cy := h * 0.082
	var ch := h * 0.024
	_track(Rect2(mx, cy, mw, ch), _state.composure / 100.0, _meter_color(_state.composure))

	# Discretion + Cleanliness pills, side by side.
	var py := h * 0.125
	var ph := h * 0.022
	var pw := (mw - w * 0.03) * 0.5
	_pill(font, "DISCRETION", _state.discretion, mx, py, pw, ph, int(h * 0.015))
	_pill(font, "CLEANLINESS", _state.cleanliness, mx + pw + w * 0.03, py, pw, ph, int(h * 0.015))


func _pill(font: Font, label: String, value: float, x: float, y: float, pw: float, ph: float, fs: int) -> void:
	_text(font, "%s  %d" % [label, int(round(value))], x, int(y - h_gap()), pw, fs, TEXT_DIM)
	_track(Rect2(x, y, pw, ph), value / 100.0, _meter_color(value))


## A rounded meter track with a FLAT fill — the shared look for Composure and the
## two pills. `col` comes from _meter_color(), so the red→amber→green state
## language is untouched.
##
## No gradient, no gloss. §5 is explicit that gradients are juice only and never
## structural, and the earlier embossed treatment broke that: it read as a glossy
## app widget rather than the earnest instrument register B is meant to be.
## Rounding stays — §5 sets a corner scale and puts meters at height/2.
func _track(rect: Rect2, frac: float, col: Color) -> void:
	_rrect(rect, PANEL.darkened(0.22), int(rect.size.y * 0.5), Palette.BORDER, 2)
	var pad := 2.5
	var fw := (rect.size.x - pad * 2.0) * clampf(frac, 0.0, 1.0)
	if fw <= 1.0:
		return
	var fill := Rect2(rect.position.x + pad, rect.position.y + pad, fw, rect.size.y - pad * 2.0)
	_rrect(fill, col, int(fill.size.y * 0.5))


func h_gap() -> float:
	return get_viewport_rect().size.y * 0.006


func _level_display_name(kind: int) -> String:
	match kind:
		LevelKind.CHURCH:
			return "Church"
		LevelKind.RAVE:
			return "Rave"
		_:
			return "Prototype"


## The venue roster, in enum order — what the picker renders. Data-driven off
## LevelKind, so a new level appears in the picker with no change here.
func _level_names() -> PackedStringArray:
	var names := PackedStringArray()
	for kind in LevelKind.values():
		names.append(_level_display_name(kind))
	return names


func _current_level_index() -> int:
	return LevelKind.values().find(level_kind)


## Switch venue and restart, keeping the picker button/highlight in sync. The one
## path used by both the 1/2/3 keys and a picker tap.
func _switch_level(kind: int) -> void:
	level_kind = kind
	_reset()
	if _picker != null:
		_picker.set_current(_current_level_index())


func _on_level_chosen(index: int) -> void:
	_manual.close()
	_switch_level(LevelKind.values()[index])


func _is_quiet_room() -> bool:
	return _level != null and _level.silence_noise_rate > 0.0


## The core read of a quiet-room level: is it safe to push right now, and is a
## soundscape change coming? Polarity-aware — the Church waits for cover, the Rave
## dreads the hush — but the three states (heads-up / danger / safe) are shared.
## Drawn only in a quiet room; ordinary levels never show it.
func _draw_quiet_status(font: Font, w: float, h: float) -> void:
	if not _is_quiet_room() or _state.phase != SimState.Phase.PLAYING:
		return
	var exposed := Hazards.room_exposed(_state, _level)
	var slot := Hazards.find(_state, SimEvent.Kind.COVER)
	var incoming: bool = slot != null and slot.phase == HazardSlot.Phase.TELEGRAPH
	var church := _level.baseline_exposed

	var col := FLOW
	var label := "BASS  —  PUSH FREELY"
	if incoming:
		# A window is telegraphing: cover incoming (Church) or a hush incoming (Rave).
		col = AMBER
		label = "the organ swells  —  GET READY" if church else "the drop's coming  —  EASE OFF SOON"
	elif exposed:
		col = RED
		label = "SILENCE  —  ease off" if church else "HUSH  —  they can hear you!"
	else:
		col = FLOW
		label = "COVER  —  PUSH NOW" if church else "BASS  —  PUSH FREELY"

	# The bar has to fit the band between the pills (bottom h*0.147) and the tops of
	# the "THE PUSH"/"RELIEF" column labels, whose caps reach up to about h*0.190
	# from their h*0.202 baseline. That leaves ~h*0.043 of room for an h*0.032 bar;
	# h*0.152 centres it. Moving it back down collides with both labels — the gauge
	# and relief columns hold the same place on every level, quiet room or not.
	var by := h * 0.152
	var bh := h * 0.032
	var bar := col
	bar.a = 0.92
	_rrect(Rect2(w * 0.06, by, w * 0.88, bh), bar, int(bh * 0.34))
	_text(font, label, 0, int(by + bh * 0.70), w, int(h * 0.020), Color(0.08, 0.07, 0.05))


## THE PUSH now hugs the left edge: the bowl and the man own the rest of the
## screen, and the gauge only ever needs to be read for the needle's HEIGHT, so
## it loses width cheaply.
func _draw_gauge(font: Font, w: float, h: float) -> void:
	var gx := w * 0.05
	var gw := w * 0.16
	var gy := h * 0.22
	var gh := h * 0.46
	var gbot := gy + gh
	var zone := PushSim.zone_of(_state)

	# Housing, then the recessed track. The track's own colour IS the dead zone;
	# the flow and red bands float on top of it.
	_rrect(Rect2(gx - 8, gy - 8, gw + 16, gh + 16), PANEL, 16, Palette.BORDER, 2)
	_rrect(Rect2(gx, gy, gw, gh), DEAD, 10)

	# Flat bands. They were gradient-and-gloss "raised surfaces"; §5 says that
	# treatment is juice, not structure, and the zones are pure structure.
	var highest := 0.0
	for band in _state.flow_bands:
		highest = maxf(highest, band.y)
		var inside: bool = _state.needle >= band.x and _state.needle <= band.y
		_band(gx, gw, gbot, gh, band.x, band.y,
				FLOW if (zone == PushSim.ZONE_FLOW and inside) else FLOW_DIM)
	_band(gx, gw, gbot, gh, highest, 1.0, RED if zone == PushSim.ZONE_RED else RED_DIM)

	# In-flow glow — a soft reward for good placement.
	if zone == PushSim.ZONE_FLOW:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		for band in _state.flow_bands:
			if _state.needle >= band.x and _state.needle <= band.y:
				# Two haloes: draw calls have no blur, so a wide-faint plus a
				# tight-brighter pass fakes the falloff.
				var outer := FLOW
				outer.a = (0.10 + 0.09 * pulse)
				_band(gx - 6, gw + 12, gbot, gh, band.x - 0.014, band.y + 0.014, outer, 14)
				var inner := FLOW
				inner.a = (0.14 + 0.12 * pulse)
				_band(gx - 3, gw + 6, gbot, gh, band.x - 0.006, band.y + 0.006, inner, 11)

	# Needle — the one pure-white mark on the screen, haloed in its zone colour.
	var ny := gbot - _state.needle * gh
	var zcol: Color = [TEXT_DIM, FLOW, RED][zone]
	# Four fading passes rather than two: with hard-edged rects, too few steps
	# read as stacked lozenges instead of a glow. The whole needle stays inside
	# the housing — a halo spilling onto the backdrop reads as a smear. The dead
	# zone's grey halo is pulled right down; it's the state with nothing to say.
	var halo_peak := 0.12 if zone == PushSim.ZONE_DEAD else 0.26
	for i in 4:
		var f := float(i) / 3.0
		var halo := zcol
		halo.a = halo_peak * (1.0 - f * 0.70)
		var hh := 32.0 - f * 15.0
		var spread := 12.0 - f * 9.0
		_rrect(Rect2(gx - spread, ny - hh * 0.5, gw + spread * 2.0, hh), halo, int(hh * 0.5))

	# Flat white bar and a capped tip. The halo above stays — a glow around the
	# needle is exactly the "juice" §5 permits; the highlight line that used to
	# run along the bar was emboss, and went.
	var body := Rect2(gx - 4.0, ny - 8.0, gw + 8.0, 16.0)
	_rrect(body, NEEDLE, 8)
	var tip := Vector2(gx + gw - 8.0, ny)
	draw_circle(tip, 11.0, NEEDLE)
	draw_arc(tip, 11.0, 0.0, TAU, 28, zcol, 2.5, true)

	# Quiet room, currently exposed: everything above the silence cap is audible —
	# mark that region so the player sees exactly how low they must ride it out.
	if _is_quiet_room() and Hazards.room_exposed(_state, _level):
		var y_cap := gbot - _level.silence_push_cap * gh
		var warn := RED
		warn.a = 0.14
		_rrect(Rect2(gx, gy, gw, y_cap - gy), warn, 10)
		draw_line(Vector2(gx, y_cap), Vector2(gx + gw, y_cap), RED, 2.0)

	# During a Knock freeze, frost the gauge and flip the demand to RELEASE (UI spec).
	if Hazards.relief_stalled(_state):
		_rrect(Rect2(gx - 8, gy - 8, gw + 16, gh + 16), Color(0.55, 0.78, 0.98, 0.16), 16)

	_text(font, "THE PUSH", gx - 8, int(gy - h * 0.018), gw + 16, int(h * 0.016), TEXT_DIM)
	# The zone name is a claim about what is happening RIGHT NOW, so it goes quiet
	# once the run is over — a frozen gauge still reading "FLOW" under the results
	# scrim says the run is live when it isn't. The gauge itself stays, as a
	# record of where the needle ended up; only the claim goes.
	if _state.phase != SimState.Phase.PLAYING:
		return
	var zname: String = ["DEAD ZONE", "FLOW", "RED ZONE"][zone]
	var zlabel_col := zcol
	if Hazards.relief_stalled(_state):
		zname = "RELEASE"
		zlabel_col = Color(0.72, 0.88, 1.0)
	# The zone name gets a WIDER region than the gauge itself. At this column
	# width "DEAD ZONE" clips to "DEAD Z"; the strip to the gauge's right is empty
	# down here, so the label can centre on the gauge and overhang it.
	_text(font, zname, 0, int(gbot + h * 0.04), w * 0.26, int(h * 0.024), zlabel_col)


## Relief lost its abstract green tube — the bowl IS the meter now, so all that's
## left is the precise readout. A pile is a great feel and a poor number, and the
## win condition is an exact 100%, so the digits stay.
func _draw_relief_readout(font: Font, w: float, h: float) -> void:
	# Once the run is over the results screen owns every number, and this one sits
	# exactly where the win screen puts "tap · press R to retry".
	if _state.phase != SimState.Phase.PLAYING:
		return
	var cav := _bowl_cavity(w, h)
	# Consistency rides alongside the percentage. It changes the fill rate, so it
	# can't be a thing you only infer from the shape of the pile — but it's a feel,
	# not a number, so it gets a word rather than a second percentage.
	# Wider than the cavity, and shifted back by half the excess so it stays
	# centred on the bowl — the cavity's own width clips the longer words.
	var pad := w * 0.14
	_text(font, "RELIEF  %d%%   ·   %s" % [int(_state.relief), _consistency_word()],
			cav.position.x - pad * 0.5, int(h * 0.727), cav.size.x + pad,
			int(h * 0.024), TEXT)


func _consistency_word() -> String:
	var t := _state.thickness
	if t < 0.20:
		return "RUNNY"
	if t < 0.42:
		return "LOOSE"
	if t < 0.60:
		return "STEADY"
	if t < 0.80:
		return "FIRM"
	return "SOLID"


func _draw_prompt(font: Font, w: float, h: float) -> void:
	# Nothing in-flight matters once the run is over — the results own the screen.
	if _state.phase != SimState.Phase.PLAYING:
		return
	# A live hazard owns the prompt band; otherwise fall back to a scheduled prompt.
	var text := _hazard_banner()
	var col := ORANGE
	if not text.is_empty():
		col = AMBER
		# Red once a hazard is actually on you, amber while it's still telegraphing.
		for kind in [SimEvent.Kind.SMELL, SimEvent.Kind.JOLT, SimEvent.Kind.BUZZ]:
			var s := Hazards.find(_state, kind)
			if s != null and s.phase == HazardSlot.Phase.ACTIVE:
				col = RED
		if Hazards.relief_stalled(_state):
			col = RED
	elif not _scheduler.last_prompt.is_empty():
		text = _scheduler.last_prompt
	if text.is_empty():
		return
	var by := h * 0.74
	var bh := h * 0.05
	_rrect(Rect2(w * 0.10, by, w * 0.80, bh), col, int(bh * 0.30))
	_text(font, text, 0, int(by + bh * 0.66), w, int(h * 0.026), Color(0.1, 0.08, 0.05))


## A live hazard owns the prompt band. The Knock wins ties — it takes your input
## away, so it's the more urgent read.
func _hazard_banner() -> String:
	var knock := Hazards.find(_state, SimEvent.Kind.KNOCK)
	if knock != null:
		match knock.phase:
			HazardSlot.Phase.TELEGRAPH:
				return "*knock*  —  GET READY"
			HazardSlot.Phase.ACTIVE:
				return "HOLD STILL  —  RELEASE!"
	var jolt := Hazards.find(_state, SimEvent.Kind.JOLT)
	if jolt != null:
		return "SWIPE TO RE-CENTER" if jolt.phase == HazardSlot.Phase.ACTIVE \
				else "*rumble*  —  BRACE"
	if Hazards.find(_state, SimEvent.Kind.BUZZ) != null:
		return "BZZT  —  TAP TO DISMISS"
	if Hazards.find(_state, SimEvent.Kind.SMELL) != null:
		return "SMELL  —  SWIPE TO WAFT"
	return ""


## The phone, buzzing away in your pocket — jittering faster once it's ringing out.
func _draw_buzz(w: float, h: float) -> void:
	if _state.phase != SimState.Phase.PLAYING:
		return
	var slot := Hazards.find(_state, SimEvent.Kind.BUZZ)
	if slot == null:
		return
	var ringing := slot.phase == HazardSlot.Phase.ACTIVE
	var jiggle := sin(_t * 42.0) * (3.0 if ringing else 1.2)
	var pw := w * 0.055
	var ph := h * 0.048
	# In the channel between the gauge (now hard left) and the bowl, so it sits on
	# neither.
	var px := w * 0.245 + jiggle
	var py := h * 0.30
	draw_rect(Rect2(px, py, pw, ph), ORANGE if ringing else AMBER)
	draw_rect(Rect2(px + pw * 0.14, py + ph * 0.10, pw * 0.72, ph * 0.64), Color(0.12, 0.12, 0.14))


## The cloud itself: drifting and faint while incoming, close and solid once it's
## on you. Drawn from the model, so it can't disagree with the hazard state.
func _draw_smell(w: float, h: float) -> void:
	if _state.phase != SimState.Phase.PLAYING:
		return
	var slot := Hazards.find(_state, SimEvent.Kind.SMELL)
	if slot == null:
		return
	var arrived := slot.phase == HazardSlot.Phase.ACTIVE
	var col := Color(0.55, 0.66, 0.24, 0.55 if arrived else 0.28)
	var r := w * (0.13 if arrived else 0.10)
	var cx := w * 0.5 + sin(_t * 1.6) * w * (0.02 if arrived else 0.06)
	var cy := h * 0.168
	draw_circle(Vector2(cx, cy), r, col)
	draw_circle(Vector2(cx - r * 0.75, cy + r * 0.18), r * 0.72, col)
	draw_circle(Vector2(cx + r * 0.75, cy + r * 0.12), r * 0.78, col)


func _draw_overlay(font: Font, w: float, h: float) -> void:
	if _state.phase == SimState.Phase.PLAYING:
		return

	draw_rect(Rect2(-40, -40, w + 80, h + 80), Color(0.03, 0.04, 0.05, 0.80))

	if _state.phase == SimState.Phase.LOST:
		# Re-draw him ON TOP of the scrim. He is the fail state, and behind an
		# 0.80 wash of black the slump is invisible — the beat is worth more than
		# the dimming. The text lands over him and still reads: he is a flat dark
		# silhouette, which is exactly what text wants behind it.
		_draw_sitter(w, h)
		_text(font, "COULDN'T HOLD IT", 0, int(h * 0.40), w, int(h * 0.050), RED)
		_text(font, "Composure ran out.", 0, int(h * 0.47), w, int(h * 0.026), TEXT)
		# Below his feet, not across his head — the slump is the picture here.
		_text(font, "tap  ·  press R to retry", 0, int(h * 0.76), w, int(h * 0.024), TEXT_DIM)
		return

	# WON — score from the four meters.
	var result := Scoring.evaluate(_state, _level)
	_draw_stars(w * 0.5, h * 0.28, int(result.stars))
	_text(font, _rank_title(result), 0, int(h * 0.36), w, int(h * 0.040), GOAL)

	var bd: Dictionary = result["breakdown"]
	var y := 0.44
	# Bracket keys (not bd.clear — that resolves to Dictionary.clear()).
	_score_line(font, w, h, y, "Clear", int(bd["clear"])); y += 0.045
	_score_line(font, w, h, y, "Discretion", int(bd["discretion"])); y += 0.045
	_score_line(font, w, h, y, "Cleanliness", int(bd["cleanliness"])); y += 0.045
	_score_line(font, w, h, y, "Flow", int(bd["flow"])); y += 0.045
	_score_line(font, w, h, y, "Speed", int(bd["speed"])); y += 0.055
	_text(font, "SCORE  %d" % int(result["base"]), 0, int(h * y), w, int(h * 0.034), TEXT)
	_text(font, "tap  ·  press R to retry", 0, int(h * (y + 0.06)), w, int(h * 0.024), TEXT_DIM)


func _score_line(font: Font, w: float, h: float, y: float, label: String, pts: int) -> void:
	_text(font, "%s" % label, w * 0.16, int(h * y), w * 0.40, int(h * 0.024), TEXT_DIM)
	_text(font, "%d" % pts, w * 0.56, int(h * y), w * 0.24, int(h * 0.024), TEXT)


func _draw_stars(cx: float, cy: float, stars: int) -> void:
	var r := get_viewport_rect().size.y * 0.03
	var gap := r * 2.6
	for i in 3:
		var c := Vector2(cx + (float(i) - 1.0) * gap, cy)
		_draw_star(c, r, GOAL if i < stars else TEXT_DIM, i < stars)


func _rank_title(result: Dictionary) -> String:
	match int(result.stars):
		3:
			return "SMOOTH OPERATOR"
		2:
			return "GOT THE JOB DONE"
		_:
			return "PUBLICLY HUMILIATED" if not bool(result.never_detected) else "BY A HAIR"


# ----------------------------------------------------------- draw primitives
#
# _draw() has no blur, no gradients and no rounded shapes of its own, so the
# vector look is built from three things: StyleBoxFlat for rounded rects,
# per-vertex polygon colours for gradients, and stacked translucent passes for
# anything that wants to glow.

## A rounded rect. Deliberately allocates a FRESH StyleBoxFlat every call —
## draw commands can resolve a style box after _draw() returns, so reusing and
## mutating one would repaint every earlier rect with the last colour set.
func _rrect(rect: Rect2, col: Color, radius: int,
		border_col: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border_col
		sb.set_border_width_all(border_w)
	draw_style_box(sb, rect)


## Like _rrect, but with per-corner radii. The bowl needs a tight top and a deep
## round bottom to read as a basin instead of a bucket, and a single radius can't
## say that.
## (Spelled out rather than tl/tr/br/bl — "tr" shadows Object.tr().)
func _rrect_c(rect: Rect2, col: Color, top_l: int, top_r: int, bot_r: int, bot_l: int,
		border_col: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	# Set per corner: StyleBoxFlat has set_corner_radius_all() but no
	# set_corner_radius_individual() — the individual radii are plain properties.
	sb.corner_radius_top_left = top_l
	sb.corner_radius_top_right = top_r
	sb.corner_radius_bottom_right = bot_r
	sb.corner_radius_bottom_left = bot_l
	if border_w > 0:
		sb.border_color = border_col
		sb.set_border_width_all(border_w)
	draw_style_box(sb, rect)


## A vertical two-stop gradient, as a quad with per-vertex colours. Its corners
## are SHARP — inset it inside a rounded housing rather than using it as the
## outer shape of anything.
func _vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var pts := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


## One horizontal slice of the gauge track, in needle-space (0..1).
func _band(x: float, bw: float, bottom: float, gh: float, n_lo: float, n_hi: float,
		col: Color, radius: int = 8) -> void:
	var y_hi := bottom - n_hi * gh
	var y_lo := bottom - n_lo * gh
	_rrect(Rect2(x, y_hi, bw, y_lo - y_hi), col, radius)


func _draw_star(center: Vector2, radius: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	var inner := radius * 0.45
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rr := radius if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, 2.0)


func _meter_color(v: float) -> Color:
	var f := clampf(v / 100.0, 0.0, 1.0)
	if f < 0.5:
		return RED.lerp(AMBER, f / 0.5)
	return AMBER.lerp(FLOW, (f - 0.5) / 0.5)


func _text(font: Font, s: String, x: float, baseline: int, region_w: float, fs: int, col: Color) -> void:
	draw_string(font, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_CENTER, region_w, fs, col)
