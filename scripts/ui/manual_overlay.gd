class_name ManualOverlay
extends Control
## The in-game FIELD MANUAL — a pause-and-read rules panel. Pure view: it holds no
## sim state and never touches the model, so any scene (this prototype, later the
## real Sit) can drop one in. It builds its whole node tree in code so there's no
## .tscn to hand-edit and it version-controls as a single script.
##
## Written in the spec's deadpan "surprisingly serious simulator" voice (spec §11):
## the gap between the subject and the gravity of the manual IS the joke. It's kept
## deliberately long-winded for the testing phase — trim it once the tutorial and
## real onboarding exist.
##
## Toggled by the always-visible "?" button, or by H / Esc from the host. The host
## is responsible for pausing the sim while `is_open()` — the manual doesn't know
## the sim exists.

# --- Palette (mirrors the grey-box view so the manual reads as the same product) ---
const C_BG := Color(0.07, 0.08, 0.10, 0.92)
const C_PANEL := Color(0.13, 0.15, 0.19)
const C_BORDER := Color(0.30, 0.34, 0.42)
const C_TITLE := Color(0.96, 0.92, 0.42)
const C_TEXT := Color(0.90, 0.93, 0.98)
const HEX_FLOW := "3ed166"
const HEX_RED := "eb4c40"
const HEX_AMBER := "f2bf40"
const HEX_DIM := "94a1b5"

var _overlay: Control
var _body: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # never block gameplay while closed
	_build_help_button()
	_build_overlay()


func is_open() -> bool:
	return _overlay.visible


func toggle() -> void:
	_set_open(not _overlay.visible)


func open() -> void:
	_set_open(true)


func close() -> void:
	_set_open(false)


func _set_open(value: bool) -> void:
	_overlay.visible = value
	if value:
		_body.scroll_to_line(0)


# ---------------------------------------------------------------- construction

func _build_help_button() -> void:
	var btn := Button.new()
	btn.text = "?"
	btn.focus_mode = Control.FOCUS_NONE  # must never steal Space/Enter from The Push
	btn.add_theme_font_size_override("font_size", 40)
	btn.custom_minimum_size = Vector2(72, 64)
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -92
	btn.offset_right = -20
	btn.offset_top = 16
	btn.offset_bottom = 80
	btn.pressed.connect(toggle)
	add_child(btn)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # eat stray taps behind the panel
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = C_BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	_overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	margin.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 26)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	pad.add_child(vbox)

	vbox.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false  # the outer ScrollContainer owns scrolling
	_body.selection_enabled = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 30)
	_body.add_theme_font_size_override("bold_font_size", 30)
	_body.add_theme_color_override("default_color", C_TEXT)
	_body.add_theme_constant_override("line_separation", 4)
	_body.text = _manual_text()
	scroll.add_child(_body)


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()

	var title := Label.new()
	title.text = "FIELD MANUAL · SEATED OPERATIONS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", C_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕ CLOSE"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	return header


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = C_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(0)
	return sb


# ---------------------------------------------------------------- copy

