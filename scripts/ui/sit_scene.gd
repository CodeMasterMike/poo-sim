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
##
## It came up from 0.735 when the toilet grew a pedestal. The bowl used to hover
## with h*0.02 of nothing under it; now the foot lands ON this line, so the line
## is what the toilet stands on rather than a stripe behind it. 0.700 is as low
## as it can go — the Relief readout's caps reach h*0.703.
const FLOOR_Y := 0.700

# --- The toilet, in one block --------------------------------------------
#
# Every part of it is positioned off every other part, and scattering these
# across four draw functions is exactly how the cistern ended up floating a
# screen's worth of nothing above the bowl the first time round.

## The seat: an ellipse, because we are looking slightly DOWN at it. It is the
## widest thing in the scene — wider than his hips, wider than the body under it
## — and that overhang is most of what says "toilet" instead of "bucket". The
## bowl was a rounded rect before, square-shouldered and the same width top to
## bottom, and it read as a laundry basket.
const SEAT_CY := 0.494    ## the seat's centre line (h) — level with his hips
const SEAT_RX := 0.255    ## outer half-width (w)
const SEAT_RY := 0.046    ## how steep the angle we're looking from is (h)
const SEAT_LIP := 0.014   ## its thickness, seen from above (h)

## The opening — also the mouth of the cavity, so HOLE_RX sets the meter's width.
## The seat's band is the gap between this and SEAT_RX/SEAT_RY.
##
## Deliberately NARROW. The first attempt kept the old bowl's width here and the
## result was a grey frame around a black rectangle: the hole was 0.384w across
## inside a 0.464w body, so the porcelain came to h*0.04 a side and read as an
## outline rather than as ceramic with mass. It looked like a wheelie bin. The
## hole is the one measurement to be stingy with — everything else on the fixture
## is only legible in the space it leaves.
const HOLE_RX := 0.136    ## (w)
const HOLE_RY := 0.024    ## (h)

## Where the cavity floor sits (h). Below it is solid porcelain and then the
## pedestal, which needs the rest of the drop to FLOOR_Y to say "stem" — hence
## the cavity giving up h*0.034 against the old bowl.
const BOWL_BASE := 0.650

## How wide the throat is at the cavity's floor, as a fraction of its mouth. A
## bowl narrows toward the trap, and saying so is most of what stops the cavity
## reading as a slot cut in a grey box: straight sides and a flat top gave the
## whole fixture away as a rectangle with a lid.
const THROAT_PINCH := 0.72

## The body's half-width (in w) at each step of the fall from SEAT_CY to
## FLOOR_Y. A toilet is not a cone: it hangs almost straight under the seat's
## overhang, tucks in hard over the last quarter, and kicks back out into a foot
## where it meets the floor.
##
## The near-vertical top three quarters are also load-bearing, not styling. The
## contents are drawn in `bowl_cavity()`'s rect — a straight-sided frame — so the
## porcelain has to stay wider than HOLE_RX for the cavity's whole depth or the
## pile draws itself outside the silhouette. The pinch is only allowed to start
## below BOWL_BASE, which is where the cavity has already ended.
const BODY_PROFILE := [
	Vector2(0.00, 0.198),
	Vector2(0.30, 0.190),
	Vector2(0.55, 0.176),
	Vector2(0.76, 0.158),   # BOWL_BASE lands here — still clear of HOLE_RX
	Vector2(0.87, 0.134),
	Vector2(0.95, 0.110),
	Vector2(1.00, 0.124),   # the foot, kicking back out where it meets the floor
]

## How many render samples the bowl's heightfield is drawn at, per simulated
## column. The sim settles 24 columns; drawing them raw reads as 24 visible
## steps, so the silhouette is resampled finer and roughened on top.
const PILE_SUBDIV: int = 3

