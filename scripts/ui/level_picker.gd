class_name LevelPicker
extends OverlayPanel
## A tappable level picker for the prototype: a persistent "LEVEL: <name>" button
## that opens a menu of venues. Touch + mouse; the 1/2/3 keys stay as accelerators.
##
## Self-contained like ManualOverlay (builds its own node tree, no .tscn), and
## data-driven — it renders whatever names setup() is handed, in order, so a venue
## registered in LevelCatalog shows up here with no change to this file.
##
## Pure view: holds no sim state, and deliberately does not read the catalog itself.
## It is handed display names and emits the chosen INDEX; the host converts that
## back to a level id and resets. The host is also responsible for pausing the sim
## while is_open().

signal level_chosen(index: int)

## The scrim, panel and text tones come from OverlayPanel. Only the "now playing"
## highlight is this screen's own, and it is FLOW because it means the same thing
## the Flow band does: this is the one you are on.
const C_ACTIVE := Palette.FLOW

var _names: PackedStringArray = []
var _current: int = 0
var _open_btn: Button
var _list: VBoxContainer
var _level_buttons: Array[Button] = []


## Hand it the roster (display names, in index order) and the current selection.
func setup(names: PackedStringArray, current: int) -> void:
	_names = names
	_current = current
	_rebuild_list()
	_update_open_button()


## Reflect a selection the host made by another route (a 1/2/3 keypress).
func set_current(index: int) -> void:
	_current = index
	_update_open_button()
	_refresh_highlight()


# ---------------------------------------------------------------- construction

## A small CENTRED card, where the manual is a full-screen wall of text — the one
## real difference between the two overlays, and why the base owns the shell rather
## than the layout.
func _build_contents(into: Control) -> void:
	_open_btn = add_toggle_button("LEVEL", 30, Control.PRESET_TOP_LEFT, 20, 16, 300, 80)
	_open_btn.custom_minimum_size = Vector2(0, 64)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	into.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var pad: MarginContainer = padded(28)
	panel.add_child(pad)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	pad.add_child(_list)

	# The host calls setup() after adding us to the tree, but a picker that was never
	# set up should still open onto a usable panel rather than an empty box.
	_rebuild_list()


## Rebuild the menu from the current roster. Safe to call again if the roster grows.
func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_level_buttons.clear()

	var title: Label = heading("SELECT A VENUE", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)

	for i in _names.size():
		var btn: Button = make_button(_names[i], 32)
		btn.custom_minimum_size = Vector2(420, 74)
		btn.pressed.connect(_choose.bind(i))
		_list.add_child(btn)
		_level_buttons.append(btn)

	_list.add_child(close_button(26))
	_refresh_highlight()


func _choose(index: int) -> void:
	close()
	level_chosen.emit(index)


## Mark the current venue on its button; the others read plain. Tapping the current
## one still restarts that level, which is a fine "retry" affordance.
func _refresh_highlight() -> void:
	for i in _level_buttons.size():
		var btn := _level_buttons[i]
		if i == _current:
			btn.text = "%s   •  now playing" % _names[i]
			btn.add_theme_color_override("font_color", C_ACTIVE)
		else:
			btn.text = _names[i]
			btn.add_theme_color_override("font_color", C_TEXT)


func _update_open_button() -> void:
	if _open_btn == null:
		return
	var lvl_name := _names[_current] if _current >= 0 and _current < _names.size() else "?"
	_open_btn.text = "LEVEL:  %s" % lvl_name

