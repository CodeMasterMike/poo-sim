class_name VectorDraw
extends RefCounted
## The Sit's drawing primitives — the vocabulary every screen paints in.
##
## Godot's `draw_*` calls have no blur, no gradients and no rounded shapes, so the
## whole vector look is built from three tricks: StyleBoxFlat for rounded rects,
## per-vertex polygon colours for gradients, and stacked translucent passes for
## anything that wants to glow. Those tricks are what lives here.
##
## Every function takes the CanvasItem to paint into as its first argument, rather
## than the class holding a reference to one. Static and stateless means a second
## screen (the results card, the prep bookend) can draw in the same idiom without
## inheriting from anything or being handed an instance — and it keeps the
## primitives honestly separate from the thing being drawn.
##
## Pure presentation: nothing here knows what a Relief meter is.

const TRANSPARENT := Color(0, 0, 0, 0)


## A rounded rect. Deliberately allocates a FRESH StyleBoxFlat every call —
## draw commands can resolve a style box after _draw() returns, so reusing and
## mutating one would repaint every earlier rect with the last colour set.
static func rrect(ci: CanvasItem, rect: Rect2, col: Color, radius: int,
		border_col: Color = TRANSPARENT, border_w: int = 0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border_col
		sb.set_border_width_all(border_w)
	ci.draw_style_box(sb, rect)


## Like rrect, but with per-corner radii. The bowl needs a tight top and a deep
## round bottom to read as a basin instead of a bucket, and a single radius can't
## say that.
## (Spelled out rather than tl/tr/br/bl — "tr" shadows Object.tr().)
static func rrect_corners(ci: CanvasItem, rect: Rect2, col: Color,
		top_l: int, top_r: int, bot_r: int, bot_l: int,
		border_col: Color = TRANSPARENT, border_w: int = 0) -> void:
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
	ci.draw_style_box(sb, rect)


## A closed polygon with a thick ink outline — the register-A treatment (§5:
## flat fill, one shadow tone, thick outline, no gradient) for the shapes a
## rounded rect can't say. The toilet's body is one: it has to pinch in under
## the seat and kick back out into a foot, and no corner radius describes that.
##
## The ink goes down FIRST, as an over-wide closed polyline, and the fill covers
## its inner half. Same trick as shade_limbs(), and for the same reason: an
## outline stroked on top straddles the edge and eats inward, which on a band as
## thin as the seat's closes the shape up entirely.
static func inked(ci: CanvasItem, pts: PackedVector2Array, col: Color,
		ink: Color = TRANSPARENT, iw: float = 0.0) -> void:
	if pts.size() < 3:
		return
	if iw > 0.0 and ink.a > 0.0:
		var ring := pts.duplicate()
		ring.append(pts[0])
		ci.draw_polyline(ring, ink, iw * 2.0, true)
	ci.draw_colored_polygon(pts, col)


## An ellipse, as a polygon. The toilet is ellipses all the way down — the seat,
## its opening, the shadow the pedestal casts on the floor — and Godot draws
## circles and rounded rects and nothing in between. Scaling a circle under a
## transform was the alternative, and it scales the ink with it, so a squashed
## seat comes back with a squashed outline.
static func ellipse_pts(center: Vector2, rx: float, ry: float,
		segments: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color,
		ink: Color = TRANSPARENT, iw: float = 0.0) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	inked(ci, ellipse_pts(center, rx, ry), col, ink, iw)


## An ellipse as an outline rather than a fill — a hoop lying at some depth in
## the bowl, which is how a level reads once the bowl has a mouth you look down
## into. Closed, so there is no seam at the start point.
static func ellipse_ring(ci: CanvasItem, center: Vector2, rx: float, ry: float,
		col: Color, width: float, segments: int = 48) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var pts := ellipse_pts(center, rx, ry, segments)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, width, true)


## A vertical two-stop gradient, as a quad with per-vertex colours. Its corners
## are SHARP — inset it inside a rounded housing rather than using it as the
## outer shape of anything.
static func vgrad(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var pts := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


## One horizontal slice of the gauge track, in needle-space (0..1).
static func band(ci: CanvasItem, x: float, bw: float, bottom: float, gh: float,
		n_lo: float, n_hi: float, col: Color, radius: int = 8) -> void:
	var y_hi := bottom - n_hi * gh
	var y_lo := bottom - n_lo * gh
	rrect(ci, Rect2(x, y_hi, bw, y_lo - y_hi), col, radius)


## One round-capped bar. draw_line has no round caps, so each end gets a circle.
## Passing the same point twice draws a plain disc — that is how the head is done.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	if a != b:
		ci.draw_line(a, b, col, r * 2.0)
	ci.draw_circle(a, r, col)
	ci.draw_circle(b, r, col)


## Ink, shadow, then lit core — the three passes that turn a list of limbs into
## one cel-shaded silhouette. Every outline is laid down before any fill so the
## figure reads as a single shape rather than a stack of separately-inked tubes.
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
##
## `limbs` is an array of [Vector2 a, Vector2 b, float radius] triples.
static func shade_limbs(ci: CanvasItem, limbs: Array,
		ink: Color, lit: Color, shadow: Color, iw: float) -> void:
	for item in limbs:
		limb(ci, item[0], item[1], item[2] + iw, ink)
	for item in limbs:
		limb(ci, item[0], item[1], item[2], shadow)
	for item in limbs:
		var r: float = item[2]
		var off := Vector2(r * 0.14, -r * 0.10)
		limb(ci, item[0] + off, item[1] + off, r * 0.80, lit)


static func star(ci: CanvasItem, center: Vector2, radius: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	var inner := radius * 0.45
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rr := radius if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, 2.0)


## Centred text in a region. Every label in the Sit is centred, so the alignment
## isn't a parameter — pass the region's left edge and its width.
static func text(ci: CanvasItem, font: Font, s: String, x: float, baseline: int,
		region_w: float, fs: int, col: Color) -> void:
	ci.draw_string(font, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_CENTER, region_w, fs, col)
