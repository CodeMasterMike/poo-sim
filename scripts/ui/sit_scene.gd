class_name SitScene
extends RefCounted
## The room, the man, and the bowl — everything behind the HUD.
##
## This is register A of the style guide: flat fills, one shadow tone, thick ink
## outlines, no gradients. The instrument panel on top is register B, and the
## contrast between them is the joke. Keeping them in separate files is mostly so
## that stays true — it is easy to let a glossy meter treatment creep into the art
## when both live in one 1,400-line _draw().
##
## Draw order is load-bearing and reads back to front: he sits behind the bowl,
## the bowl is cut away across his lap so you can see in, then his forearms and
## hands come back over the front rim, and the stink rises off it all last.
##
## Pure view. It reads SimState and never writes it.

## The canvas to paint into, and the match seed — the pile's surface noise is a
## pure function of (sample index, seed), so a given seed always grows the same
## pile and a replay redraws it identically. Nothing here calls randf().
var _ci: CanvasItem
var _seed: int

# --- Bound for the duration of one draw() call. ---
#
# Passed as fields rather than threaded through fifteen signatures. The art code
# reads them constantly (the sitter's pose, the bowl's fill, the stream's
# consistency) and the alternative was every private helper carrying three
# parameters it only forwards. They are write-once per frame, by draw().
var state: SimState
var level: LevelDef
var frame: SitFrame

## The room's ground plane, as a fraction of screen height. Sits below both the
## gauge and the bowl so the whole scene stands on one floor. Everything under it
## is HUD apron: the prompt band and the footer readouts.
const FLOOR_Y := 0.735

## How many render samples the bowl's heightfield is drawn at, per simulated
## column. The sim settles 24 columns; drawing them raw reads as 24 visible
## steps, so the silhouette is resampled finer and roughened on top.
const PILE_SUBDIV: int = 3

# --- Colours: aliased from the locked Palette (docs/specs/poo-sim-style-guide.html)
#     so every screen draws from one source and can't drift. ---
const BG := Palette.BG
const PANEL := Palette.PANEL
const DEAD := Palette.DEAD
const NEEDLE := Palette.NEEDLE
const GOAL := Palette.GOAL
const MATTER := Palette.MATTER
const MATTER_DARK := Palette.MATTER_DARK
const WATER := Palette.WATER


func _init(canvas: CanvasItem, match_seed: int) -> void:
	_ci = canvas
	_seed = match_seed


## The whole scene, back to front.
func draw(sim_state: SimState, level_def: LevelDef, view: SitFrame, w: float, h: float) -> void:
	state = sim_state
	level = level_def
	frame = view
	_draw_backdrop(w, h)
	_draw_sitter(w, h)
	_draw_bowl(w, h)
	_draw_sitter_legs(w, h)
	_draw_stink(w, h)


## Him alone, for the loss screen — which redraws him ON TOP of its scrim, because
## behind an 0.80 wash of black the slump is invisible and the slump is the beat.
func draw_sitter(sim_state: SimState, view: SitFrame, w: float, h: float) -> void:
	state = sim_state
	frame = view
	_draw_sitter(w, h)