## Deadpan on purpose. Documents only what the prototype actually simulates today
## (the Push, the four gauges, and the four live hazards); extend as the catalog
## comes online.
func _manual_text() -> String:
	# Copy below uses a compact [c=hex]…[/c] shorthand for readability; expand it to
	# real BBCode color spans here in one pass.
	var s: String = "".join([
		_h("OBJECTIVE"),
		"You are seated. You will not be leaving until the act is complete. ",
		"Fill the [c=%s]RELIEF[/c] gauge to 100%% before your [c=%s]COMPOSURE[/c] runs out — " % [HEX_FLOW, HEX_AMBER],
		"quietly, and without incident. This is a matter of personal dignity. Treat it as such.\n\n",

		_h("I.  THE PUSH"),
		"One control governs everything. [b]Hold anywhere[/b] to bear down and raise the needle; ",
		"[b]release[/b] to relax and let it fall. The needle sits in one of three zones:\n",
		_li("[c=%s]DEAD ZONE (low)[/c]" % HEX_DIM,
			"Nothing happens down here, slowly. Relief barely fills and your Composure bleeds while you dither. Idling is not a strategy; it is a defeat in slow motion."),
		_li("[c=%s]FLOW (green band)[/c]" % HEX_FLOW,
			"The professional's zone. Relief fills at the ideal rate, no penalty. Keep the needle here. Note that the band will move, narrow, and drift as conditions change — adapt to it."),
		_li("[c=%s]RED ZONE (high)[/c]" % HEX_RED,
			"Maximum output, roughly one-and-a-half times Flow — and where things go wrong. Linger and you will SPLASH (a Cleanliness event) and make NOISE (a Discretion event). A brief, deliberate dip into the red is a legitimate tactic. Camping there is how amateurs are identified."),
		"\n",

		_h("II.  THE FOUR GAUGES"),
		"Every sitting is measured on four instruments. For all four, [b]fuller is better.[/b]\n",
		_li("[c=%s]RELIEF[/c]" % HEX_FLOW,
			"Your progress, and the win condition. Reach 100%% and you are free."),
		_li("[c=%s]COMPOSURE[/c]" % HEX_AMBER,
			"Your clock and your nerve. It only ever falls. Empty it and you lose your composure entirely — a panic failure. It drains faster while you idle in the dead zone or strain in the red."),
		_li("[c=%s]DISCRETION[/c]" % HEX_AMBER,
			"The sum of your NOISE and your SMELL. Keep it high and you go unnoticed. Let it fall past the detection threshold and you are, clinically speaking, caught — with consequences appropriate to the venue."),
		_li("[c=%s]CLEANLINESS[/c]" % HEX_AMBER,
			"The state of the scene. Splashback and mess erode it. It rarely ends the run outright, but it ends your reputation — and your star rating."),
		"\n",

		_h("III.  FIELD HAZARDS"),
		"The act is never uninterrupted. Each hazard demands exactly one response. ",
		"Learn the response; there is no time to think.\n",
		_li("[b]THE KNOCK[/b]",
			"Someone is at the door. [b]Release everything and hold perfectly still[/b] until they lose interest. Any push during the knock is audible and Discretion craters. Freezing costs you progress and burns Composure — that is the price of not being seen."),
		_li("[b]JOLT / TURBULENCE[/b]",
			"The world lurches and the needle is thrown. [b]Swipe[/b] (drag) to wrestle it back toward the Flow band before it flies into the red or bottoms out."),
		_li("[b]THE BUZZ[/b]",
			"Your phone. [b]Tap[/b] to dismiss it. Ignore it and it grows louder — a Discretion risk — while quietly draining your Composure. It is not important. Dismiss it."),
		_li("[b]THE SMELL CLOUD[/b]",
			"Not scheduled — earned, by pushing hard in the red. A visible cloud rises. [b]Swipe[/b] to waft it away before it is noticed. The real lesson is upstream: push greedy and you manufacture your own problems."),
		"\n",

		_h("IV.  CONTROLS"),
		_li("[b]Hold / Space[/b]", "Push."),
		_li("[b]Drag / Swipe[/b]", "Waft a cloud; re-center after a jolt."),
		_li("[b]Tap[/b]", "Dismiss the phone."),
		_li("[b]R[/b]", "Restart the sitting."),
		_li("[b]H / Esc[/b]", "Open or close this manual."),
		_li("[b]B[/b]", "Toggle the autopilot (demonstration only)."),
		"\n",
		"[c=%s]This manual is provisional and expands as new venues and hazards enter service. Sit with confidence.[/c]" % HEX_DIM,
	])
	return s.replace("[c=", "[color=#").replace("[/c]", "[/color]")


func _h(title: String) -> String:
	return "[b][font_size=34][color=#%s]%s[/color][/font_size][/b]\n" % [C_TITLE.to_html(false), title]


func _li(term: String, desc: String) -> String:
	return "   •  %s — %s\n" % [term, desc]
