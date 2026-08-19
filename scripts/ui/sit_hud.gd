class_name SitHud
extends RefCounted
## The instrument panel — everything in front of the scene.
##
## Style guide register B: the earnest, precise gauges that the subject matter
## does not deserve, which is the joke. Register A (the room, the man, the bowl)
## is SitScene's, and the two are kept in separate files so the glossy treatment
## can't quietly creep into the art.
##
## Pillar 2 governs everything here: the meters win every contrast fight. If a
## readout and a piece of scenery ever compete, the readout wins.
##
## Pure view. It reads SimState and never writes it.

## The canvas to paint into, and the scene behind it — the loss screen composites
## the sitter back OVER its own scrim, because behind an 0.80 wash of black the
## slump is invisible and the slump is the whole beat.
var _ci: CanvasItem
var _scene: SitScene

# --- Bound for the duration of one draw() call; see SitScene for the reasoning. ---
var state: SimState
var level: LevelDef
var clock: SimClock
var scheduler: EventScheduler
var frame: SitFrame
var autoplay: bool = false

# --- Colours: aliased from the locked Palette (docs/specs/poo-sim-style-guide.html). ---
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

## What separates the items in the controls hint, on one line or two.
const SEP := "  ·  "


func _init(canvas: CanvasItem, scene: SitScene) -> void:
	_ci = canvas
	_scene = scene


## The whole panel, over the scene.
func draw(sim_state: SimState, level_def: LevelDef, sim_clock: SimClock,
		event_scheduler: EventScheduler, view: SitFrame, autoplay_on: bool,
		w: float, h: float) -> void:
	state = sim_state
	level = level_def
	clock = sim_clock
	scheduler = event_scheduler
	frame = view
	autoplay = autoplay_on
	var font := ThemeDB.fallback_font

	# The venue name lives in the LEVEL button (top-left); keep the title clean.
	VectorDraw.text(_ci, font, "The Push", 0, int(h * 0.045), w, VectorDraw.type_size(w, 0.026), TEXT)

	_draw_meters_top(font, w, h)
	_draw_quiet_status(font, w, h)
	_draw_gauge(font, w, h)
	_draw_relief_readout(font, w, h)
	_draw_smell(w, h)
	_draw_buzz(w, h)
	_draw_prompt(font, w, h)

	# Footer readouts.
	var fr := state.flow_ratio()
	VectorDraw.text(_ci, font, "Flow %d%%   ·   %.1fs" % [int(round(fr * 100.0)), clock.elapsed],
			0, int(h * 0.88), w, VectorDraw.type_size(w, 0.022), TEXT_DIM)
	_draw_controls_hint(font, w, h)
	if autoplay:
		VectorDraw.text(_ci, font, "· AUTOPLAY ·", 0, int(h * 0.85), w, VectorDraw.type_size(w, 0.020), GOAL)

	# Splash flash tint.
	if frame.splash_flash > 0.0:
		var tint := RED
		tint.a = 0.35 * (frame.splash_flash / 0.4)
		_ci.draw_rect(Rect2(-40, -40, w + 80, h + 80), tint)
		VectorDraw.text(_ci, font, "SPLASH!", 0, int(h * 0.44), w, VectorDraw.type_size(w, 0.045), NEEDLE)

	# Knock resolution banner (brief).
	if frame.knock_flash > 0.0:
		var kcol := FLOW if frame.knock_flash_good else RED
		var kt := kcol
		kt.a = 0.22 * (frame.knock_flash / 0.8)
		_ci.draw_rect(Rect2(-40, -40, w + 80, h + 80), kt)
		var ktxt := "STAYED QUIET" if frame.knock_flash_good else "THEY HEARD YOU!"
		VectorDraw.text(_ci, font, ktxt, 0, int(h * 0.40), w, VectorDraw.type_size(w, 0.040), kcol)

	_draw_overlay(font, w, h)