## The room behind the HUD: a vertical wash, a faked vignette, and a floor line.
## Oversized on every side so the splash/jolt shake can never reveal an edge.
func _draw_backdrop(w: float, h: float) -> void:
	var full := Rect2(-40, -40, w + 80, h + 80)
	VectorDraw.vgrad(_ci, full, BG.lightened(0.07), BG.darkened(0.30))

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
		_ci.draw_rect(frame, Color(0.0, 0.0, 0.0, 0.045 * fade * fade), false, bw)


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
		_ci.draw_line(Vector2(x, 0.0), Vector2(x, fy), grout, 1.0)
		x += tile
	var y := tile
	while y < fy:
		_ci.draw_line(Vector2(0.0, y), Vector2(w, y), grout, 1.0)
		y += tile

	# Floor, a touch darker than the wall, and the skirting line where they meet.
	_ci.draw_rect(Rect2(-40.0, fy, w + 80.0, h - fy + 40.0), BG.darkened(0.22))
	_ci.draw_line(Vector2(-40.0, fy), Vector2(w + 40.0, fy), Palette.BORDER.darkened(0.40), 3.0)


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
	var cx := scene_cx(w)
	var ink := BG.darkened(0.62)
	var iw := maxf(2.0, w * 0.005)          # §5: outlines are ~0.5% of screen width
	var cera := DEAD.lightened(0.28)
	var cera_sh := DEAD.lightened(0.02)
	var figure := PANEL.lightened(0.20)
	var figure_sh := PANEL.darkened(0.10)

	# Three poses, all view-only — read off the input buffer and the phase, never
	# fed back into the sim. Idle breathes; pushing hunches; losing slumps.
	var lost: bool = state != null and state.phase == SimState.Phase.LOST
	var bob := sin(frame.t * (0.9 if lost else 2.2)) * h * (0.002 if lost else 0.004)
	var strain := h * 0.022 if (frame.holding and not lost) else 0.0
	var slump := h * 0.030 if lost else 0.0

	# --- the toilet's back: cistern, then the neck that carries it down onto the
	# bowl. The neck is not decoration — without it the cistern and the bowl were
	# positioned independently and the tank floated with a screen-height's worth
	# of nothing between them. It runs behind his torso, which is where the back
	# of a toilet actually is, and overlaps the bowl's top edge so they join. ---
	VectorDraw.rrect(_ci, Rect2(cx - w * 0.100, h * 0.310, w * 0.20, h * 0.195), cera_sh, 6, ink, int(iw))
	VectorDraw.rrect(_ci, Rect2(cx - w * 0.135, h * 0.203, w * 0.27, h * 0.125), cera, 8, ink, int(iw))
	VectorDraw.rrect(_ci, Rect2(cx - w * 0.122, h * 0.286, w * 0.244, h * 0.034), cera_sh, 5)
	VectorDraw.rrect(_ci, Rect2(cx - w * 0.100, h * 0.222, w * 0.075, h * 0.018), cera_sh, 4)  # the flush plate

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
	VectorDraw.shade_limbs(_ci, limbs, ink, figure, figure_sh, iw)


## Knees and forearms, drawn AFTER the bowl so they come back over its front rim.
## Without them he reads as a torso sunk into a basin; the knees are what say
## "seated astride this thing".
func _draw_sitter_legs(w: float, h: float) -> void:
	var cx := scene_cx(w)
	var ink := BG.darkened(0.62)
	var iw := maxf(2.0, w * 0.005)
	var figure := PANEL.lightened(0.20)
	var lost: bool = state != null and state.phase == SimState.Phase.LOST
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
	VectorDraw.shade_limbs(_ci, limbs, ink, figure, PANEL.darkened(0.10), iw)


static func scene_cx(w: float) -> float:
	return w * 0.62


## The bowl's outer porcelain, and the cavity you can see into. Kept as two
## functions' worth of geometry in one place so the readout, the stink lines and
## the deposits can't drift out of register with the art.
static func bowl_rect(w: float, h: float) -> Rect2:
	var cx := scene_cx(w)
	return Rect2(cx - w * 0.245, h * 0.487, w * 0.49, h * 0.228)


static func bowl_cavity(w: float, h: float) -> Rect2:
	var cx := scene_cx(w)
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
	var outer := bowl_rect(w, h)
	var cav := bowl_cavity(w, h)

	# Tight at the rim, deeply round at the base — a basin, not a bucket.
	VectorDraw.rrect_corners(_ci, outer, cera, int(w * 0.045), int(w * 0.045), int(w * 0.20), int(w * 0.20),
			ink, int(iw))
	# The rim, as its own darker ring (§5: flat, 2-tone — no gradient).
	VectorDraw.rrect(_ci, Rect2(outer.position.x + w * 0.018, outer.position.y + h * 0.008,
			outer.size.x - w * 0.036, h * 0.020), cera_sh, int(h * 0.010))
	# The cavity: a hole, not a surface. Everything below is inside the bowl.
	VectorDraw.rrect_corners(_ci, cav, PANEL.darkened(0.52), int(w * 0.030), int(w * 0.030),
			int(w * 0.17), int(w * 0.17))

	# Water first, so anything that lands displaces it visually. It goes off as
	# the bowl fills — clean at the start, and by the end you would not put your
	# hand in it.
	var foul := clampf(state.relief / 100.0, 0.0, 1.0)
	var water := Rect2(cav.position.x + w * 0.012, cav.end.y - h * 0.052,
			cav.size.x - w * 0.024, h * 0.044)
	VectorDraw.rrect(_ci, water, WATER.lerp(MATTER_DARK, 0.75 * foul), int(h * 0.018))

	_draw_streaks(cav)
	_draw_pile(cav)
	_draw_stream(h, cav)

	# Splatter. The red zone costs Cleanliness, which the streaks above record
	# permanently; this is the moment it happens, thrown up onto the rim.
	if frame.splash_flash > 0.0:
		var spread := frame.splash_flash / 0.4
		for i in 9:
			var fx: float = outer.position.x + outer.size.x * (0.10 + 0.80 * _lump(i, 211))
			var fy: float = cav.position.y - h * 0.004 * _lump(i, 213) \
					- h * 0.030 * spread * _lump(i, 217)
			_ci.draw_circle(Vector2(fx, fy), maxf(1.5, w * 0.008 * _lump(i, 219)), MATTER)

	# THE LINE. Not decoration any more and not pinned to the rim: the run ends the
	# moment the pile touches this, so it is drawn at the level's own goal_height
	# and the player is watching a real finish line rather than a label.
	var line_y := cav.end.y - cav.size.y * level.goal_height
	var glow := GOAL
	glow.a = 0.20
	VectorDraw.rrect(_ci, Rect2(cav.position.x - w * 0.012, line_y - h * 0.008,
			cav.size.x + w * 0.024, h * 0.014), glow, 6)
	VectorDraw.rrect(_ci, Rect2(cav.position.x - w * 0.006, line_y - h * 0.004,
			cav.size.x + w * 0.012, h * 0.006), GOAL, 3)


