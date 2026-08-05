class_name PushSim
extends RefCounted
## The simulation tick. It owns ALL state mutation, so the order of changes (and
## therefore any RNG pulls) is auditable in one place — the thing determinism and
## fair 1v1 boards depend on. It is engine-pure: it mutates a SimState from a
## PlayerIntent + SimClock + a LevelDef's tuning, and holds NO Node references.
## That purity is what makes ghost replay and mirrored boards possible.
##
## Advance exactly one FIXED_DT per call. Never pass a partial/variable dt here —
## render-side smoothing belongs in the view and must never feed back (spec §17).

const ZONE_DEAD := 0
const ZONE_FLOW := 1
const ZONE_RED := 2

## Discretion must climb this far back above the detect threshold before another
## dip is counted — hysteresis so one sustained detection isn't counted twice.
const DETECT_RECOVER_MARGIN: float = 10.0


func tick(state: SimState, intent: PlayerIntent, clock: SimClock, level: LevelDef, dt: float) -> void:
	if state.phase != SimState.Phase.PLAYING:
		return

	# Flow bands ease toward their timeline target (smooth shift/narrow).
	_ramp_flow_bands(state, dt)

	# --- Needle physics (verbatim from the tuned prototype) ---
	var accel := level.push_accel if intent.holding else -level.gravity
	state.needle_vel += accel * dt
	state.needle_vel -= state.needle_vel * level.damping * dt
	state.needle_vel = clampf(state.needle_vel, -level.max_speed, level.max_speed)
	state.needle += state.needle_vel * dt
	if state.needle <= 0.0:
		state.needle = 0.0
		state.needle_vel = maxf(state.needle_vel, 0.0)
	elif state.needle >= 1.0:
		state.needle = 1.0
		state.needle_vel = minf(state.needle_vel, 0.0)

	var zone := PushSim.zone_of(state)

	# --- Active hazards tick here, before fill/drain — a freeze gates them below.
	#     Hazards owns the dispatch table, so hazard #2..#14 need no change here. ---
	if not state.hazards.is_empty():
		Hazards.tick(state, intent, level, clock, dt)
	var frozen := Hazards.relief_stalled(state)

	# --- Red-zone strain: camp the red and you eventually splash (paused mid-freeze) ---
	if not frozen:
		if zone == ZONE_RED:
			state.strain += dt / level.red_strain_time
			if state.strain >= 1.0:
				_splash(state, level)
		else:
			state.strain = maxf(0.0, state.strain - dt / level.red_strain_time)

	# --- Smell: pushing hard builds a charge that eventually emits a cloud. This
	#     is what makes the Smell Cloud a consequence of the greedy line rather
	#     than a scheduled tax — see SmellCloudHazard. ---
	if not frozen:
		if zone == ZONE_RED:
			state.smell_charge = minf(1.0, state.smell_charge + level.smell_charge_rate * dt)
		else:
			state.smell_charge = maxf(0.0, state.smell_charge - level.smell_decay_rate * dt)
		# One cloud at a time; the charge holds until the current one clears.
		if state.smell_charge >= 1.0 and Hazards.find(state, SimEvent.Kind.SMELL) == null:
			state.smell_charge = 0.0
			Hazards.start(state, SimEvent.Kind.SMELL, SimEvent.SmellPayload.new(
					level.smell_telegraph, level.smell_window, level.smell_cost), clock)

	# --- Consistency and aim. Both tracked whether or not anything is currently
	#     coming out, so a Knock freeze doesn't also freeze the log or the waver. ---
	_update_thickness(state, level, dt)
	_update_sway(state, level, dt)

	# --- Relief fill (frozen during a splash stall OR a Knock freeze) ---
	if not frozen:
		if state.splash_stall > 0.0:
			state.splash_stall = maxf(0.0, state.splash_stall - dt)
		else:
			# Relief is mass evacuated: how fast it's moving (the needle curve)
			# times how much of you each second of it is (the density).
			var rate := flow_rate(state, level) * density_of(state.thickness, level)
			var gained := minf(rate * dt, 100.0 - state.relief)
			state.relief += gained
			state.total_fill += gained
			if zone == ZONE_FLOW:
				state.flow_fill += gained
			_deposit(state, level, gained)

	# --- The bowl keeps settling even while the fill is frozen: a runny pool is
	#     still finding its level whether or not you're producing. ---
	_slump(state, level)

	# --- Done when the PILE REACHES THE LINE. Measured after the settle, so a
	#     heap that was going to slump doesn't win on a peak it can't hold. ---
	state.progress = maxf(state.progress,
			100.0 * state.bowl_peak() / maxf(0.001, level.goal_height))
	# A full mass counter also ends it. Not reachable in normal play — the pile is
	# at the rim long before then — but it stops a level whose goal_height sits
	# above what a bowlful of matter can stack into from being unwinnable.
	if state.progress >= 100.0 or state.relief >= 100.0:
		state.progress = 100.0
		state.phase = SimState.Phase.WON
		return

	# --- Composure: the Knock bleeds it while frozen; otherwise it drains by zone ---
	if not frozen:
		var base_drain := 100.0 / level.composure_seconds
		var drain := base_drain
		if zone == ZONE_DEAD:
			drain = base_drain * level.composure_drain_dead
		elif zone == ZONE_RED:
			drain = base_drain * level.composure_drain_red
		state.composure = maxf(0.0, state.composure - drain * dt)
	if state.composure <= 0.0:
		state.phase = SimState.Phase.LOST
		return

	# --- Discretion: noise while camping red + ambient smell over time ---
	var disc_loss := level.smell_rate * dt
	if zone == ZONE_RED:
		disc_loss += level.red_noise_rate * dt
	# Quiet-room silence penalty (Church + Rave): while the room is exposed, actively
	# bearing down above the silence cap is audible and bleeds Discretion. Gated on
	# `holding` (not just needle position) on purpose — acoustic windows telegraph
	# their start but not their end, so the needle coasting back down after you
	# RELEASE must be free, or you'd be punished for a fall you couldn't anticipate.
	# Gated on is_quiet_room() so every ordinary level is untouched.
	if level.is_quiet_room() and intent.holding \
			and state.needle > level.silence_push_cap and Hazards.room_exposed(state, level):
		disc_loss += level.silence_noise_rate * dt
	state.discretion = clampf(state.discretion - disc_loss, 0.0, 100.0)
	_track_detection(state, level)