func _draw_meters_top(font: Font, w: float, h: float) -> void:
	var mx := w * 0.06
	var mw := w * 0.88

	# Composure — the master clock, full-width up top.
	VectorDraw.text(_ci, font, "COMPOSURE", mx, int(h * 0.072), mw, VectorDraw.type_size(w, 0.016), TEXT_DIM)
	var cy := h * 0.082
	var ch := h * 0.024
	_track(Rect2(mx, cy, mw, ch), state.composure / 100.0, _meter_color(state.composure))

	# Discretion + Cleanliness pills, side by side.
	var py := h * 0.125
	var ph := h * 0.022
	var pw := (mw - w * 0.03) * 0.5
	_pill(font, "DISCRETION", state.discretion, mx, py, pw, ph, VectorDraw.type_size(w, 0.015))
	_pill(font, "CLEANLINESS", state.cleanliness, mx + pw + w * 0.03, py, pw, ph, VectorDraw.type_size(w, 0.015))


func _pill(font: Font, label: String, value: float, x: float, y: float, pw: float, ph: float, fs: int) -> void:
	VectorDraw.text(_ci, font, "%s  %d" % [label, int(round(value))], x, int(y - h_gap()), pw, fs, TEXT_DIM)
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
	VectorDraw.rrect(_ci, rect, PANEL.darkened(0.22), int(rect.size.y * 0.5), Palette.BORDER, 2)
	var pad := 2.5
	var fw := (rect.size.x - pad * 2.0) * clampf(frac, 0.0, 1.0)
	if fw <= 1.0:
		return
	var fill := Rect2(rect.position.x + pad, rect.position.y + pad, fw, rect.size.y - pad * 2.0)
	VectorDraw.rrect(_ci, fill, col, int(fill.size.y * 0.5))


func h_gap() -> float:
	return _ci.get_viewport_rect().size.y * 0.006


## The core read of a quiet-room level: is it safe to push right now, and is a
## soundscape change coming? Polarity-aware — the Church waits for cover, the Rave
## dreads the hush — but the three states (heads-up / danger / safe) are shared.
## Drawn only in a quiet room; ordinary levels never show it.
func _draw_quiet_status(font: Font, w: float, h: float) -> void:
	if not level.is_quiet_room() or state.phase != SimState.Phase.PLAYING:
		return
	var exposed := Hazards.room_exposed(state, level)
	var slot := Hazards.find(state, SimEvent.Kind.COVER)
	var incoming: bool = slot != null and slot.phase == HazardSlot.Phase.TELEGRAPH
	var church := level.baseline_exposed

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
	VectorDraw.rrect(_ci, Rect2(w * 0.06, by, w * 0.88, bh), bar, int(bh * 0.34))
	VectorDraw.text(_ci, font, label, 0, int(by + bh * 0.70), w, VectorDraw.type_size(w, 0.020), Color(0.08, 0.07, 0.05))