## How many rows of lumps deep the pile is drawn. Row 0 is the crest and each row
## below sits a lump deeper and darker; the count is worked out from how tall the
## cavity is and clamped to this, because everything past it is buried behind the
## rows in front of it and only costs draw calls.
const PILE_LUMP_ROW_CAP: int = 14

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
##
## `bowl_rect` is the whole fixture's footprint — seat overhang included, down to
## the floor. Only the splatter reads it, for the span to throw drops across.
static func bowl_rect(w: float, h: float) -> Rect2:
	var cx := scene_cx(w)
	var top := h * (SEAT_CY - SEAT_RY)
	return Rect2(cx - w * SEAT_RX, top, w * SEAT_RX * 2.0, h * FLOOR_Y - top)


## The cavity: the throat you see down, and the frame everything inside the bowl
## is positioned in — the water, the skid marks, the pile, the goal line, and the
## HUD's Relief readout under it.
##
## Its mouth IS the seat's opening, so it starts at the opening's widest line and
## is the opening's width; the ellipse's own upper half caps it off above, and
## the front of the seat is cut away over it. That cutaway is why the seat reads
## as an open-front one — which is a real seat, and the honest way to keep a
## front-on bowl legible as a fill meter.
static func bowl_cavity(w: float, h: float) -> Rect2:
	var cx := scene_cx(w)
	return Rect2(cx - w * HOLE_RX, h * SEAT_CY, w * HOLE_RX * 2.0, h * (BOWL_BASE - SEAT_CY))


## The throat's half-width at a fraction of the way down the cavity.
static func _throat_hw(w: float, t: float) -> float:
	return w * HOLE_RX * lerpf(1.0, THROAT_PINCH, pow(clampf(t, 0.0, 1.0), 1.35))


## The body's half-width at a fraction of the fall from the seat to the floor.
## Straight lines between the BODY_PROFILE steps read as a faceted cone, so the
## bracketing pair is smoothstepped instead.
static func _body_hw(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	for i in BODY_PROFILE.size() - 1:
		var a: Vector2 = BODY_PROFILE[i]
		var b: Vector2 = BODY_PROFILE[i + 1]
		if u <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, u))
	var last: Vector2 = BODY_PROFILE[BODY_PROFILE.size() - 1]
	return last.y