## 0 = dead, 1 = flow, 2 = red. Generalized over any number of bands, so a split
## Flow Zone (two bands) works through the same function with no special-casing.
static func zone_of(state: SimState) -> int:
	if state.flow_bands.is_empty():
		return ZONE_DEAD
	for band in state.flow_bands:
		if state.needle >= band.x and state.needle <= band.y:
			return ZONE_FLOW
	return ZONE_RED if state.needle > state.band_span().y else ZONE_DEAD


## How fast matter is moving, as a CONTINUOUS function of the needle.
##
## This used to be a three-step lookup on the zone, which meant the needle's
## position inside the Flow band was worth nothing — sitting on the band's floor
## filled exactly as fast as riding its ceiling, so every clean run took the same
## time and the bowl art (which has always drawn a harder push as a fatter layer)
## was describing something the sim didn't do.
##
## The three anchors keep their exact meaning; only the space between them is
## interpolated. Set `fill_flow_spread` to 0 to get the old step function back.
##
## Everything below is then gated by `_push_gate`: with the needle on the floor
## you are not pushing, so nothing comes out at all.
static func flow_rate(state: SimState, level: LevelDef) -> float:
	return _curve_rate(state, level) * _push_gate(state.needle, level)


## Nothing moves unless you are actually bearing down.
##
## The dead zone used to still trickle at `fill_dead` all the way down to a needle
## resting on zero, which meant a sitter doing nothing at all was still producing —
## the same wrong read a Knock freeze exists to prevent, except permanent.
##
## Eased rather than switched: a hard cut would pop the stream on and off as the
## needle drifted across the threshold. At needle 0 it is exactly zero, which is
## the part that matters.
static func _push_gate(needle: float, level: LevelDef) -> float:
	if level.fill_cutoff <= 0.0:
		return 1.0
	return smoothstep(0.0, level.fill_cutoff, needle)