## Skid marks down the porcelain. Cleanliness is the meter that already tracks
## how much you splashed, so the bowl simply wears it: the lower it drops, the
## more the walls show for it. No new state — the mess IS the score, drawn.
func _draw_streaks(cav: Rect2) -> void:
	var filth := clampf(1.0 - state.cleanliness / 100.0, 0.0, 1.0)
	var count := int(filth * 9.0)
	for i in count:
		var sx: float = cav.position.x + cav.size.x * (0.07 + 0.86 * _lump(i, 101))
		var sy: float = cav.position.y + cav.size.y * (0.04 + 0.30 * _lump(i, 103))
		var run: float = cav.size.y * (0.10 + 0.30 * _lump(i, 107))
		var rad: float = cav.size.x * (0.010 + 0.016 * _lump(i, 109))
		VectorDraw.limb(_ci, Vector2(sx, sy), Vector2(sx, sy + run), rad, MATTER_DARK)
		VectorDraw.limb(_ci, Vector2(sx, sy), Vector2(sx, sy + run * 0.55), rad * 0.45,
				MATTER_DARK.lerp(MATTER, 0.45))


## Read the sim's heightfield at a fractional position across the bowl (0..1),
## in rim-fractions. The pile is no longer the view's invention — this is a
## straight lookup into state.bowl.
func _sample_bowl(u: float) -> float:
	var cols := state.bowl.size()
	if cols == 0:
		return 0.0
	var p := clampf(u, 0.0, 1.0) * float(cols - 1)
	var i := clampi(int(floor(p)), 0, cols - 1)
	var a: float = state.bowl[i]
	if i + 1 >= cols:
		return a
	return lerpf(a, state.bowl[i + 1], p - float(i))


## The pile, drawn straight off the settled heightfield.
##
## This replaced a stack of fixed-cost layers, and the difference is the whole
## point of the change: the silhouette is now the *shape the matter settled into*.
## Runny slumps to a flat pool because the sim's angle of repose is near zero at
## low thickness; solid holds a steep mound under wherever you were aiming.
##
## Surface roughness is a pure function of (sample index, _seed) — NOTHING
## here calls randf(). _draw() re-runs every frame, so live noise would make the
## pile crawl and shimmer instead of sitting there, and a seeded replay has to
## redraw the identical pile.
func _draw_pile(cav: Rect2) -> void:
	var cols := state.bowl.size()
	if cols == 0:
		return
	# Sub-pixel traces are skipped, not clamped: a crest flattened onto the floor
	# line makes a zero-area polygon and draw_colored_polygon fails to triangulate.
	if state.bowl_peak() * cav.size.y < 1.5:
		return
	var samples := cols * PILE_SUBDIV
	var flash := frame.milestone_flash > 0.0

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
		var rough := (_lump(s, 401) - 0.5) * 0.10 * state.bowl_thickness \
				* minf(1.0, hgt * 5.0)
		xs.append(cav.position.x + cav.size.x * u)
		ys.append(minf(cav.end.y - cav.size.y * clampf(hgt + rough, 0.0, 1.10), cav.end.y))

	var body := MATTER_DARK
	var crust := MATTER
	if flash:
		var k := 0.30 * (frame.milestone_flash / 0.5)
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
		_ci.draw_colored_polygon(quad, body.lerp(crust, 0.10 + 0.09 * _lump(s, 419)))
		# The lit crust riding the surface.
		quad[2] = Vector2(x1, minf(y1 + lift, cav.end.y))
		quad[3] = Vector2(x0, minf(y0 + lift, cav.end.y))
		_ci.draw_colored_polygon(quad, crust)

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
		VectorDraw.limb(_ci, p - Vector2(run, 0.0), p + Vector2(run * 0.6, 0.0),
				maxf(1.0, lift * 0.22), Palette.MATTER_LIT)


