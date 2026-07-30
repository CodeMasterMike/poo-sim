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
## Which level content to run. GREYBOX proves the machinery (the tuning-override
## path); CHURCH and RAVE are the two cover-window levels (full LevelDef factories,
## same system at opposite polarity). Switch at runtime with the 1 / 2 / 3 keys.
enum LevelKind { GREYBOX, CHURCH, RAVE }
@export var level_kind: LevelKind = LevelKind.GREYBOX

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


func _build_level() -> LevelDef:
	match level_kind:
		LevelKind.CHURCH:
			# A full factory: church tuning + its own cover-window timeline.
			return LevelChurch.build()
		LevelKind.RAVE:
			# The Church's inverse — covered by default, hushes expose you.
			return LevelRave.build()
		_:
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

	_draw_backdrop(w, h)

	# The venue name lives in the LEVEL button (top-left); keep the title clean.
	_text(font, "The Push", 0, int(h * 0.045), w, int(h * 0.026), TEXT)

	_draw_meters_top(font, w, h)
	_draw_quiet_status(font, w, h)
	_draw_gauge(font, w, h)
	_draw_relief(font, w, h)
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

	# Just enough floor to stop the HUD floating in a void. Two passes, the
	# bright one held off the screen edges so it reads as a floor, not a seam.
	var fy := h * 0.80
	draw_line(Vector2(0.0, fy), Vector2(w, fy), Color(0.16, 0.19, 0.25, 0.30), 2.0)
	draw_line(Vector2(w * 0.14, fy), Vector2(w * 0.86, fy), Color(0.20, 0.24, 0.31, 0.55), 2.0)


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


## An inset, rounded meter track with a lit fill and a gloss sliver — the shared
## look for Composure and the two pills. `col` still comes from _meter_color(),
## so the red→amber→green state language is untouched.
func _track(rect: Rect2, frac: float, col: Color) -> void:
	_rrect(rect, PANEL.darkened(0.22), int(rect.size.y * 0.5), Palette.BORDER, 2)
	var pad := 2.5
	var fw := (rect.size.x - pad * 2.0) * clampf(frac, 0.0, 1.0)
	if fw <= 1.0:
		return
	var fill := Rect2(rect.position.x + pad, rect.position.y + pad, fw, rect.size.y - pad * 2.0)
	var r := int(fill.size.y * 0.5)
	_rrect(fill, col.darkened(0.18), r)
	# Inset the gradient: _vgrad has sharp corners, so it has to stay clear of
	# the rounded fill's edges.
	var lit := fill.grow_individual(-r * 0.5, -1.5, -r * 0.5, -1.5)
	_vgrad(lit, col.lightened(0.18), col.darkened(0.10))
	_rrect(Rect2(fill.position.x + r * 0.5, fill.position.y + 1.5,
			maxf(0.0, fill.size.x - r), fill.size.y * 0.30), Color(1.0, 1.0, 1.0, 0.20), 3)


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
	_rrect(Rect2(w * 0.07, by + bh * 0.14, w * 0.86, bh * 0.22), Color(1.0, 1.0, 1.0, 0.16), 3)
	_text(font, label, 0, int(by + bh * 0.70), w, int(h * 0.020), Color(0.08, 0.07, 0.05))


func _draw_gauge(font: Font, w: float, h: float) -> void:
	var gx := w * 0.20
	var gw := w * 0.26
	var gy := h * 0.22
	var gh := h * 0.46
	var gbot := gy + gh
	var zone := PushSim.zone_of(_state)

	# Housing, then the recessed track. The track's own colour IS the dead zone;
	# the flow and red bands float on top of it.
	_rrect(Rect2(gx - 8, gy - 8, gw + 16, gh + 16), PANEL, 16, Palette.BORDER, 2)
	_rrect(Rect2(gx, gy, gw, gh), DEAD, 10)

	var highest := 0.0
	for band in _state.flow_bands:
		highest = maxf(highest, band.y)
		var inside: bool = _state.needle >= band.x and _state.needle <= band.y
		_lit_band(gx, gw, gbot, gh, band.x, band.y,
				FLOW if (zone == PushSim.ZONE_FLOW and inside) else FLOW_DIM)
	_lit_band(gx, gw, gbot, gh, highest, 1.0, RED if zone == PushSim.ZONE_RED else RED_DIM)

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

	var body := Rect2(gx - 4.0, ny - 8.0, gw + 8.0, 16.0)
	_rrect(body, NEEDLE, 8)
	# Highlight line along the top of the body, and a capped tip.
	_rrect(Rect2(body.position.x + 6.0, body.position.y + 2.5, body.size.x - 12.0, 4.0),
			Color(1.0, 1.0, 1.0, 0.9), 2)
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

	# The tube reads as glass: a dark recess, then the column of relief inside it.
	_rrect(Rect2(rx, gy, rw, gh), PANEL.darkened(0.35), 16, Palette.BORDER, 2)

	var fh := gh * (_state.relief / 100.0)
	var rcol := FLOW
	if _milestone_flash > 0.0:
		rcol = NEEDLE.lerp(FLOW, 1.0 - _milestone_flash / 0.5)
	var pad := 5.0
	var top_y := maxf(gy + pad, gbot - pad - fh)
	if gbot - pad - top_y > 1.0:
		var fill := Rect2(rx + pad, top_y, rw - pad * 2.0, gbot - pad - top_y)
		_rrect(fill, rcol.darkened(0.22), 12)
		# Gradient inset clear of the rounded corners (see _vgrad), then a gloss
		# band across the surface of the column.
		var lit := fill.grow_individual(-6.0, -5.0, -6.0, -5.0)
		_vgrad(lit, rcol.lightened(0.30), rcol.darkened(0.24))
		_rrect(Rect2(fill.position.x + 5.0, fill.position.y + 4.0,
				maxf(0.0, fill.size.x - 10.0), minf(8.0, fill.size.y * 0.10)),
				Color(1.0, 1.0, 1.0, 0.28), 4)

	# Goal marker — a gold capsule straddling the tube, with a faint halo.
	var goal_glow := GOAL
	goal_glow.a = 0.22
	_rrect(Rect2(rx - 12, gy - 6, rw + 24, 13), goal_glow, 6)
	_rrect(Rect2(rx - 8, gy - 2.5, rw + 16, 5), GOAL, 3)
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
	_rrect(Rect2(w * 0.11, by + bh * 0.12, w * 0.78, bh * 0.20), Color(1.0, 1.0, 1.0, 0.18), 4)
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
	var px := w * 0.075 + jiggle
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


## A gauge band with a top-lit gradient and a gloss sliver — the flow and red
## zones, which need to read as raised surfaces against the recessed track.
func _lit_band(x: float, bw: float, bottom: float, gh: float, n_lo: float, n_hi: float,
		col: Color) -> void:
	var y_hi := bottom - n_hi * gh
	var rect := Rect2(x, y_hi, bw, (bottom - n_lo * gh) - y_hi)
	if rect.size.y <= 0.0:
		return
	_rrect(rect, col, 8)
	var lit := rect.grow_individual(-5.0, -4.0, -5.0, -4.0)
	if lit.size.x <= 0.0 or lit.size.y <= 0.0:
		return
	_vgrad(lit, col.lightened(0.16), col.darkened(0.22))
	_rrect(Rect2(lit.position.x, lit.position.y, lit.size.x, minf(6.0, lit.size.y * 0.25)),
			Color(1.0, 1.0, 1.0, 0.16), 3)


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
