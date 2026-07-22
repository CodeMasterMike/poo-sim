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
@export var tuning_override: LevelDef

## The per-match seed. Everything random — currently the jitter on when hazards
## fire — is rolled from this, so one seed always replays the same sit. Change it
## to reshuffle the schedule.
@export var match_seed: int = 1337

## Start with the debug auto-player attached (see scripts/debug/auto_player.gd).
## Toggle at runtime with B. Off in normal play.
@export var auto_play: bool = false

# --- Colors (grey-box palette, meter language from the UI spec) ---
const BG := Color(0.09, 0.10, 0.12)
const PANEL := Color(0.15, 0.17, 0.21)
const DEAD := Color(0.19, 0.23, 0.29)
const FLOW := Color(0.24, 0.82, 0.40)
const FLOW_DIM := Color(0.15, 0.42, 0.25)
const RED := Color(0.92, 0.30, 0.25)
const RED_DIM := Color(0.42, 0.19, 0.19)
const AMBER := Color(0.95, 0.75, 0.25)
const ORANGE := Color(0.98, 0.55, 0.15)
const NEEDLE := Color(0.98, 0.99, 1.0)
const TEXT := Color(0.92, 0.94, 0.98)
const TEXT_DIM := Color(0.58, 0.63, 0.71)
const GOAL := Color(0.96, 0.92, 0.42)

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
var _auto_hold: bool = false      ## set by the debug auto-player, if attached
var _auto_swipe: Vector2 = Vector2.ZERO
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


func _ready() -> void:
	_reset()
	if auto_play:
		_set_auto_play(true)


func _holding_now() -> bool:
	return _auto_hold or _mouse_down or _key_down or not _touches.is_empty()


## Read-only access to the model for debug tooling. The view itself only ever
## reads _state; nothing outside the sim may mutate it.
func sim_state() -> SimState:
	return _state


## Input hook for the debug auto-player — deliberately routed through the same
## intent path as a human hold, so a bot run is a real run.
func set_auto_hold(value: bool) -> void:
	_auto_hold = value


## Queue a swipe for the next simulation step, as a drag would. Debug-only.
func set_auto_swipe(value: Vector2) -> void:
	_auto_swipe = value


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
		if event.pressed:
			_tap_queued = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			_tap_queued = true
		else:
			_touches.erase(event.index)
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

	# When the run is over, any fresh press retries.
	if _state != null and _state.phase != SimState.Phase.PLAYING:
		var pressed_now: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed_now:
			_reset()


func _process(delta: float) -> void:
	_t += delta
	_advance_sim(delta)

	# View feedback, driven by (never driving) the model.
	if _state.splash_pulse != _last_splash_pulse:
		_last_splash_pulse = _state.splash_pulse
		_splash_flash = 0.4
	while _state.relief >= float(_next_milestone) and _next_milestone < 100:
		_milestone_flash = 0.5
		_next_milestone += 25

	_splash_flash = maxf(0.0, _splash_flash - delta)
	_milestone_flash = maxf(0.0, _milestone_flash - delta)
	if _splash_flash > 0.0:
		var mag := 7.0 * (_splash_flash / 0.4)
		_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mag
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
	intent.tap = _tap_queued
	intent.swipe = _swipe_queued + _auto_swipe
	_tap_queued = false
	_swipe_queued = Vector2.ZERO
	_auto_swipe = Vector2.ZERO
	return intent