## THE PUSH now hugs the left edge: the bowl and the man own the rest of the
## screen, and the gauge only ever needs to be read for the needle's HEIGHT, so
## it loses width cheaply.
func _draw_gauge(font: Font, w: float, h: float) -> void:
	var gx := w * 0.05
	var gw := w * 0.16
	var gy := h * 0.22
	var gh := h * 0.46
	var gbot := gy + gh
	var zone := PushSim.zone_of(state)

	# Housing, then the recessed track. The track's own colour IS the dead zone;
	# the flow and red bands float on top of it.
	VectorDraw.rrect(_ci, Rect2(gx - 8, gy - 8, gw + 16, gh + 16), PANEL, 16, Palette.BORDER, 2)
	VectorDraw.rrect(_ci, Rect2(gx, gy, gw, gh), DEAD, 10)

	# Flat bands. They were gradient-and-gloss "raised surfaces"; §5 says that
	# treatment is juice, not structure, and the zones are pure structure.
	var highest := 0.0
	for band in state.flow_bands:
		highest = maxf(highest, band.y)
		var inside: bool = state.needle >= band.x and state.needle <= band.y
		VectorDraw.band(_ci, gx, gw, gbot, gh, band.x, band.y,
				FLOW if (zone == PushSim.ZONE_FLOW and inside) else FLOW_DIM)
	VectorDraw.band(_ci, gx, gw, gbot, gh, highest, 1.0, RED if zone == PushSim.ZONE_RED else RED_DIM)

	# In-flow glow — a soft reward for good placement.
	if zone == PushSim.ZONE_FLOW:
		var pulse := 0.5 + 0.5 * sin(frame.t * 6.0)
		for band in state.flow_bands:
			if state.needle >= band.x and state.needle <= band.y:
				# Two haloes: draw calls have no blur, so a wide-faint plus a
				# tight-brighter pass fakes the falloff.
				var outer := FLOW
				outer.a = (0.10 + 0.09 * pulse)
				VectorDraw.band(_ci, gx - 6, gw + 12, gbot, gh, band.x - 0.014, band.y + 0.014, outer, 14)
				var inner := FLOW
				inner.a = (0.14 + 0.12 * pulse)
				VectorDraw.band(_ci, gx - 3, gw + 6, gbot, gh, band.x - 0.006, band.y + 0.006, inner, 11)

	# Needle — the one pure-white mark on the screen, haloed in its zone colour.
	var ny := gbot - state.needle * gh
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
		VectorDraw.rrect(_ci, Rect2(gx - spread, ny - hh * 0.5, gw + spread * 2.0, hh), halo, int(hh * 0.5))

	# Flat white bar and a capped tip. The halo above stays — a glow around the
	# needle is exactly the "juice" §5 permits; the highlight line that used to
	# run along the bar was emboss, and went.
	var body := Rect2(gx - 4.0, ny - 8.0, gw + 8.0, 16.0)
	VectorDraw.rrect(_ci, body, NEEDLE, 8)
	var tip := Vector2(gx + gw - 8.0, ny)
	_ci.draw_circle(tip, 11.0, NEEDLE)
	_ci.draw_arc(tip, 11.0, 0.0, TAU, 28, zcol, 2.5, true)

	# Quiet room, currently exposed: everything above the silence cap is audible —
	# mark that region so the player sees exactly how low they must ride it out.
	if level.is_quiet_room() and Hazards.room_exposed(state, level):
		var y_cap := gbot - level.silence_push_cap * gh
		var warn := RED
		warn.a = 0.14
		VectorDraw.rrect(_ci, Rect2(gx, gy, gw, y_cap - gy), warn, 10)
		_ci.draw_line(Vector2(gx, y_cap), Vector2(gx + gw, y_cap), RED, 2.0)

	# During a Knock freeze, frost the gauge and flip the demand to RELEASE (UI spec).
	if Hazards.relief_stalled(state):
		VectorDraw.rrect(_ci, Rect2(gx - 8, gy - 8, gw + 16, gh + 16), Color(0.55, 0.78, 0.98, 0.16), 16)

	VectorDraw.text(_ci, font, "THE PUSH", gx - 8, int(gy - h * 0.018), gw + 16, VectorDraw.type_size(w, 0.016), TEXT_DIM)
	# The zone name is a claim about what is happening RIGHT NOW, so it goes quiet
	# once the run is over — a frozen gauge still reading "FLOW" under the results
	# scrim says the run is live when it isn't. The gauge itself stays, as a
	# record of where the needle ended up; only the claim goes.
	if state.phase != SimState.Phase.PLAYING:
		return
	var zname: String = ["DEAD ZONE", "FLOW", "RED ZONE"][zone]
	var zlabel_col := zcol
	if Hazards.relief_stalled(state):
		zname = "RELEASE"
		zlabel_col = Color(0.72, 0.88, 1.0)
	# The zone name gets a WIDER region than the gauge itself. At this column
	# width "DEAD ZONE" clips to "DEAD Z"; the strip to the gauge's right is empty
	# down here, so the label can centre on the gauge and overhang it.
	VectorDraw.text(_ci, font, zname, 0, int(gbot + h * 0.04), w * 0.26, VectorDraw.type_size(w, 0.024), zlabel_col)