## Is anything actually coming out right now?
##
## Shared by the falling stream and the consistency readout, so the label can never
## name a consistency the bowl isn't showing. Covers all three ways output stops:
## the needle resting below the push gate, a Knock freeze, and the stall after a
## splash.
static func is_flowing(state: SimState, level: LevelDef) -> bool:
	if state.phase != SimState.Phase.PLAYING:
		return false
	if Hazards.relief_stalled(state) or state.splash_stall > 0.0:
		return false
	return flow_volume(state, level) > 0.03


## Current output as a fraction of this level's hardest possible flow — the
## stream's width, and the test above.
static func flow_volume(state: SimState, level: LevelDef) -> float:
	var rate := PushSim.flow_rate(state, level) * PushSim.density_of(state.thickness, level)
	return clampf(rate / maxf(0.1, level.fill_red), 0.0, 1.3)


## What's actually coming out, falling to where the sim is depositing it.
##
## Thin, quick and near-straight when it's runny; a fat, slow, wavering rope when
## it's solid. Width tracks the live fill rate, so the stream is a direct readout
## of how fast you're filling — push harder and you can see it thicken.
func _draw_stream(h: float, cav: Rect2) -> void:
	if not is_flowing(state, level):
		return
	var vol := flow_volume(state, level)

	var thick := state.thickness
	# Asked of the sim, not recomputed here — the stream has to land on the column
	# it is actually feeding.
	var u := PushSim.drop_u(state, level)
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
		var pt := Vector2(x + sin(frame.t * speed + f * 5.5) * wave * f, lerpf(top, land, f))
		# Tapers slightly toward the landing — it's stretching as it falls.
		VectorDraw.limb(_ci, prev, pt, wid * (1.0 - 0.18 * f), MATTER)
		prev = pt
	VectorDraw.limb(_ci, Vector2(x, top), Vector2(x, top + (land - top) * 0.55), wid * 0.30,
			Palette.MATTER_LIT)

	# Where it lands. Runny spreads on impact; solid just plops.
	var splat := wid * (1.6 - 0.7 * thick)
	_ci.draw_circle(prev, splat, MATTER)
	if thick < 0.5:
		var spread := splat * (1.0 + 1.4 * (0.5 - thick))
		VectorDraw.limb(_ci, prev - Vector2(spread, 0.0), prev + Vector2(spread, 0.0),
				maxf(1.0, wid * 0.35), MATTER)


## Deterministic 0..1 noise from a layer index and a salt, mixed with the match
## seed so a different seed grows a different pile — but the SAME seed always
## grows the same one.
func _lump(i: int, salt: int) -> float:
	var x: int = i * 73856093 ^ _seed * 19349663 ^ salt * 83492791
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
	if state.phase != SimState.Phase.PLAYING:
		return
	var slot := Hazards.find(state, SimEvent.Kind.SMELL)
	if slot == null:
		return
	var arrived := slot.phase == HazardSlot.Phase.ACTIVE

	var bx := scene_cx(w)
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
			var wobble := sin(f * TAU * 1.5 + frame.t * speed + float(i) * 2.1) * w * 0.020 * f
			pts.append(Vector2(bx + ox + wobble, base + (tip - base) * f))
			# Fade out towards the tip: a squiggle that just stops looks cut off.
			var c := col
			c.a = peak * (1.0 - f) * (1.0 - f)
			cols.append(c)
		_ci.draw_polyline_colors(pts, cols, maxf(2.0, w * 0.006), true)