## The body's outer silhouette as one closed polygon, so the fill and the ink
## come off the same points and can never disagree by a pixel.
static func _body_outline(w: float, h: float, steps: int = 28) -> PackedVector2Array:
	var cx := scene_cx(w)
	var top := h * SEAT_CY
	var span := h * FLOOR_Y - top
	var right := PackedVector2Array()
	var left := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var hw := w * _body_hw(t)
		var y := top + span * t
		right.append(Vector2(cx + hw, y))
		left.append(Vector2(cx - hw, y))
	left.reverse()
	return right + left


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
	var cx := scene_cx(w)
	var hole := PANEL.darkened(0.52)
	var outer := bowl_rect(w, h)
	var cav := bowl_cavity(w, h)

	# The shadow where it meets the floor. Without it the pedestal stands on the
	# floor LINE rather than on the floor, and the fixture reads as a sticker laid
	# over the room instead of a thing in it.
	VectorDraw.ellipse(_ci, Vector2(cx, h * FLOOR_Y), w * 0.150, h * 0.013,
			Color(0.0, 0.0, 0.0, 0.30))

	# The porcelain body: hangs almost straight under the seat's overhang, tucks
	# in over the last quarter, kicks back out into a foot. See BODY_PROFILE.
	VectorDraw.inked(_ci, _body_outline(w, h), cera, ink, iw)

	# The seat, in three passes: its edge, offset DOWN so its thickness shows from
	# this angle; its top surface; and the opening punched through both.
	#
	# The top surface gets a THIRD porcelain tone, and it has to. The first cut
	# gave the seat the body's own fill and leaned on the overhang and the ink to
	# separate them — and they can't. Identical fills merge whatever is drawn
	# between them, and an ink line w*0.005 wide describes an edge, not a plane.
	# The seat simply vanished into the bowl. This is the one up-facing surface on
	# the fixture, so it is the one that catches the light.
	var cera_lit := DEAD.lightened(0.50)
	var seat := Vector2(cx, h * SEAT_CY)
	VectorDraw.ellipse(_ci, seat + Vector2(0.0, h * SEAT_LIP), w * SEAT_RX, h * SEAT_RY,
			cera_sh, ink, iw)
	VectorDraw.ellipse(_ci, seat, w * SEAT_RX, h * SEAT_RY, cera_lit, ink, iw)

	# The hinges. Two lugs at the back, bridging the seat to the cistern's neck —
	# a cheap detail that buys a lot, because a hinge is a thing only a toilet
	# seat has. Set out at w*0.095 so they clear his torso (w*0.072) and still sit
	# inside the neck (w*0.100); dead centre they would simply be behind him.
	for side in [-1.0, 1.0]:
		VectorDraw.rrect(_ci, Rect2(cx + side * w * 0.095 - w * 0.017,
				h * (SEAT_CY - SEAT_RY * 0.95), w * 0.034, h * 0.030),
				cera_sh, int(w * 0.010), ink, int(iw))

	VectorDraw.ellipse(_ci, seat, w * HOLE_RX, h * HOLE_RY, hole, ink, iw)

	# The cavity: a hole, not a surface. Everything below is inside the bowl. It
	# hangs off the opening's widest line so the two merge into one throat, and it
	# covers the seat's front band on the way — that erasure IS the cutaway.
	#
	# Barely rounded at the base: the throat walls below do the shaping now, and a
	# deep radius here fought them for the same corner.
	VectorDraw.rrect_corners(_ci, cav, hole, 0, 0, int(w * 0.05), int(w * 0.05))

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
	_draw_chunks(h, cav)
	_draw_throat_walls(w, h, cav, cera_sh, ink, iw)

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
	#
	# A HOOP, not a bar. Its height is honest — still `goal_height` off the
	# cavity floor — but its shape is now the shape a level actually has in a bowl
	# you look down into, sized to the throat at its own depth and squashed by the
	# same perspective ratio as the seat. As a straight rect it spanned the full
	# mouth, and at the default goal_height of 1.0 that put a bright yellow bar
	# clean across the seat: the fixture read as a bin with the lid shut.
	var line_y := cav.end.y - cav.size.y * level.goal_height
	var line_hw := _throat_hw(w, clampf(1.0 - level.goal_height, 0.0, 1.0))
	var line_ry := line_hw * (h * SEAT_RY) / (w * SEAT_RX)
	var glow := GOAL
	glow.a = 0.20
	var at := Vector2(cx, line_y)
	VectorDraw.ellipse_ring(_ci, at, line_hw, line_ry, glow, maxf(6.0, h * 0.012))
	VectorDraw.ellipse_ring(_ci, at, line_hw, line_ry, GOAL, maxf(2.0, h * 0.004))


## The bowl's inner walls, drawn back OVER the contents.
##
## The pile, the water and the skid marks are all laid out in `bowl_cavity()`'s
## straight-sided rect, because a heightfield of vertical strips is what the sim
## settles and re-projecting it into a tapering throat every frame would buy the
## picture nothing the eye can read. So the taper is applied afterwards, as
## porcelain: these two wedges cover the strip between the rect's edge and the
## throat's, which both clips the contents back into the throat AND is the inner
## wall. They only work because BODY_PROFILE never narrows past HOLE_RX above
## BOWL_BASE — the wedge is always laid over porcelain, never over the room.
##
## The wall takes the shadow tone: it is the unlit side of a curved surface.
func _draw_throat_walls(w: float, h: float, cav: Rect2, cera_sh: Color,
		ink: Color, iw: float) -> void:
	var cx := scene_cx(w)
	var steps := 18
	for side in [-1.0, 1.0]:
		var edge := PackedVector2Array()
		for i in steps + 1:
			var t := float(i) / float(steps)
			edge.append(Vector2(cx + side * _throat_hw(w, t), cav.position.y + cav.size.y * t))
		var wedge := edge.duplicate()
		# Back up the rect's own edge, so the wedge always closes on porcelain.
		wedge.append(Vector2(cx + side * w * HOLE_RX, cav.end.y))
		wedge.append(Vector2(cx + side * w * HOLE_RX, cav.position.y))
		VectorDraw.inked(_ci, wedge, cera_sh)
		# Ink the INNER edge only. Outlining the wedge would run a second line
		# down its outer edge, where it abuts the body — which reads as a crack
		# in the porcelain rather than as the lip of the throat.
		_ci.draw_polyline(edge, ink, iw, true)


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

	# The chunky surface, if what's in the bowl is firm enough to have one. Drawn
	# ON TOP of the trapezoids rather than instead of them: the strips are the
	# opaque mass (the heightfield, honestly), the lumps are what that mass is made
	# of. Without the strips underneath, every gap between lumps would be a hole
	# straight through to the porcelain.
	var chunky := _pile_chunkiness()
	if chunky > 0.02:
		_draw_pile_lumps(cav, chunky, crust, body)

	# Wet sheen. The one thing that separates "fresh" from "a brown shape", and
	# the reason the product gets a third tone — a recorded exception to §5, see
	# the style guide. Scattered along the crest, never on every sample: an even
	# stripe of highlight reads as flaky pastry rather than something wet.
	#
	# It thins out as the surface goes chunky, because by then each lump is
	# carrying its own highlight and the two together read as glazed.
	for s in samples + 1:
		if _lump(s, 409) <= lerpf(0.62, 0.94, chunky):
			continue
		if ys[s] >= cav.end.y - cav.size.y * 0.04:
			continue
		var p := Vector2(xs[s], ys[s] + lift * 0.45)
		var run := cav.size.x / float(samples) * (0.7 + 0.9 * _lump(s, 411))
		VectorDraw.limb(_ci, p - Vector2(run, 0.0), p + Vector2(run * 0.6, 0.0),
				maxf(1.0, lift * 0.22), Palette.MATTER_LIT)


