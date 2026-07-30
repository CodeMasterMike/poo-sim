class_name LevelPicker
extends Control
## A tappable level picker for the prototype: a persistent "LEVEL: <name>" button
## that opens a menu of venues. Touch + mouse; the 1/2/3 keys stay as accelerators.
##
## Self-contained like ManualOverlay (builds its own node tree, no .tscn), and
## data-driven — it renders whatever names setup() is handed, in order, so new
## LevelKinds show up automatically with no change here.
##
## Pure view: holds no sim state and knows nothing about LevelKind. It emits the
## chosen index; the host maps that back to a level and resets. The host is
## responsible for pausing the sim while is_open().

signal level_chosen(index: int)

# --- Colours: aliased from the locked Palette (docs/specs/poo-sim-style-guide.html). ---
const C_DIM := Palette.SCRIM
const C_PANEL := Palette.PANEL
const C_BORDER := Palette.BORDER
const C_TITLE := Palette.GOAL
const C_TEXT := Palette.TEXT
const C_ACTIVE := Palette.FLOW

var _names: PackedStringArray = []
var _current: int = 0
var _open_btn: Button
var _overlay: Control
var _list: VBoxContainer
var _level_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # never block gameplay while closed
	_build_open_button()
	_build_overlay()


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


func is_open() -> bool:
	return _overlay.visible


func open() -> void:
	_overlay.visible = true


func close() -> void:
	_overlay.visible = false


func toggle() -> void:
	_overlay.visible = not _overlay.visible


# ---------------------------------------------------------------- construction

func _build_open_button() -> void:
	_open_btn = Button.new()
	_open_btn.text = "LEVEL"
	_open_btn.focus_mode = Control.FOCUS_NONE  # must never steal Space from The Push
	_open_btn.add_theme_font_size_override("font_size", 30)
	_open_btn.custom_minimum_size = Vector2(0, 64)
	_open_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_open_btn.offset_left = 20
	_open_btn.offset_top = 16
	_open_btn.offset_right = 300
	_open_btn.offset_bottom = 80
	_open_btn.pressed.connect(toggle)
	add_child(_open_btn)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = C_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 28)
	panel.add_child(pad)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	pad.add_child(_list)


## Rebuild the menu from the current roster. Safe to call again if the roster grows.
func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_level_buttons.clear()

	var title := Label.new()
	title.text = "SELECT A VENUE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)

	for i in _names.size():
		var btn := Button.new()
		btn.text = _names[i]
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 32)
		btn.custom_minimum_size = Vector2(420, 74)
		btn.pressed.connect(_choose.bind(i))
		_list.add_child(btn)
		_level_buttons.append(btn)

	var close_btn := Button.new()
	close_btn.text = "✕ CLOSE"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(close)
	_list.add_child(close_btn)

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


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = C_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	return sb
