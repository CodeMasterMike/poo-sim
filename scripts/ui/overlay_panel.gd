class_name OverlayPanel
extends Control
## The shell every pause-and-read panel is built out of — the manual, the level
## picker, and whatever comes next (a pause menu, a results card, world select).
##
## Both existing overlays had grown the same sixty lines independently: a full-rect
## root that must not block gameplay while closed, a scrim that must eat stray taps
## while open, a corner button whose focus_mode must be NONE or it steals Space from
## The Push, an identical StyleBoxFlat, the `for side in [...]` margin incantation,
## a "✕ CLOSE" button, and is_open/open/close/toggle.
##
## Most of those lines are load-bearing in a way that is invisible when you copy
## them. `focus_mode = FOCUS_NONE` is the one that matters most: miss it on the
## third overlay's button and pressing it hands that button the keyboard, after
## which Space toggles the button instead of pushing — a bug that looks like the
## game ignoring input. Putting it in the shell means the third overlay gets it
## whether or not its author knew to.
##
## What is NOT shared is layout. The manual is a full-screen wall of text and the
## picker is a small centred menu, and pretending those are one parameterised thing
## would cost more than it saves. Subclasses build their own contents; the base owns
## the shell, the open/close state, and the fiddly bits above.
##
## Pure view. Holds no sim state and knows nothing about the model — the host is
## responsible for pausing the sit while `is_open()`.

# --- Colours: aliased from the locked Palette (docs/specs/poo-sim-style-guide.html)
#     once, here, rather than re-listed at the top of every overlay. Subclasses
#     inherit these names directly. ---
const C_SCRIM := Palette.SCRIM
const C_PANEL := Palette.PANEL
const C_BORDER := Palette.BORDER
const C_TITLE := Palette.GOAL
const C_TEXT := Palette.TEXT

## The hidden layer holding the scrim and the panel. Everything a subclass builds
## goes inside it, so one `visible` flag opens and closes the whole overlay.
var _overlay: Control


## Subclasses must NOT define _ready() — override `_build_contents()` instead.
## GDScript overrides rather than chains _ready(), so a subclass that defines one
## silently skips all of this and comes up with no shell at all.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Never block gameplay while closed: this node spans the screen, and at the
	# Control default (STOP) it would swallow every tap aimed at The Push.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = _build_shell()
	_build_contents(_overlay)


## Build the panel's own layout inside `into`. The one method a subclass must have.
func _build_contents(_into: Control) -> void:
	pass


## Called each time the overlay opens — the manual rewinds its scroll here. Not
## called on close.
func _on_opened() -> void:
	pass


# ------------------------------------------------------------------ open / close

func is_open() -> bool:
	return _overlay != null and _overlay.visible


func open() -> void:
	_set_open(true)


func close() -> void:
	_set_open(false)


func toggle() -> void:
	_set_open(not is_open())


func _set_open(value: bool) -> void:
	if _overlay == null:
		return
	_overlay.visible = value
	if value:
		_on_opened()


# ---------------------------------------------------------------- construction

## The root + scrim, hidden. The scrim is MOUSE_FILTER_STOP on purpose: while the
## overlay is open it must absorb taps that miss the panel, or a tap beside the menu
## falls through and starts a push behind it.
func _build_shell() -> Control:
	var shell := Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.visible = false
	add_child(shell)

	var dim := ColorRect.new()
	dim.color = C_SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(dim)
	return shell


## The always-visible button that opens this overlay, placed by pixel offsets from
## the given corner. Placement is the subclass's business — the manual's "?" sits
## top-right and the picker's "LEVEL" top-left — but everything else about it is
## the same button, including the focus_mode that keeps Space meaning "push".
func add_toggle_button(label: String, font_size: int, preset: int,
		left: float, top: float, right: float, bottom: float) -> Button:
	var btn := make_button(label, font_size)
	btn.set_anchors_and_offsets_preset(preset)
	btn.offset_left = left
	btn.offset_top = top
	btn.offset_right = right
	btn.offset_bottom = bottom
	btn.pressed.connect(toggle)
	add_child(btn)
	return btn


## A button in the overlay idiom. FOCUS_NONE is the load-bearing part: a focused
## Button consumes Space and Enter, which are The Push's controls.
static func make_button(label: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	return btn


## The "✕ CLOSE" button, already wired to close(). Every overlay needs a way out
## that isn't a keyboard shortcut — this is a touch game.
func close_button(font_size: int) -> Button:
	var btn := make_button("✕ CLOSE", font_size)
	btn.pressed.connect(close)
	return btn


## The panel chrome: dark card, hairline border, the style guide's corner scale.
## `content_margin` of 0 lets the panel's own padding container own the inset, which
## is what a scrolling body wants — otherwise the text is inset twice.
static func panel_style(content_margin: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = C_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	if content_margin >= 0:
		sb.set_content_margin_all(content_margin)
	return sb


## A MarginContainer with even padding. MarginContainer takes its inset from four
## separately-named theme constants, so this was written out as a `for side in
## [...]` loop at every use.
static func padded(margin: int) -> MarginContainer:
	var box := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		box.add_theme_constant_override(side, margin)
	return box


## A section title in the overlay idiom.
static func heading(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", C_TITLE)
	return label