## How chunky the pile's surface reads, 0..1.
##
## Graded off `bowl_thickness`, never off `thickness` — the same rule the settle
## and the drawn roughness already follow. A mound of lumps must not smooth over
## because the exit went runny when you let go.
func _pile_chunkiness() -> float:
	if level == null or level.chunk_mass <= 0.0:
		return 0.0
	return smoothstep(level.chunk_thickness_floor, 0.95, state.bowl_thickness)


## The lumps the pile is made of, laid along its crest.
##
## Two rows, drawn bottom up. Each lump is a dark disc with a lighter one on top of


## One lump of matter, as a flat tilted oval.
##
## SKIPPED rather than clamped when it comes out sub-pixel, and that guard is not
## defensive padding — it is a crash fix. A flattened ellipse is a ring of very
## nearly collinear points, `draw_colored_polygon` fails to triangulate it, and the
## error is fatal to the whole frame: the first version put a wet catchlight at
## ry*0.17 on a small lump and the sit died mid-run in the debugger. Same failure
## the pile's trapezoids were rewritten around; see the vector-pass notes.
func _blob(at: Vector2, rx: float, ry: float, rot: float, col: Color,
		segments: int = 14) -> void:
	if rx < 0.7 or ry < 0.7:
		return
	_ci.draw_colored_polygon(VectorDraw.ellipse_pts(at, rx, ry, segments, rot), col)