func _build_level() -> LevelDef:
	# duplicate() so a shared .tres override is never mutated by the timeline.
	var level: LevelDef = tuning_override.duplicate() if tuning_override != null else LevelDef.new()
	level.timeline = LevelGreybox.timeline()
	return level


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

	# Background (oversized so shake never reveals an edge).
	draw_rect(Rect2(-40, -40, w + 80, h + 80), BG)

	_text(font, "The Push — prototype", 0, int(h * 0.045), w, int(h * 0.026), TEXT)

	_draw_meters_top(font, w, h)
	_draw_gauge(font, w, h)
	_draw_relief(font, w, h)
	_draw_smell(w, h)
	_draw_prompt(font, w, h)

	# Footer readouts.
	var fr := _state.flow_ratio()
	_text(font, "Flow %d%%   ·   %.1fs" % [int(round(fr * 100.0)), _clock.elapsed],
			0, int(h * 0.88), w, int(h * 0.022), TEXT_DIM)
	_text(font, "HOLD to push  ·  release to relax  ·  R restart  ·  B autoplay",
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


func _draw_meters_top(font: Font, w: float, h: float) -> void:
	var mx := w * 0.06
	var mw := w * 0.88

	# Composure — the master clock, full-width up top.
	_text(font, "COMPOSURE", mx, int(h * 0.072), mw, int(h * 0.016), TEXT_DIM)
	var cy := h * 0.082
	var ch := h * 0.024
	draw_rect(Rect2(mx, cy, mw, ch), PANEL)
	draw_rect(Rect2(mx, cy, mw * (_state.composure / 100.0), ch), _meter_color(_state.composure))
	draw_rect(Rect2(mx, cy, mw, ch), TEXT_DIM, false, 2.0)

	# Discretion + Cleanliness pills, side by side.
	var py := h * 0.125
	var ph := h * 0.022
	var pw := (mw - w * 0.03) * 0.5
	_pill(font, "DISCRETION", _state.discretion, mx, py, pw, ph, int(h * 0.015))
	_pill(font, "CLEANLINESS", _state.cleanliness, mx + pw + w * 0.03, py, pw, ph, int(h * 0.015))


func _pill(font: Font, label: String, value: float, x: float, y: float, pw: float, ph: float, fs: int) -> void:
	_text(font, "%s  %d" % [label, int(round(value))], x, int(y - h_gap()), pw, fs, TEXT_DIM)
	draw_rect(Rect2(x, y, pw, ph), PANEL)
	draw_rect(Rect2(x, y, pw * (value / 100.0), ph), _meter_color(value))
	draw_rect(Rect2(x, y, pw, ph), TEXT_DIM, false, 2.0)


func h_gap() -> float:
	return get_viewport_rect().size.y * 0.006


func _draw_gauge(font: Font, w: float, h: float) -> void:
	var gx := w * 0.20
	var gw := w * 0.26
	var gy := h * 0.22
	var gh := h * 0.46
	var gbot := gy + gh
	var zone := PushSim.zone_of(_state)

	draw_rect(Rect2(gx - 8, gy - 8, gw + 16, gh + 16), PANEL)
	# Whole track defaults to dead; bands and red paint over it.
	_band(gx, gw, gbot, gh, 0.0, 1.0, DEAD)

	var highest := 0.0
	for band in _state.flow_bands:
		highest = maxf(highest, band.y)
		var inside: bool = _state.needle >= band.x and _state.needle <= band.y
		_band(gx, gw, gbot, gh, band.x, band.y, FLOW if (zone == PushSim.ZONE_FLOW and inside) else FLOW_DIM)
	_band(gx, gw, gbot, gh, highest, 1.0, RED if zone == PushSim.ZONE_RED else RED_DIM)

	# In-flow glow — a soft reward for good placement.
	if zone == PushSim.ZONE_FLOW:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		for band in _state.flow_bands:
			if _state.needle >= band.x and _state.needle <= band.y:
				var glow := FLOW
				glow.a = 0.25 + 0.20 * pulse
				_band(gx - 10, gw + 20, gbot, gh, band.x, band.y, glow)

	# Needle.
	var ny := gbot - _state.needle * gh
	var zcol: Color = [TEXT_DIM, FLOW, RED][zone]
	var glow_col := zcol
	glow_col.a = 0.35
	draw_rect(Rect2(gx - gw * 0.16, ny - 14, gw * 1.32, 28), glow_col)
	draw_rect(Rect2(gx - gw * 0.08, ny - 6, gw * 1.16, 12), NEEDLE)

	# During a Knock freeze, frost the gauge and flip the demand to RELEASE (UI spec).
	if Hazards.relief_stalled(_state):
		draw_rect(Rect2(gx - 8, gy - 8, gw + 16, gh + 16), Color(0.55, 0.78, 0.98, 0.16))

	_text(font, "THE PUSH", gx - 8, int(gy - h * 0.018), gw + 16, int(h * 0.016), TEXT_DIM)
	var zname: String = ["DEAD ZONE", "FLOW", "RED ZONE"][zone]
	var zlabel_col := zcol
	if Hazards.relief_stalled(_state):
		zname = "RELEASE"
		zlabel_col = Color(0.72, 0.88, 1.0)
	_text(font, zname, gx - 8, int(gbot + h * 0.04), gw + 16, int(h * 0.024), zlabel_col)


func _draw_relief(font: Font, w: float, h: float) -> void:
	var gy := h * 0.22
	var gh := h * 0.46
	var gbot := gy + gh
	var rx := w * 0.64
	var rw := w * 0.16

	draw_rect(Rect2(rx, gy, rw, gh), PANEL.darkened(0.2))
	var fh := gh * (_state.relief / 100.0)
	var rcol := FLOW
	if _milestone_flash > 0.0:
		rcol = NEEDLE.lerp(FLOW, 1.0 - _milestone_flash / 0.5)
	draw_rect(Rect2(rx, gbot - fh, rw, fh), rcol)
	draw_rect(Rect2(rx, gy, rw, gh), TEXT_DIM, false, 2.0)
	draw_line(Vector2(rx - 6, gy), Vector2(rx + rw + 6, gy), GOAL, 3.0)  # goal line
	_text(font, "RELIEF", rx, int(gy - h * 0.018), rw, int(h * 0.016), TEXT_DIM)
	_text(font, "%d%%" % int(_state.relief), rx, int(gbot + h * 0.04), rw, int(h * 0.024), TEXT)


func _draw_prompt(font: Font, w: float, h: float) -> void:
	# Nothing in-flight matters once the run is over — the results own the screen.
	if _state.phase != SimState.Phase.PLAYING:
		return
	# A live hazard owns the prompt band; otherwise fall back to a scheduled prompt.
	var text := _hazard_banner()
	var col := ORANGE
	if not text.is_empty():
		col = AMBER
		var smell := Hazards.find(_state, SimEvent.Kind.SMELL)
		if Hazards.relief_stalled(_state) or (smell != null and smell.phase == HazardSlot.Phase.ACTIVE):
			col = RED
	elif not _scheduler.last_prompt.is_empty():
		text = _scheduler.last_prompt
	if text.is_empty():
		return
	var by := h * 0.74
	var bh := h * 0.05
	draw_rect(Rect2(w * 0.10, by, w * 0.80, bh), col)
	_text(font, text, 0, int(by + bh * 0.66), w, int(h * 0.026), Color(0.1, 0.08, 0.05))


## A live hazard owns the prompt band. The Knock wins ties — it takes your input
## away, so it's the more urgent read.
func _hazard_banner() -> String:
	var knock := Hazards.find(_state, SimEvent.Kind.KNOCK)
	if knock != null:
		match knock.phase:
			HazardSlot.Phase.TELEGRAPH:
				return "*knock knock*  —  GET READY TO STOP"
			HazardSlot.Phase.ACTIVE:
				return "HOLD STILL  —  RELEASE!"
	if Hazards.find(_state, SimEvent.Kind.SMELL) != null:
		return "SMELL CLOUD  —  SWIPE TO WAFT"
	return ""


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
		_text(font, "COULDN'T HOLD IT", 0, int(h * 0.40), w, int(h * 0.050), RED)
		_text(font, "Composure ran out.", 0, int(h * 0.47), w, int(h * 0.026), TEXT)
		_text(font, "tap  ·  press R to retry", 0, int(h * 0.55), w, int(h * 0.024), TEXT_DIM)
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


func _band(x: float, bw: float, bottom: float, gh: float, n_lo: float, n_hi: float, col: Color) -> void:
	var y_hi := bottom - n_hi * gh
	var y_lo := bottom - n_lo * gh
	draw_rect(Rect2(x, y_hi, bw, y_lo - y_hi), col)


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
