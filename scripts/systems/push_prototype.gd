extends Control
## Grey-box prototype of "The Push" (roadmap step 1).
##
## Hold ANYWHERE to raise the needle; release to let it fall. Keep the needle in
## the green Flow Zone to fill Relief cleanly. Camp the red zone and it fills
## faster — but you'll eventually splash and stall. Fill Relief to 100% to win.
## Tap or press R to retry.
##
## The whole point of this prototype is feel, so every value that shapes it is
## exported below — tweak it live in the remote inspector and replay. No art,
## no audio, no hazards: just the question "is hold-and-release to fill fun?"

# --- Feel tuning (safe to tweak live while running) ---
@export_group("Needle physics")
@export var push_accel: float = 2.2      ## upward accel while holding (gauge units/s^2)
@export var gravity: float = 1.6         ## downward accel while released
@export var damping: float = 3.0         ## velocity damping — higher settles faster
@export var max_speed: float = 1.5       ## needle speed clamp (gauge units/s)

@export_group("Flow zone (0 = bottom, 1 = top)")
@export var flow_low: float = 0.50
@export var flow_high: float = 0.72

@export_group("Relief fill (% per second)")
@export var fill_dead: float = 4.0
@export var fill_flow: float = 14.0
@export var fill_red: float = 22.0

@export_group("Red-zone risk")
@export var red_strain_time: float = 1.5   ## seconds camping red before a splash fires
@export var splash_stall_time: float = 0.5 ## seconds Relief is frozen after a splash

# --- Colors (grey-box palette, meter language from the UI spec) ---
const BG := Color(0.09, 0.10, 0.12)
const PANEL := Color(0.15, 0.17, 0.21)
const DEAD := Color(0.19, 0.23, 0.29)
const FLOW := Color(0.24, 0.82, 0.40)
const FLOW_DIM := Color(0.15, 0.42, 0.25)
const RED := Color(0.92, 0.30, 0.25)
const RED_DIM := Color(0.42, 0.19, 0.19)
const NEEDLE := Color(0.98, 0.99, 1.0)
const TEXT := Color(0.92, 0.94, 0.98)
const TEXT_DIM := Color(0.58, 0.63, 0.71)
const GOAL := Color(0.96, 0.92, 0.42)

# --- State ---
enum State { PLAYING, WON }
var state: State = State.PLAYING

var needle: float = 0.0       # 0 = bottom, 1 = top
var needle_vel: float = 0.0
var relief: float = 0.0       # 0..100, the win condition

var elapsed: float = 0.0
var flow_fill: float = 0.0    # Relief earned inside the Flow Zone
var total_fill: float = 0.0   # total Relief earned (for the Flow Ratio)

var strain: float = 0.0       # 0..1, builds while camping red
var splash_stall: float = 0.0 # Relief frozen while > 0
var splash_flash: float = 0.0 # visual flash timer
var shake: Vector2 = Vector2.ZERO
var milestone_flash: float = 0.0
var _next_milestone: int = 25

var _t: float = 0.0           # animation clock

# --- Input pointers (hold-anywhere: mouse, touch, or space) ---
var _mouse_down: bool = false
var _key_down: bool = false
var _touches: Dictionary = {}
var holding: bool:
	get:
		return _mouse_down or _key_down or not _touches.is_empty()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
		else:
			_touches.erase(event.index)
	elif event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			_key_down = event.pressed
		elif event.keycode == KEY_R and event.pressed:
			_reset()

	# When won, any press retries.
	if state == State.WON:
		var pressed_now: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed_now:
			_reset()


func _process(delta: float) -> void:
	_t += delta
	if state == State.PLAYING:
		_update_play(delta)

	splash_flash = maxf(0.0, splash_flash - delta)
	milestone_flash = maxf(0.0, milestone_flash - delta)
	if splash_flash > 0.0:
		var mag := 7.0 * (splash_flash / 0.4)
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mag
	else:
		shake = Vector2.ZERO
	queue_redraw()