## The rate curve itself, ungated — what the anchors describe.
static func _curve_rate(state: SimState, level: LevelDef) -> float:
	if state.flow_bands.is_empty():
		return level.fill_dead
	var flow_lo := level.fill_flow * (1.0 - level.fill_flow_spread)
	var flow_hi := level.fill_flow * (1.0 + level.fill_flow_spread)
	var n := state.needle

	for band in state.flow_bands:
		if n >= band.x and n <= band.y:
			# Inside a band: floor pays flow_lo, ceiling pays flow_hi.
			return lerpf(flow_lo, flow_hi, inverse_lerp(band.x, band.y, n)) \
					if band.y > band.x else level.fill_flow

	var span := state.band_span()
	var lowest := span.x
	var highest := span.y
	if n > highest:
		# Above everything: ramp from the top band's ceiling up to the red anchor.
		return lerpf(flow_hi, level.fill_red, 0.0 if highest >= 1.0 \
				else inverse_lerp(highest, 1.0, n))
	if n < lowest:
		# Below everything: ramp from the dead anchor up to the lowest band's floor.
		return lerpf(level.fill_dead, flow_lo, 0.0 if lowest <= 0.0 else n / lowest)
	# In the gap of a SPLIT zone. zone_of() calls this dead, so it pays dead —
	# a notch between two bands has to be worth avoiding or the split is free.
	return level.fill_dead


## Thicker matter is denser, so more of you leaves per second. Centred on 0.5, so
## a level that seeds `thickness_base` at neutral fills at exactly the anchor
## rates and every existing pacing number (the 80s Composure, the 45-75s sit)
## holds without re-tuning.
static func density_of(thickness: float, level: LevelDef) -> float:
	return 1.0 + (thickness - 0.5) * 2.0 * level.density_swing


## The middle of the Flow band(s) — the reference "neutral push". Both consistency
## and the landing point are measured from here rather than from a fixed 0.5, so
## when the timeline shifts the band the whole model re-centres with it instead of
## quietly stranding the player on one side of it.
##
## THE definition of "the middle of the band", and now the only one. The Jolt's
## re-centre and the debug auto-player each carried their own, taking the midpoint
## of `flow_bands[0]` instead of the midpoint of the whole span. With one band
## those agree exactly, so no shipped level ever saw the difference — which is
## precisely why two of them could sit there unnoticed.
##
## Caveat for the first SPLIT level: the midpoint of the span falls in the GAP
## between two bands, which `_curve_rate` pays at the dead rate. That is fine as a
## reference point for consistency and sway, and wrong as a re-centre target — a
## split zone will want a "nearest point inside a band" alongside this, not
## instead of it.
static func band_centre(state: SimState) -> float:
	if state.flow_bands.is_empty():
		return 0.5
	var span := state.band_span()
	return (span.x + span.y) * 0.5


## Where the stream is landing, as a fraction across the bowl. Static and shared
## with the view, so the stream you see falling and the column it actually feeds
## cannot drift apart.
## (`_level` is unused today. It stays in the signature because where the stream
## lands is a level's business — an off-centre pan is on the environment backlog —
## and every caller already has one to hand.)
static func drop_u(state: SimState, _level: LevelDef) -> float:
	return clampf(0.5 + state.sway, 0.0, 1.0)


## Wander the landing point around the middle of the bowl.
##
## An earlier version mapped needle height straight onto lateral position, which
## meant pushing harder aimed you further across the bowl — wrong on its face, and
## it left half the bowl permanently clean while the other half built a spike.
## Force doesn't steer you; it makes you a less steady platform. So the stream
## hunts around the centre, and the amplitude — never the direction — is what
## responds to how hard you're bearing down and to whatever the room is doing.
##
## Two sines at an irrational frequency ratio, so the path never settles into a
## visible metronome. Pure function of accumulated sim time: no RNG, replays exact.
func _update_sway(state: SimState, level: LevelDef, dt: float) -> void:
	state.sway_clock += dt
	# 0 at the Flow band's centre, 1 at full lock — how hard you're bearing down.
	var centre := band_centre(state)
	var force := clampf((state.needle - centre) / maxf(0.05, 1.0 - centre), 0.0, 1.0)
	var amp := level.sway_ambient \
			+ level.sway_push * force \
			+ level.sway_turbulence * Hazards.turbulence(state)
	var t := state.sway_clock * level.sway_rate * TAU
	state.sway = amp * (sin(t) * 0.65 + sin(t * 1.618 + 1.7) * 0.35)


## Ease thickness toward what the current push implies.
func _update_thickness(state: SimState, level: LevelDef, dt: float) -> void:
	var target := clampf(level.thickness_base
			+ level.thickness_push_gain * (state.needle - band_centre(state)), 0.0, 1.0)
	state.thickness += (target - state.thickness) * clampf(level.thickness_ease * dt, 0.0, 1.0)


