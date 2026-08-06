class_name SitFrame
extends RefCounted
## The view's own transient state — everything that flashes, shakes or breathes.
##
## This is the counterpart to SimState, and the boundary between them is the
## project's third guardrail: the sim owns what HAPPENED, this owns how the screen
## is REACTING to it. Nothing here ever feeds back. Delete the whole file mid-run
## and the sit would play out identically; it would just look inert.
##
## It exists as its own object because that reaction is derived, not stored: the
## sim reports a splash by bumping a counter, and it is the EDGE on that counter
## that starts a flash. That edge detection needs somewhere to keep its trackers,
## and on the host they sat in a drift of eight loose fields that every renderer
## then had to be handed one at a time.
##
## Deliberately NOT part of SimState: a flash is not something a ghost replay or a
## mirrored board should carry, and putting it there would make the snapshot
## surface a lie.


## The view clock. Drives the sitter's breathing, the stream's waver and the stink
## squiggles — and the input layer times taps against it, which is why the host
## advances it even while an overlay has the sit paused.
var t: float = 0.0

## Whether the player is bearing down right now. The sitter hunches on it. Read off
## the input buffer, never off the sim, because it is a pose and not a rule.
var holding: bool = false

## Screen shake, in pixels. Applied as a draw transform over everything.
var shake: Vector2 = Vector2.ZERO

var splash_flash: float = 0.0     ## the red wash and "SPLASH!", 0.4s
var milestone_flash: float = 0.0  ## the pile blooming pale at each quarter, 0.5s
var knock_flash: float = 0.0      ## the pass/fail banner after a hazard, 0.8s
var knock_flash_good: bool = false

# --- Edge trackers. The sim publishes counters; these remember what we last saw,
#     so a flash fires once per event rather than every frame it is still true. ---
var _last_splash_pulse: int = 0
var _next_milestone: int = 25
var _last_hazard_pulse: int = 0

const SPLASH_TIME := 0.4
const MILESTONE_TIME := 0.5
const KNOCK_TIME := 0.8
## Peak shake for a splash, and the steady rattle while a Jolt is on you.
const SPLASH_SHAKE := 7.0
const JOLT_SHAKE := 5.0


## Clear every reaction. Called when a run restarts, so the new sit doesn't open
## mid-flash on the last one's splash. `t` deliberately survives — it is a clock,
## not a reaction, and the input layer is timing against it.
func reset() -> void:
	holding = false
	shake = Vector2.ZERO
	splash_flash = 0.0
	milestone_flash = 0.0
	knock_flash = 0.0
	knock_flash_good = false
	_last_splash_pulse = 0
	_next_milestone = 25
	_last_hazard_pulse = 0


## Read the model and react to it. Call AFTER the sim has stepped, so the edges are
## detected against the state the player is about to be shown.
##
## `t` is not advanced here — the host does that unconditionally, because an
## overlay pauses the sit but not the clock the input layer measures taps against.
func advance(state: SimState, delta: float, holding_now: bool) -> void:
	holding = holding_now

	if state.splash_pulse != _last_splash_pulse:
		_last_splash_pulse = state.splash_pulse
		splash_flash = SPLASH_TIME
	# A while, not an if: a single tick can cross more than one quarter.
	while state.progress >= float(_next_milestone) and _next_milestone < 100:
		milestone_flash = MILESTONE_TIME
		_next_milestone += 25

	splash_flash = maxf(0.0, splash_flash - delta)
	milestone_flash = maxf(0.0, milestone_flash - delta)

	var shake_mag := 0.0
	if splash_flash > 0.0:
		shake_mag = SPLASH_SHAKE * (splash_flash / SPLASH_TIME)
	# Turbulence keeps rattling the whole time it's on you.
	var jolt := Hazards.find(state, SimEvent.Kind.JOLT)
	if jolt != null and jolt.phase == HazardSlot.Phase.ACTIVE:
		shake_mag = maxf(shake_mag, JOLT_SHAKE)
	if shake_mag > 0.0:
		# The one place the view is ALLOWED a global randf(): shake is not simulated,
		# never reaches the model, and a seeded rattle would read as a pattern.
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_mag
	else:
		shake = Vector2.ZERO

	# Hazard resolution feedback — edge-detected off the model, purely visual.
	if state.hazard_resolve_pulse != _last_hazard_pulse:
		_last_hazard_pulse = state.hazard_resolve_pulse
		knock_flash = KNOCK_TIME
		knock_flash_good = not state.last_hazard_failed
	knock_flash = maxf(0.0, knock_flash - delta)
