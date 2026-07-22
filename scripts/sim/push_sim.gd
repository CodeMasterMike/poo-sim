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


func tick(state: SimState, intent: PlayerIntent, _clock: SimClock, level: LevelDef, dt: float) -> void:
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

	# --- Red-zone strain: camp the red and you eventually splash ---
	if zone == ZONE_RED:
		state.strain += dt / level.red_strain_time
		if state.strain >= 1.0:
			_splash(state, level)
	else:
		state.strain = maxf(0.0, state.strain - dt / level.red_strain_time)

	# --- Relief fill (frozen during a splash stall — the mess cost) ---
	if state.splash_stall > 0.0:
		state.splash_stall = maxf(0.0, state.splash_stall - dt)
	else:
		var rate := level.fill_dead
		if zone == ZONE_FLOW:
			rate = level.fill_flow
		elif zone == ZONE_RED:
			rate = level.fill_red
		var gained := rate * dt
		state.relief = minf(100.0, state.relief + gained)
		state.total_fill += gained
		if zone == ZONE_FLOW:
			state.flow_fill += gained
		if state.relief >= 100.0:
			state.phase = SimState.Phase.WON
			return

	# --- Composure: always draining, faster off the flow band ---
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
	state.discretion = clampf(state.discretion - disc_loss, 0.0, 100.0)
	_track_detection(state, level)


## 0 = dead, 1 = flow, 2 = red. Generalized over any number of bands, so a split
## Flow Zone (two bands) works through the same function with no special-casing.
static func zone_of(state: SimState) -> int:
	if state.flow_bands.is_empty():
		return ZONE_DEAD
	var highest := state.flow_bands[0].y
	for band in state.flow_bands:
		if state.needle >= band.x and state.needle <= band.y:
			return ZONE_FLOW
		highest = maxf(highest, band.y)
	return ZONE_RED if state.needle > highest else ZONE_DEAD


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