## Relief lost its abstract green tube — the bowl IS the meter now, so all that's
## left is the precise readout. A pile is a great feel and a poor number, and the
## win condition is an exact 100%, so the digits stay.
func _draw_relief_readout(font: Font, w: float, h: float) -> void:
	# Once the run is over the results screen owns every number, and this one sits
	# exactly where the win screen puts "tap · press R to retry".
	if state.phase != SimState.Phase.PLAYING:
		return
	var cav := SitScene.bowl_cavity(w, h)
	# Consistency rides alongside the percentage. It changes the fill rate, so it
	# can't be a thing you only infer from the shape of the pile — but it's a feel,
	# not a number, so it gets a word rather than a second percentage.
	# Wider than the cavity, and shifted back by half the excess so it stays
	# centred on the bowl — the cavity's own width clips the longer words.
	var pad := w * 0.14
	# Shows PROGRESS, not the mass counter: the bowl is the Relief meter, and what
	# the meter has to answer is "how close am I to done", which is now the pile's
	# height against the goal line. `state.relief` is still the mass that left you
	# and still drives Flow Ratio — it just isn't the finish line any more.
	var line := "RELIEF  %d%%" % int(state.progress)
	var word := _readout_consistency()
	if not word.is_empty():
		line += "   ·   " + word
	# The region has to hold the longest line this readout can PRODUCE, not the
	# one on screen when it was tuned. A cavity-plus-padding box fits
	# "RELIEF  9%" and loses the end of the longer consistency words — STEADY
	# rendered as "STE". So measure the line and widen to it when it asks for
	# more, keeping the box centred on the bowl either way.
	var fs := VectorDraw.type_size(w, 0.024)
	var need := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x + w * 0.04
	var region := maxf(cav.size.x + pad, need)
	VectorDraw.text(_ci, font, line, cav.get_center().x - region * 0.5, int(h * 0.727), region,
			fs, TEXT)


## Which consistency the readout names.
##
## While something is coming out, it describes THAT. When nothing is — needle on
## the floor, a Knock freeze, a splash stall — naming the exit is describing output
## that isn't happening, and it reads as a contradiction next to a bowl full of
## firm matter. So it falls back to what's in the bowl, the only consistency that
## still means anything at rest.
##
## Empty and not flowing (the opening seconds) names nothing at all: `bowl_thickness`
## is undefined until the first deposit, so any word there would be invented.
func _readout_consistency() -> String:
	if SitScene.is_flowing(state, level):
		return _consistency_word(state.thickness)
	if state.bowl_mass() > 0.0:
		return _consistency_word(state.bowl_thickness)
	return ""


func _consistency_word(t: float) -> String:
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
	if state.phase != SimState.Phase.PLAYING:
		return
	# A live hazard owns the prompt band; otherwise fall back to a scheduled prompt.
	var text := _hazard_banner()
	var col := ORANGE
	if not text.is_empty():
		col = AMBER
		# Red once a hazard is actually on you, amber while it's still telegraphing.
		for kind in [SimEvent.Kind.SMELL, SimEvent.Kind.JOLT, SimEvent.Kind.BUZZ]:
			var s := Hazards.find(state, kind)
			if s != null and s.phase == HazardSlot.Phase.ACTIVE:
				col = RED
		if Hazards.relief_stalled(state):
			col = RED
	elif not scheduler.last_prompt.is_empty():
		text = scheduler.last_prompt
	if text.is_empty():
		return
	var by := h * 0.74
	var bh := h * 0.05
	VectorDraw.rrect(_ci, Rect2(w * 0.10, by, w * 0.80, bh), col, int(bh * 0.30))
	VectorDraw.text(_ci, font, text, 0, int(by + bh * 0.66), w, VectorDraw.type_size(w, 0.026), Color(0.1, 0.08, 0.05))


## A live hazard owns the prompt band. The Knock wins ties — it takes your input
## away, so it's the more urgent read.
func _hazard_banner() -> String:
	var knock := Hazards.find(state, SimEvent.Kind.KNOCK)
	if knock != null:
		match knock.phase:
			HazardSlot.Phase.TELEGRAPH:
				return "*knock*  —  GET READY"
			HazardSlot.Phase.ACTIVE:
				return "HOLD STILL  —  RELEASE!"
	var jolt := Hazards.find(state, SimEvent.Kind.JOLT)
	if jolt != null:
		return "SWIPE TO RE-CENTER" if jolt.phase == HazardSlot.Phase.ACTIVE \
				else "*rumble*  —  BRACE"
	if Hazards.find(state, SimEvent.Kind.BUZZ) != null:
		return "BZZT  —  TAP TO DISMISS"
	if Hazards.find(state, SimEvent.Kind.SMELL) != null:
		return "SMELL  —  SWIPE TO WAFT"
	return ""


