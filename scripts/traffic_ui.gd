extends Control
class_name TrafficUI

@export var ui_row_up_offset: float = 100.0

# 这些颜色/字号最好还是让根节点传进来，再用这个函数统一套
var _timer_font_size_px: int = 32
var _timer_font_color: Color = Color(0.2, 0.2, 0.2)

@onready var start_button: Button = $StartButton
@onready var speed_slider: HSlider = $SpeedSlider
@onready var panel_A: Control = $LightA
@onready var panel_B: Control = $LightB
@onready var panel_C: Control = $LightC
@onready var panel_D: Control = $LightD

var speed_input: SpinBox
var timescale_slider: HSlider
var timescale_button: Button
var timer_label: Label

var _locked_by_running: bool = false
var _show_light_panels: bool = false

signal start_pressed
signal lights_changed
signal speed_changed(value: float)
signal timescale_changed(value: float)

func _ready() -> void:
	_ensure_ui_fullrect()
	_bootstrap_ui_defaults()
	_ensure_speed_input()
	_ensure_timescale_controls()
	_ensure_timer_label()
	_ensure_panel_signal_connections()
	_apply_light_panels_visibility()
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	_update_timer_label(0.0)

# —— 提供给外部的接口 —— 

func set_show_light_panels(v: bool) -> void:
	_show_light_panels = v
	_apply_light_panels_visibility()

func set_running(r: bool) -> void:
	_locked_by_running = r

func set_timer_style(font_size_px: int, font_color: Color) -> void:
	_timer_font_size_px = font_size_px
	_timer_font_color = font_color
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", _timer_font_size_px)
		timer_label.add_theme_color_override("font_color", _timer_font_color)

func update_timer(sec: float) -> void:
	_update_timer_label(sec)

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

	# 顶部：速度滑杆居中
	if speed_slider:
		var sl_w: float = maxf(speed_slider.size.x, 420.0)
		speed_slider.size = Vector2(sl_w, 20.0)
		speed_slider.position = Vector2(center_x - sl_w * 0.5, row_up_y)

	# 顶部：开始按钮
	if start_button:
		var sb_w: float = maxf(start_button.size.x, 120.0)
		var sb_h: float = maxf(start_button.size.y, 36.0)
		start_button.size = Vector2(sb_w, sb_h)
		var x_btn: float = (center_x - speed_slider.size.x * 0.5) - sb_w - 12.0
		start_button.position = Vector2(x_btn, row_up_y - 2.0)

	# 顶部：速度输入框
	if speed_input:
		var gap: float = 12.0
		speed_input.position = Vector2(speed_slider.position.x + speed_slider.size.x + gap, row_up_y - 2.0)

	# 顶部：计时标签
	if timer_label:
		var tl_w: float = 320.0
		var tl_h: float = float(_timer_font_size_px) + 12.0
		timer_label.size = Vector2(tl_w, tl_h)
		timer_label.position = Vector2(center_x - tl_w * 0.5, row_up_y - (tl_h + 4.0))
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 面板：在下方
	var base_down_y: float = road_y + tick_size + 36.0
	if _show_light_panels:
		_position_panel_below(panel_A, 0, base_down_y, intersection_positions)
		_position_panel_below(panel_B, 1, base_down_y, intersection_positions)
		_position_panel_below(panel_C, 2, base_down_y, intersection_positions)
		_position_panel_below(panel_D, 3, base_down_y, intersection_positions)

	# 面板下方：加速控件
	var max_panel_h: float = 0.0
	if _show_light_panels:
		max_panel_h = maxf(
			maxf(panel_A.size.y, panel_B.size.y),
			maxf(panel_C.size.y, panel_D.size.y)
		)
	var row_ts_y: float = base_down_y + max_panel_h + 16.0

	if timescale_slider:
		var ts_w: float = 300.0
		timescale_slider.size = Vector2(ts_w, 20.0)
		timescale_slider.position = Vector2(center_x - ts_w * 0.5, row_ts_y)

	if timescale_button:
		var gap_ts: float = 12.0
		timescale_button.size = Vector2(96.0, 32.0)
		timescale_button.position = Vector2(
			timescale_slider.position.x + timescale_slider.size.x + gap_ts,
			row_ts_y - 2.0
		)

# —— 内部实现 —— 

func _on_start_pressed() -> void:
	emit_signal("start_pressed")

func _ensure_ui_fullrect() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
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
	speed_input.size = Vector2(96.0, 24.0)
	speed_input.suffix = " m/s"

	if not speed_slider.value_changed.is_connected(_on_speed_slider_changed):
		speed_slider.value_changed.connect(_on_speed_slider_changed)
	if not speed_input.value_changed.is_connected(_on_speed_input_changed):
		speed_input.value_changed.connect(_on_speed_input_changed)

func _on_speed_slider_changed(v: float) -> void:
	if speed_input and absf(speed_input.value - v) > 1e-4:
		speed_input.value = v
	emit_signal("speed_changed", v)

func _on_speed_input_changed(v: float) -> void:
	if speed_slider and absf(speed_slider.value - v) > 1e-4:
		speed_slider.value = v
	emit_signal("speed_changed", v)

func _ensure_timescale_controls() -> void:
	var ex1: Node = get_node_or_null("TimeScaleSlider")
	if ex1 and ex1 is HSlider:
		timescale_slider = ex1
	else:
		timescale_slider = HSlider.new()
		timescale_slider.name = "TimeScaleSlider"
		add_child(timescale_slider)
	timescale_slider.min_value = 1.0
	timescale_slider.max_value = 10.0
	timescale_slider.step = 0.5
	timescale_slider.value = 10.0

	var ex2: Node = get_node_or_null("ApplyTimeScaleButton")
	if ex2 and ex2 is Button:
		timescale_button = ex2
	else:
		timescale_button = Button.new()
		timescale_button.name = "ApplyTimeScaleButton"
		add_child(timescale_button)
	timescale_button.text = "应用加速"
	if not timescale_button.pressed.is_connected(_on_apply_timescale_pressed):
		timescale_button.pressed.connect(_on_apply_timescale_pressed)

func _on_apply_timescale_pressed() -> void:
	var v: float = clampf(timescale_slider.value, 1.0, 10.0)
	timescale_button.text = "加速 ×" + str(v)
	emit_signal("timescale_changed", v)

func _ensure_timer_label() -> void:
	var ex: Node = get_node_or_null("TimerLabel")
	if ex and ex is Label:
		timer_label = ex
	else:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		add_child(timer_label)
	timer_label.add_theme_font_size_override("font_size", _timer_font_size_px)
	timer_label.add_theme_color_override("font_color", _timer_font_color)

func _update_timer_label(sec: float) -> void:
	if timer_label:
		var s = snappedf(sec, 0.1)
		timer_label.text = "总用时：" + str(s) + " 秒"

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