## Drop `gained` percent of Relief into the bowl, at the column the stream is
## currently landing on. Split across two columns so the landing point slides
## smoothly with the needle instead of snapping between buckets.
func _deposit(state: SimState, level: LevelDef, gained: float) -> void:
	var cols := state.bowl.size()
	if cols <= 0 or gained <= 0.0:
		return
	# 100% Relief fills the bowl to the rim, so one column-height is 100/cols percent.
	var units := gained * float(cols) / 100.0

	# The bowl takes on the consistency of what lands in it, weighted by mass. A
	# late dribble of runny can't re-grade a firm mound, and — the reason this is
	# tracked separately from `thickness` at all — the pile doesn't liquefy the
	# moment you let go and the exit goes runny.
	var held := state.bowl_mass()
	state.bowl_thickness = (state.bowl_thickness * held + state.thickness * units) \
			/ maxf(0.000001, held + units)

	var drop := drop_u(state, level) * float(cols - 1)
	var i := clampi(int(floor(drop)), 0, cols - 1)
	var f := drop - float(i)
	if i + 1 < cols:
		state.bowl[i] += units * (1.0 - f)
		state.bowl[i + 1] += units * f
	else:
		state.bowl[i] += units


## One relaxation sweep over the heightfield: neighbouring columns that differ by
## more than the material's angle of repose trade matter until they don't. Runny
## stuff has almost no repose and relaxes fast, so it finds its level and reads as
## a flat pool; solid stuff holds a steep face and stacks into a mound.
##
## This is a sandpile automaton, NOT Godot physics, and that is deliberate: a
## RigidBody pile is node-owned and not bit-reproducible, so putting one in the
## Relief path would cost ghost replay and mirrored 1v1 boards (spec §17). A flat
## float array reproduces exactly and snapshots for free.
##
## Transfers are accumulated against a snapshot and applied afterwards, so the
## result doesn't depend on which end of the bowl the loop happens to start at.
## Matter is only ever moved, never created — SimState.bowl_mass() is the guard.
func _slump(state: SimState, level: LevelDef) -> void:
	var cols := state.bowl.size()
	if cols < 2:
		return
	# Graded by what's IN the bowl, never by what's at the exit — see
	# SimState.bowl_thickness.
	var repose := lerpf(level.repose_runny, level.repose_solid, state.bowl_thickness)
	var relax := lerpf(level.slump_relax_runny, level.slump_relax_solid, state.bowl_thickness)
	var flux := PackedFloat32Array()
	flux.resize(cols)
	for i in cols - 1:
		var diff := state.bowl[i] - state.bowl[i + 1]
		var excess := absf(diff) - repose
		if excess <= 0.0:
			continue
		# Half the excess, eased — a full correction would ring instead of settle.
		var move := excess * 0.5 * relax
		if diff > 0.0:
			flux[i] -= move
			flux[i + 1] += move
		else:
			flux[i] += move
			flux[i + 1] -= move
	for i in cols:
		state.bowl[i] += flux[i]


func _ramp_flow_bands(state: SimState, dt: float) -> void:
	if state.flow_target_bands.is_empty():
		return
	# Can't lerp between differently-sized band sets (e.g. a 1→2 band split) — snap.
	if state.flow_bands.size() != state.flow_target_bands.size():
		state.flow_bands = state.flow_target_bands.duplicate()
		return
	var t := 1.0 if state.flow_ramp_rate <= 0.0 else clampf(state.flow_ramp_rate * dt, 0.0, 1.0)
	for i in state.flow_bands.size():
		state.flow_bands[i] = state.flow_bands[i].lerp(state.flow_target_bands[i], t)


func _splash(state: SimState, level: LevelDef) -> void:
	state.strain = 0.0
	state.splash_stall = level.splash_stall_time
	state.cleanliness = maxf(0.0, state.cleanliness - level.splash_cleanliness_hit)
	state.splash_pulse += 1


func _track_detection(state: SimState, level: LevelDef) -> void:
	if not state.detected_low and state.discretion < level.detect_threshold:
		state.detected_low = true
		state.detection_count += 1
	elif state.detected_low and state.discretion > level.detect_threshold + DETECT_RECOVER_MARGIN:
		state.detected_low = false