## it, and it is the DARK disc that does the real work: it is a hair wider than the
## light one, so where two lumps meet you get a seam of shadow, and where they
## don't quite meet you get a notch. That is the whole "space left between the
## chunks" read, and it costs one extra polygon per lump.
##
## Everything about a lump — where along the crest, how wide, how tall, which way
## it leans — is a pure function of (index, _seed), exactly like the surface noise
## it sits on. Nothing here calls randf(): _draw() re-runs every frame, so a live
## roll would make the pile boil.
func _draw_pile_lumps(cav: Rect2, chunky: float, crust: Color, body: Color) -> void:
	# Sized off the sim's own footprint, so a drawn lump is the width of a lump
	# that actually landed rather than a number picked to look right.
	var base: float = cav.size.x * level.chunk_spread
	if base < 1.5:
		return
	var step := base * 1.05
	var rise := base * 0.86
	var count := int(cav.size.x / step) + 1
	# Rows march DOWN from the crest until they run out of pile. Capped, because on
	# a tall narrow cavity the count is otherwise unbounded — and by then everything
	# below is buried behind the rows above it anyway.
	var rows := mini(PILE_LUMP_ROW_CAP, int(cav.size.y / rise) + 1)
	var shade := body.lerp(MATTER_DARK, 0.55)

	# Row 0 is the crest; each row below is a lump deeper and takes more of the
	# shadow tone. Filling the whole depth is what makes the mass read as BUILT of
	# these things — with only the crest cobbled, the face below it was a plain
	# brown wall and the pile looked like a poured slab with a lid on.
	for row in rows:
		for k in count:
			var i := row * 997 + k
			# Alternate rows are offset half a step, so the lumps pack like brick
			# rather than lining up into columns.
			var slot := float(k) + 0.5 + 0.5 * float(row & 1) + (_lump(i, 601) - 0.5) * 0.55
			var u := slot * step / cav.size.x
			if u < 0.0 or u > 1.0:
				continue
			var hgt: float = _sample_bowl(u)
			var rx: float = base * (0.62 + 0.55 * _lump(i, 605)) * chunky
			var ry: float = rx * (0.58 + 0.34 * _lump(i, 603))
			# How far below the crest this lump's centre sits. A lump has to be
			# buried to at least its own half-height, or it would float over a pile
			# too shallow to be holding it.
			var sink: float = ry * 1.15 + float(row) * rise
			if hgt * cav.size.y < sink + 1.0:
				continue
			var at := Vector2(cav.position.x + cav.size.x * u,
					cav.end.y - cav.size.y * hgt + sink)
			if at.y - ry > cav.end.y:
				continue     # below the bowl's floor
			var rot: float = (_lump(i, 607) - 0.5) * 1.1
			var lit: float = clampf(1.0 - 0.26 * float(row), 0.34, 1.0)
			# The dark disc is the one doing the real work: a hair wider than the
			# light one, so touching lumps get a seam of shadow and lumps that fall
			# short of each other get a notch. That IS the gap between the chunks.
			_blob(at, rx * 1.16, ry * 1.16, rot, shade)
			_blob(at, rx, ry, rot, crust.lerp(shade, 1.0 - lit))
			if row == 0 and _lump(i, 609) > 0.5:
				# One wet catchlight per lump that gets one, lit from up and to the
				# right like the sitter. Kept WIDE and shallow: a round one centred
				# on the lump turned every cobble into a coin.
				_blob(at + Vector2(rx * 0.22, -ry * 0.42), rx * 0.42, ry * 0.22, rot,
						Palette.MATTER_LIT, 10)


## Lumps still in the air, on their way down.
##
## Every one of these is a real BowlChunk the sim is carrying: its width is the
## footprint it will deposit, and it is falling toward the column it will actually
## land on. The only liberties taken here are render-side easing — it accelerates
## downward and tumbles as it goes, neither of which feeds back.
func _draw_chunks(h: float, cav: Rect2) -> void:
	if state.chunks.is_empty():
		return
	var top := cav.position.y - h * 0.012
	var shade := MATTER.lerp(MATTER_DARK, 0.5)
	for chunk in state.chunks:
		var f: float = clampf(chunk.fall, 0.0, 1.0)
		# The sim drops it at a constant rate; gravity is applied here, where it is
		# only a picture. Both ends still line up exactly with the sim's timing.
		var drop: float = f * f * 0.7 + f * 0.3
		var land: float = cav.end.y - cav.size.y * clampf(_sample_bowl(chunk.u), 0.0, 1.08)
		# It drifts across to its landing column as it falls — this is the visible
		# half of the scatter roll, and the reason a lump reads as coming away
		# crooked rather than as being aimed.
		var u: float = lerpf(chunk.from_u, chunk.u, drop)
		# Drawn half again as wide as the footprint it will deposit. In the air it has
		# nothing to be judged against, and at true size it read as a crumb rather than
		# as the lump that is about to become one of the cobbles below it.
		var rx: float = cav.size.x * chunk.half * 1.45
		var ry: float = rx * 0.78
		var rot: float = (chunk.grain - 0.5) * 9.0 * f
		var at := Vector2(cav.position.x + cav.size.x * u, lerpf(top, land - ry, drop))
		_blob(at, rx * 1.12, ry * 1.12, rot, shade, 16)
		_blob(at, rx, ry, rot, MATTER, 16)
		# A second, smaller blob welded to the first: one clean oval reads as a
		# pebble, two overlapping read as something that broke off something.
		var off := Vector2(cos(rot) * rx * 0.55, sin(rot) * rx * 0.55)
		_blob(at + off, rx * 0.62, ry * 0.72, rot, MATTER)
		_blob(at + Vector2(rx * 0.2, -ry * 0.38), rx * 0.32, ry * 0.24, rot,
				Palette.MATTER_LIT, 10)


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