## The phone, buzzing away in your pocket — jittering faster once it's ringing out.
func _draw_buzz(w: float, h: float) -> void:
	if state.phase != SimState.Phase.PLAYING:
		return
	var slot := Hazards.find(state, SimEvent.Kind.BUZZ)
	if slot == null:
		return
	var ringing := slot.phase == HazardSlot.Phase.ACTIVE
	var jiggle := sin(frame.t * 42.0) * (3.0 if ringing else 1.2)
	var pw := w * 0.055
	var ph := h * 0.048
	# In the channel between the gauge (now hard left) and the bowl, so it sits on
	# neither.
	var px := w * 0.245 + jiggle
	var py := h * 0.30
	_ci.draw_rect(Rect2(px, py, pw, ph), ORANGE if ringing else AMBER)
	_ci.draw_rect(Rect2(px + pw * 0.14, py + ph * 0.10, pw * 0.72, ph * 0.64), Color(0.12, 0.12, 0.14))


## The cloud itself: drifting and faint while incoming, close and solid once it's
## on you. Drawn from the model, so it can't disagree with the hazard state.
func _draw_smell(w: float, h: float) -> void:
	if state.phase != SimState.Phase.PLAYING:
		return
	var slot := Hazards.find(state, SimEvent.Kind.SMELL)
	if slot == null:
		return
	var arrived := slot.phase == HazardSlot.Phase.ACTIVE
	var col := Color(0.55, 0.66, 0.24, 0.55 if arrived else 0.28)
	var r := w * (0.13 if arrived else 0.10)
	var cx := w * 0.5 + sin(frame.t * 1.6) * w * (0.02 if arrived else 0.06)
	var cy := h * 0.168
	_ci.draw_circle(Vector2(cx, cy), r, col)
	_ci.draw_circle(Vector2(cx - r * 0.75, cy + r * 0.18), r * 0.72, col)
	_ci.draw_circle(Vector2(cx + r * 0.75, cy + r * 0.12), r * 0.78, col)


func _draw_overlay(font: Font, w: float, h: float) -> void:
	if state.phase == SimState.Phase.PLAYING:
		return

	_ci.draw_rect(Rect2(-40, -40, w + 80, h + 80), Color(0.03, 0.04, 0.05, 0.80))

	if state.phase == SimState.Phase.LOST:
		# Re-draw him ON TOP of the scrim. He is the fail state, and behind an
		# 0.80 wash of black the slump is invisible — the beat is worth more than
		# the dimming. The text lands over him and still reads: he is a flat dark
		# silhouette, which is exactly what text wants behind it.
		_scene.draw_sitter(state, frame, w, h)
		VectorDraw.text(_ci, font, "COULDN'T HOLD IT", 0, int(h * 0.40), w, VectorDraw.type_size(w, 0.050), RED)
		VectorDraw.text(_ci, font, "Composure ran out.", 0, int(h * 0.47), w, VectorDraw.type_size(w, 0.026), TEXT)
		# Below his feet, not across his head — the slump is the picture here.
		VectorDraw.text(_ci, font, "tap  ·  press R to retry", 0, int(h * 0.76), w, VectorDraw.type_size(w, 0.024), TEXT_DIM)
		return

	# WON — score from the four meters.
	var result := Scoring.evaluate(state, level)
	_draw_stars(w * 0.5, h * 0.28, int(result.stars))
	VectorDraw.text(_ci, font, _rank_title(result), 0, int(h * 0.36), w, VectorDraw.type_size(w, 0.040), GOAL)

	var bd: Dictionary = result["breakdown"]
	var y := 0.44
	# Bracket keys (not bd.clear — that resolves to Dictionary.clear()).
	_score_line(font, w, h, y, "Clear", int(bd["clear"])); y += 0.045
	_score_line(font, w, h, y, "Discretion", int(bd["discretion"])); y += 0.045
	_score_line(font, w, h, y, "Cleanliness", int(bd["cleanliness"])); y += 0.045
	_score_line(font, w, h, y, "Flow", int(bd["flow"])); y += 0.045
	_score_line(font, w, h, y, "Speed", int(bd["speed"])); y += 0.055
	VectorDraw.text(_ci, font, "SCORE  %d" % int(result["base"]), 0, int(h * y), w, VectorDraw.type_size(w, 0.034), TEXT)
	VectorDraw.text(_ci, font, "tap  ·  press R to retry", 0, int(h * (y + 0.06)), w, VectorDraw.type_size(w, 0.024), TEXT_DIM)