func _update_play(delta: float) -> void:
	elapsed += delta

	# Needle physics: hold pushes up, gravity pulls down, damping steadies it.
	var accel := push_accel if holding else -gravity
	needle_vel += accel * delta
	needle_vel -= needle_vel * damping * delta
	needle_vel = clampf(needle_vel, -max_speed, max_speed)
	needle += needle_vel * delta
	if needle <= 0.0:
		needle = 0.0
		needle_vel = maxf(needle_vel, 0.0)
	elif needle >= 1.0:
		needle = 1.0
		needle_vel = minf(needle_vel, 0.0)

	var zone := _zone()

	# Red-zone strain: camp the red and you eventually splash.
	if zone == 2:
		strain += delta / red_strain_time
		if strain >= 1.0:
			_splash()
	else:
		strain = maxf(0.0, strain - delta / red_strain_time)

	# Relief fill (frozen during a splash stall — that's the mess cost).
	if splash_stall > 0.0:
		splash_stall = maxf(0.0, splash_stall - delta)
	else:
		var rate := fill_dead
		if zone == 1:
			rate = fill_flow
		elif zone == 2:
			rate = fill_red
		var gained := rate * delta
		relief = minf(100.0, relief + gained)
		total_fill += gained
		if zone == 1:
			flow_fill += gained
		if relief >= float(_next_milestone) and _next_milestone < 100:
			milestone_flash = 0.5
			_next_milestone += 25
		if relief >= 100.0:
			state = State.WON


func _zone() -> int:
	# 0 = dead, 1 = flow, 2 = red
	if needle < flow_low:
		return 0
	if needle <= flow_high:
		return 1
	return 2


func _splash() -> void:
	strain = 0.0
	splash_stall = splash_stall_time
	splash_flash = 0.4


func _flow_ratio() -> float:
	return 0.0 if total_fill <= 0.0 else flow_fill / total_fill


func _grade(fr: float) -> String:
	if fr >= 0.90:
		return "S"
	if fr >= 0.75:
		return "A"
	if fr >= 0.55:
		return "B"
	return "C"


func _reset() -> void:
	state = State.PLAYING
	needle = 0.0
	needle_vel = 0.0
	relief = 0.0
	elapsed = 0.0
	flow_fill = 0.0
	total_fill = 0.0
	strain = 0.0
	splash_stall = 0.0
	splash_flash = 0.0
	milestone_flash = 0.0
	_next_milestone = 25


# ------------------------------------------------------------------ rendering

