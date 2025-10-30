extends Control
class_name TrafficUI

@export var ui_row_up_offset: float = 100.0

@onready var start_button: Button = $StartButton
@onready var speed_slider: HSlider = $SpeedSlider
@onready var panel_A: Control = $LightA
@onready var panel_B: Control = $LightB
@onready var panel_C: Control = $LightC
@onready var panel_D: Control = $LightD

var speed_input: SpinBox
var speed_label: Label        # 只这个标签要深灰色
var _locked_by_running: bool = false
var _show_light_panels: bool = false

signal start_pressed
signal lights_changed
signal speed_changed(value: float)

func _ready() -> void:
	_ensure_ui_fullrect()
	_bootstrap_ui_defaults()
	_ensure_speed_input()
	_ensure_speed_label()
	_ensure_panel_signal_connections()
	_apply_light_panels_visibility()
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

# =========================
# 对外接口
# =========================

func set_show_light_panels(v: bool) -> void:
	_show_light_panels = v
	_apply_light_panels_visibility()

func set_running(r: bool) -> void:
	_locked_by_running = r

func read_all_lights() -> Array:
	return [
		_read_panel(panel_A),
		_read_panel(panel_B),
		_read_panel(panel_C),
		_read_panel(panel_D),
	]

func get_speed_mps() -> float:
	return float(speed_slider.value)

func layout_for_intersections(intersection_positions: PackedFloat32Array, road_y: float, tick_size: float) -> void:
	var left_x: float = intersection_positions[intersection_positions.size() - 1]
	var right_x: float = intersection_positions[0]
	if left_x > right_x:
		var t = left_x
		left_x = right_x
		right_x = t
	var center_x: float = (left_x + right_x) * 0.5
	var row_up_y: float = road_y - tick_size - ui_row_up_offset

	# 1) 顶部：开始按钮放在最上面、略往上
	if start_button:
		var sb_w: float = 180.0
		var sb_h: float = 52.0
		start_button.size = Vector2(sb_w, sb_h)
		start_button.position = Vector2(center_x - sb_w * 0.5, row_up_y - sb_h - 20.0)

	# 2) 顶部：速度滑杆居中
	if speed_slider:
		var sl_w: float = maxf(speed_slider.size.x, 420.0)
		speed_slider.size = Vector2(sl_w, 20.0)
		speed_slider.position = Vector2(center_x - sl_w * 0.5, row_up_y)

	# 3) 顶部：左侧“速度”标签（深灰色）
	if speed_label and speed_slider:
		var label_w: float = 64.0
		var label_h: float = 26.0
		speed_label.size = Vector2(label_w, label_h)
		var x_lbl: float = (center_x - speed_slider.size.x * 0.5) - label_w - 12.0
		speed_label.position = Vector2(x_lbl, row_up_y - 2.0)

	# 4) 顶部：速度输入框（只放大，不改色）
	if speed_input and speed_slider:
		var gap: float = 12.0
		speed_input.position = Vector2(
			speed_slider.position.x + speed_slider.size.x + gap,
			row_up_y - 4.0
		)

	# 5) 下方红绿灯面板
	var base_down_y: float = road_y + tick_size + 36.0
	if _show_light_panels:
		_position_panel_below(panel_A, 0, base_down_y, intersection_positions)
		_position_panel_below(panel_B, 1, base_down_y, intersection_positions)
		_position_panel_below(panel_C, 2, base_down_y, intersection_positions)
		_position_panel_below(panel_D, 3, base_down_y, intersection_positions)

# =========================
# 内部
# =========================

func _on_start_pressed() -> void:
	emit_signal("start_pressed")

func _ensure_ui_fullrect() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	if start_button:
		start_button.text = "开始"
		start_button.add_theme_font_size_override("font_size", 20)

	if speed_slider:
		speed_slider.min_value = 10.0
		speed_slider.max_value = 40.0
		speed_slider.step = 0.5
		speed_slider.value = 20.0

func _ensure_speed_input() -> void:
	var existing: Node = get_node_or_null("SpeedInput")
	if existing and existing is SpinBox:
		speed_input = existing
	else:
		speed_input = SpinBox.new()
		speed_input.name = "SpeedInput"
		add_child(speed_input)

	speed_input.min_value = 10.0
	speed_input.max_value = 40.0
	speed_input.step = 0.5
	speed_input.value = speed_slider.value
	speed_input.size = Vector2(96.0, 26.0)
	speed_input.suffix = " m/s"
	# 这里只放大，不改颜色
	speed_input.add_theme_font_size_override("font_size", 18)

	if not speed_slider.value_changed.is_connected(_on_speed_slider_changed):
		speed_slider.value_changed.connect(_on_speed_slider_changed)
	if not speed_input.value_changed.is_connected(_on_speed_input_changed):
		speed_input.value_changed.connect(_on_speed_input_changed)

