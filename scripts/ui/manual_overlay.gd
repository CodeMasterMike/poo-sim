class_name ManualOverlay
extends OverlayPanel
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

var _body: RichTextLabel


## Rewind to the top each time it opens. Reopening the manual halfway down the
## hazard list, where you left it, reads as the panel having failed to refresh.
func _on_opened() -> void:
	_body.scroll_to_line(0)


# ---------------------------------------------------------------- construction

## A FULL-SCREEN panel, where the picker is a small centred card — the manual is a
## wall of text and wants every pixel.
func _build_contents(into: Control) -> void:
	var help_btn: Button = add_toggle_button("?", 40, Control.PRESET_TOP_RIGHT, -92, 16, -20, 80)
	help_btn.custom_minimum_size = Vector2(72, 64)

	var margin: MarginContainer = padded(28)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	into.add_child(margin)

	var panel := PanelContainer.new()
	# Zero content margin: the padding container below owns the inset, and letting
	# the style box add its own too would inset the body text twice.
	panel.add_theme_stylebox_override("panel", panel_style(0))
	margin.add_child(panel)

	var pad: MarginContainer = padded(26)
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

	var title: Label = heading("FIELD MANUAL · SEATED OPERATIONS", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	header.add_child(close_button(30))
	return header


# ---------------------------------------------------------------- copy

## Deadpan on purpose. Documents what the prototype actually simulates today (the
## Push, the four gauges, and the live hazards — Knock, Jolt, Buzz, Smell Cloud, and
## the Cover/Hush quiet-room mechanic); extend as the rest of the catalog comes online.
func _manual_text() -> String:
	# BBCode hex spans, straight from the locked Palette tokens.
	var flow := Palette.FLOW.to_html(false)
	var red := Palette.RED.to_html(false)
	var amber := Palette.AMBER.to_html(false)
	var dim := Palette.TEXT_DIM.to_html(false)
	# Copy below uses a compact [c=hex]…[/c] shorthand for readability; expand it to
	# real BBCode color spans here in one pass.
	var s: String = "".join([
		_h("OBJECTIVE"),
		"You are seated. You will not be leaving until the act is complete. ",
		"Fill the [c=%s]RELIEF[/c] gauge to 100%% before your [c=%s]COMPOSURE[/c] runs out — " % [flow, amber],
		"quietly, and without incident. This is a matter of personal dignity. Treat it as such.\n\n",

		_h("I.  THE PUSH"),
		"One control governs everything. [b]Hold anywhere[/b] to bear down and raise the needle; ",
		"[b]release[/b] to relax and let it fall. The needle sits in one of three zones:\n",
		_li("[c=%s]DEAD ZONE (low)[/c]" % dim,
			"Nothing happens down here, slowly. Relief barely fills and your Composure bleeds while you dither. Idling is not a strategy; it is a defeat in slow motion."),
		_li("[c=%s]FLOW (green band)[/c]" % flow,
			"The professional's zone. Relief fills at the ideal rate, no penalty. Keep the needle here. Note that the band will move, narrow, and drift as conditions change — adapt to it."),
		_li("[c=%s]RED ZONE (high)[/c]" % red,
			"Maximum output, roughly one-and-a-half times Flow — and where things go wrong. Linger and you will SPLASH (a Cleanliness event) and make NOISE (a Discretion event). A brief, deliberate dip into the red is a legitimate tactic. Camping there is how amateurs are identified."),
		"\n",

		_h("II.  THE FOUR GAUGES"),
		"Every sitting is measured on four instruments. For all four, [b]fuller is better.[/b]\n",
		_li("[c=%s]RELIEF[/c]" % flow,
			"Your progress, and the win condition. Reach 100% and you are free."),
		_li("[c=%s]COMPOSURE[/c]" % amber,
			"Your clock and your nerve. It only ever falls. Empty it and you lose your composure entirely — a panic failure. It drains faster while you idle in the dead zone or strain in the red."),
		_li("[c=%s]DISCRETION[/c]" % amber,
			"The sum of your NOISE and your SMELL. Keep it high and you go unnoticed. Let it fall past the detection threshold and you are, clinically speaking, caught — with consequences appropriate to the venue."),
		_li("[c=%s]CLEANLINESS[/c]" % amber,
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
		_li("[b]COVER & HUSH[/b]",
			("Some venues police every sound; watch the banner and match your Push to it. In the [b]Church[/b] the room is silent — wait for an organ swell ([c=%s]COVER[/c]) to bear down, and ride low through the [c=%s]SILENCE[/c] between. The [b]Rave[/b] inverts it: the [c=%s]BASS[/c] hides everything, so push freely until a [c=%s]HUSH[/c] falls and you are exposed. Same rule either way — [b]push while it is safe, ease off while exposed[/b]. Bearing down while exposed is heard, and Discretion bleeds fast." % [flow, red, flow, red])),
		"\n",

		_h("IV.  CONTROLS"),
		_li("[b]Hold / Space[/b]", "Push."),
		_li("[b]Drag / Swipe[/b]", "Waft a cloud; re-center after a jolt."),
		_li("[b]Tap[/b]", "Dismiss the phone."),
		_li("[b]R[/b]", "Restart the sitting."),
		_li("[b]%s[/b]" % _venue_keys(), "Switch venue: %s." % LevelCatalog.names_joined()),
		_li("[b]H / Esc[/b]", "Open or close this manual."),
		_li("[b]B[/b]", "Toggle the autopilot (demonstration only)."),
		"\n",
		"[c=%s]This manual is provisional and expands as new venues and hazards enter service. Sit with confidence.[/c]" % dim,
	])
	return s.replace("[c=", "[color=#").replace("[/c]", "[/color]")


## The number keys the roster actually uses, as "1 / 2 / 3".
##
## The manual is the sixth and worst place a venue used to be spelled out: prose
## drifts silently, and a controls table that names three venues on a build with
## five is a documentation bug a player hits before anyone else does. Both halves of
## that line now come from LevelCatalog, which is the only coupling this overlay has
## to anything outside itself — a deliberate trade, because the alternative is copy
## that is wrong by default.
func _venue_keys() -> String:
	var keys := PackedStringArray()
	for slot in range(1, LevelCatalog.key_slots() + 1):
		keys.append(str(slot))
	return " / ".join(keys)


func _h(title: String) -> String:
	return "[b][font_size=34][color=#%s]%s[/color][/font_size][/b]\n" % [C_TITLE.to_html(false), title]


func _li(term: String, desc: String) -> String:
	return "   •  %s — %s\n" % [term, desc]