func _draw() -> void:
	var vp := get_viewport_rect().size
	var w := vp.x
	var h := vp.y
	var font := ThemeDB.fallback_font
	draw_set_transform(shake, 0.0, Vector2.ONE)

	# Background (oversized so shake never reveals an edge).
	draw_rect(Rect2(-40, -40, w + 80, h + 80), BG)

	# --- Force gauge ---
	var gx := w * 0.22
	var gw := w * 0.28
	var gy := h * 0.15
	var gh := h * 0.62
	var gbot := gy + gh
	var zone := _zone()

	draw_rect(Rect2(gx - 8, gy - 8, gw + 16, gh + 16), PANEL)
	_band(gx, gw, gbot, gh, 0.0, flow_low, DEAD)
	_band(gx, gw, gbot, gh, flow_low, flow_high, FLOW if zone == 1 else FLOW_DIM)
	_band(gx, gw, gbot, gh, flow_high, 1.0, RED if zone == 2 else RED_DIM)

	# In-flow glow — a soft reward for good placement.
	if zone == 1:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		var glow := FLOW
		glow.a = 0.25 + 0.20 * pulse
		_band(gx - 10, gw + 20, gbot, gh, flow_low, flow_high, glow)

	# Needle.
	var ny := gbot - needle * gh
	var zcol: Color = [TEXT_DIM, FLOW, RED][zone]
	var glow_col := zcol
	glow_col.a = 0.35
	draw_rect(Rect2(gx - gw * 0.16, ny - 14, gw * 1.32, 28), glow_col)
	draw_rect(Rect2(gx - gw * 0.08, ny - 6, gw * 1.16, 12), NEEDLE)

	# Gauge label + live zone name.
	_text(font, "THE PUSH", gx - 8, gy - 22, gw + 16, int(h * 0.020), TEXT_DIM)
	var zname: String = ["DEAD ZONE", "FLOW", "RED ZONE"][zone]
	_text(font, zname, gx - 8, gbot + int(h * 0.05), gw + 16, int(h * 0.028), zcol)

	# --- Relief meter ---
	var rx := w * 0.62
	var rw := w * 0.16
	draw_rect(Rect2(rx, gy, rw, gh), PANEL.darkened(0.2))
	var fh := gh * (relief / 100.0)
	var rcol := FLOW
	if milestone_flash > 0.0:
		rcol = NEEDLE.lerp(FLOW, 1.0 - milestone_flash / 0.5)
	draw_rect(Rect2(rx, gbot - fh, rw, fh), rcol)
	draw_rect(Rect2(rx, gy, rw, gh), TEXT_DIM, false, 2.0)
	draw_line(Vector2(rx - 6, gy), Vector2(rx + rw + 6, gy), GOAL, 3.0)  # goal line
	_text(font, "RELIEF", rx, gy - 22, rw, int(h * 0.020), TEXT_DIM)
	_text(font, "%d%%" % int(relief), rx, gbot + int(h * 0.05), rw, int(h * 0.028), TEXT)

	# --- Header + hint ---
	_text(font, "The Push — prototype", 0, int(h * 0.07), w, int(h * 0.026), TEXT)
	var fr := _flow_ratio()
	_text(font, "Flow %d%%   ·   %.1fs" % [int(round(fr * 100.0)), elapsed],
			0, int(h * 0.87), w, int(h * 0.024), TEXT_DIM)
	_text(font, "HOLD anywhere to push   ·   release to relax   ·   R restart",
			0, int(h * 0.92), w, int(h * 0.019), TEXT_DIM)

	# Splash flash tint.
	if splash_flash > 0.0:
		var tint := RED
		tint.a = 0.35 * (splash_flash / 0.4)
		draw_rect(Rect2(-40, -40, w + 80, h + 80), tint)
		_text(font, "SPLASH!", 0, int(h * 0.45), w, int(h * 0.045), NEEDLE)

	# --- Results overlay ---
	if state == State.WON:
		draw_rect(Rect2(-40, -40, w + 80, h + 80), Color(0.03, 0.04, 0.05, 0.78))
		_text(font, "COMPLETE", 0, int(h * 0.34), w, int(h * 0.055), FLOW)
		_text(font, "Time   %.1fs" % elapsed, 0, int(h * 0.44), w, int(h * 0.030), TEXT)
		_text(font, "Flow   %d%%" % int(round(fr * 100.0)), 0, int(h * 0.49), w, int(h * 0.030), TEXT)
		var g := _grade(fr)
		_text(font, "Grade  %s" % g, 0, int(h * 0.55), w, int(h * 0.050), GOAL)
		_text(font, "tap  ·  press R to retry", 0, int(h * 0.64), w, int(h * 0.024), TEXT_DIM)


func _band(x: float, bw: float, bottom: float, gh: float, n_lo: float, n_hi: float, col: Color) -> void:
	var y_hi := bottom - n_hi * gh
	var y_lo := bottom - n_lo * gh
	draw_rect(Rect2(x, y_hi, bw, y_lo - y_hi), col)


func _text(font: Font, s: String, x: float, baseline: float, region_w: float, fs: int, col: Color) -> void:
	draw_string(font, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_CENTER, region_w, fs, col)