func _score_line(font: Font, w: float, h: float, y: float, label: String, pts: int) -> void:
	VectorDraw.text(_ci, font, "%s" % label, w * 0.16, int(h * y), w * 0.40, VectorDraw.type_size(w, 0.024), TEXT_DIM)
	VectorDraw.text(_ci, font, "%d" % pts, w * 0.56, int(h * y), w * 0.24, VectorDraw.type_size(w, 0.024), TEXT)


func _draw_stars(cx: float, cy: float, stars: int) -> void:
	var r := _ci.get_viewport_rect().size.y * 0.03
	var gap := r * 2.6
	for i in 3:
		var c := Vector2(cx + (float(i) - 1.0) * gap, cy)
		VectorDraw.star(_ci, c, r, GOAL if i < stars else TEXT_DIM, i < stars)


func _rank_title(result: Dictionary) -> String:
	match int(result.stars):
		3:
			return "SMOOTH OPERATOR"
		2:
			return "GOT THE JOB DONE"
		_:
			return "PUBLICLY HUMILIATED" if not bool(result.never_detected) else "BY A HAIR"


# The drawing primitives moved to VectorDraw (scripts/ui/vector_draw.gd) — they
# are the idiom the whole game paints in, not this screen's business.
#
# The meter ramp stays: it isn't a primitive, it's the state language from the
# style guide (red below half, through amber, to green) and it means nothing
# outside a meter.

## The one-line controls strip along the bottom.
##
## The venue-key span is DERIVED from the roster rather than written out. It read
## "1/2/3 level" as a literal, which was one of six places a level had to be
## registered — and a hint promising three keys on a screen offering five is worse
## than no hint, because a player trusts it. A single-venue roster drops the span
## entirely instead of advertising a key that selects what is already playing.
func _controls_parts() -> Array[String]:
	var parts: Array[String] = ["HOLD push", "release relax", "R restart"]
	var slots := LevelCatalog.key_slots()
	if slots > 1:
		parts.append("1-%d level" % slots)
	parts.append_array(["H manual", "B autoplay"])
	return parts


## The hint wraps rather than shrinks. Six items joined is wider than 1080 at any
## size this footer can be read at, so it ran off both edges — the first and last
## hints, HOLD and autoplay, were the ones lost. Splitting is measured rather than
## hardcoded because the item count is level-dependent: a one-venue build drops
## the "1-3 level" entry and fits on a single line, and should use it.
func _draw_controls_hint(font: Font, w: float, h: float) -> void:
	var fs := VectorDraw.type_size(w, 0.018)
	var parts := _controls_parts()
	var joined := SEP.join(parts)
	if font.get_string_size(joined, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x <= w * 0.96:
		VectorDraw.text(_ci, font, joined, 0, int(h * 0.93), w, fs, TEXT_DIM)
		return
	var half := int(ceil(parts.size() / 2.0))
	VectorDraw.text(_ci, font, SEP.join(parts.slice(0, half)), 0, int(h * 0.917), w, fs, TEXT_DIM)
	VectorDraw.text(_ci, font, SEP.join(parts.slice(half)), 0, int(h * 0.952), w, fs, TEXT_DIM)


func _meter_color(v: float) -> Color:
	var f := clampf(v / 100.0, 0.0, 1.0)
	if f < 0.5:
		return RED.lerp(AMBER, f / 0.5)
	return AMBER.lerp(FLOW, (f - 0.5) / 0.5)