func _ensure_speed_label() -> void:
	var ex: Node = get_node_or_null("SpeedLabel")
	if ex and ex is Label:
		speed_label = ex
	else:
		speed_label = Label.new()
		speed_label.name = "SpeedLabel"
		add_child(speed_label)
	speed_label.text = "速度"
	# 这个要深灰
	speed_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	speed_label.add_theme_font_size_override("font_size", 18)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _on_speed_slider_changed(v: float) -> void:
	if speed_input and absf(speed_input.value - v) > 1e-4:
		speed_input.value = v
	emit_signal("speed_changed", v)

func _on_speed_input_changed(v: float) -> void:
	if speed_slider and absf(speed_slider.value - v) > 1e-4:
		speed_slider.value = v
	emit_signal("speed_changed", v)

func _bootstrap_ui_defaults() -> void:
	var panels_all: Array = [panel_A, panel_B, panel_C, panel_D]
	for panel in panels_all:
		if panel and panel is Control:
			var st: OptionButton = panel.get_node("StartState") as OptionButton
			if st and st.item_count < 2:
				st.clear()
				st.add_item("绿", 0)
				st.add_item("红", 1)
	_set_panel_defaults(panel_A, 30.0, 30.0, 0, 0.0)
	_set_panel_defaults(panel_B, 30.0, 30.0, 1, 0.0)
	_set_panel_defaults(panel_C, 30.0, 30.0, 1, 20.0)
	_set_panel_defaults(panel_D, 30.0, 30.0, 1, 20.0)

func _set_panel_defaults(panel: Control, g: float, r: float, st_idx: int, el: float) -> void:
	if not (panel and panel is Control):
		return
	var gv: SpinBox = panel.get_node("GreenSec") as SpinBox
	var rv: SpinBox = panel.get_node("RedSec") as SpinBox
	var ev: SpinBox = panel.get_node("StartElapsedSec") as SpinBox
	var sv: OptionButton = panel.get_node("StartState") as OptionButton
	if gv:
		gv.min_value = 0.1
		gv.value = maxf(g, 0.1)
	if rv:
		rv.min_value = 0.1
		rv.value = maxf(r, 0.1)
	if ev:
		ev.min_value = 0.0
		ev.value = maxf(el, 0.0)
	if sv:
		sv.selected = st_idx

func _ensure_panel_signal_connections() -> void:
	var panels_all: Array = [panel_A, panel_B, panel_C, panel_D]
	for p in panels_all:
		if not (p and p is Control):
			continue
		var gv = p.get_node("GreenSec") as SpinBox
		var rv = p.get_node("RedSec") as SpinBox
		var ev = p.get_node("StartElapsedSec") as SpinBox
		var sv = p.get_node("StartState") as OptionButton
		if gv and not gv.value_changed.is_connected(_on_any_panel_value_changed):
			gv.value_changed.connect(_on_any_panel_value_changed)
		if rv and not rv.value_changed.is_connected(_on_any_panel_value_changed):
			rv.value_changed.connect(_on_any_panel_value_changed)
		if ev and not ev.value_changed.is_connected(_on_any_panel_value_changed):
			ev.value_changed.connect(_on_any_panel_value_changed)
		if sv and not sv.item_selected.is_connected(_on_any_panel_item_selected):
			sv.item_selected.connect(_on_any_panel_item_selected)

func _on_any_panel_value_changed(_v: float) -> void:
	if _locked_by_running:
		return
	emit_signal("lights_changed")

func _on_any_panel_item_selected(_idx: int) -> void:
	if _locked_by_running:
		return
	emit_signal("lights_changed")

func _apply_light_panels_visibility() -> void:
	var panels_all: Array = [panel_A, panel_B, panel_C, panel_D]
	for p in panels_all:
		if p:
			p.visible = _show_light_panels

func _position_panel_below(panel: Control, idx: int, base_y: float, intersection_positions: PackedFloat32Array) -> void:
	if panel and idx < intersection_positions.size():
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var w: float = panel.size.x
		var h: float = panel.size.y
		if w <= 1.0:
			w = 200.0
		if h <= 1.0:
			h = 100.0
		panel.size = Vector2(w, h)
		var x_center: float = intersection_positions[idx]
		panel.position = Vector2(x_center - w * 0.5, base_y)

func _read_panel(panel: Control) -> LightConfig:
	var g: float = (panel.get_node("GreenSec") as SpinBox).value
	var r: float = (panel.get_node("RedSec") as SpinBox).value
	var st_idx: int = (panel.get_node("StartState") as OptionButton).selected
	var el: float = (panel.get_node("StartElapsedSec") as SpinBox).value
	return LightConfig.new(g, r, st_idx, el)