## What's actually coming out.
##
## Two halves of one idea, cross-faded by consistency. Runny is a rope: thin, quick
## and near-straight, falling all the way to where the sim is depositing it, and
## this is verbatim what the stream has always been. Solid does not pour at all —
## it swells at the exit and breaks off, and the falling is done by _draw_chunks.
## Width tracks the live fill rate either way, so the stream stays a direct readout
## of how fast you're filling.
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
	var wid := cav.size.x * (0.012 + 0.038 * vol) * (0.65 + 0.8 * thick)

	# How much of the output is leaving as lumps. Faded over a narrow band rather
	# than read off PushSim.chunk_size directly: the sim's lump size STEPS at the
	# threshold (see CHUNK_MIN_FRACTION), and a rope that vanished in one frame
	# would read as a glitch.
	var chunky := 0.0 if level.chunk_mass <= 0.0 else smoothstep(
			level.chunk_thickness_floor, level.chunk_thickness_floor + 0.18, thick)

	if chunky < 0.97:
		# Solid wavers on the way down; runny falls straight and fast.
		var wave := cav.size.x * 0.020 * thick
		var speed := lerpf(11.0, 4.0, thick)
		var rope := wid * (1.0 - chunky)
		var segs := 6
		var prev := Vector2(x, top)
		for s in range(1, segs + 1):
			var f := float(s) / float(segs)
			var pt := Vector2(x + sin(frame.t * speed + f * 5.5) * wave * f, lerpf(top, land, f))
			# Tapers slightly toward the landing — it's stretching as it falls.
			VectorDraw.limb(_ci, prev, pt, rope * (1.0 - 0.18 * f), MATTER)
			prev = pt
		VectorDraw.limb(_ci, Vector2(x, top), Vector2(x, top + (land - top) * 0.55),
				rope * 0.30, Palette.MATTER_LIT)

		# Where it lands. Runny spreads on impact; solid just plops.
		var splat := rope * (1.6 - 0.7 * thick)
		_ci.draw_circle(prev, splat, MATTER)
		if thick < 0.5:
			var spread := splat * (1.0 + 1.4 * (0.5 - thick))
			VectorDraw.limb(_ci, prev - Vector2(spread, 0.0), prev + Vector2(spread, 0.0),
					maxf(1.0, rope * 0.35), MATTER)

	if chunky > 0.03:
		_draw_forming_lump(cav, x, top, chunky)


## The piece still attached: it swells at the exit until it is heavy enough to go.
##
## Read straight off the sim's own accumulator, so the moment it disappears is the
## exact moment a BowlChunk was appended. That timing is the whole gag — it hangs,
## it hangs, and then it is gone and there is one falling.
func _draw_forming_lump(cav: Rect2, x: float, top: float, chunky: float) -> void:
	var ready: float = 0.0 if state.chunk_target <= 0.0 \
			else clampf(state.chunk_pending / state.chunk_target, 0.0, 1.0)
	var rx: float = cav.size.x * level.chunk_spread * chunky * (0.30 + 0.80 * ready)
	if rx < 1.0:
		return
	var ry := rx * 0.85
	var at := Vector2(x, top + ry * 0.45)
	_blob(at, rx * 1.12, ry * 1.12, 0.0, MATTER.lerp(MATTER_DARK, 0.5), 16)
	_blob(at, rx, ry, 0.0, MATTER, 16)
	_blob(at + Vector2(rx * 0.22, -ry * 0.3), rx * 0.32, ry * 0.22, 0.0,
			Palette.MATTER_LIT, 10)



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

