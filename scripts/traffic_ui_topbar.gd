extends RefCounted
class_name TrafficUITopBar

signal start_requested
signal speed_changed(val: float)

var _owner: Control
var _speed_min: float
var _speed_max: float
var _default_speed: float

var _start_button: Button
var _speed_label: Label
var _speed_slider: HSlider
var _speed_input: SpinBox

var _locked: bool = false

func _init(owner: Control, min_mps: float, max_mps: float, def_mps: float) -> void:
	_owner = owner
	_speed_min = min_mps
	_speed_max = max_mps
	_default_speed = clampf(def_mps, _speed_min, _speed_max)
	_build_nodes()
	_bind_signals()
	_apply_default_speed()

func _build_nodes() -> void:
	_owner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_owner.offset_left = 0
	_owner.offset_top = 0
	_owner.offset_right = 0
	_owner.offset_bottom = 0

	_start_button = _owner.get_node_or_null("StartButton") as Button
	if _start_button == null:
		_start_button = Button.new()
		_start_button.name = "StartButton"
		_owner.add_child(_start_button)
	_start_button.text = "开始"
	_start_button.size = Vector2(160, 48)
	_start_button.add_theme_font_size_override("font_size", 30)

	_speed_label = _owner.get_node_or_null("SpeedLabel") as Label
	if _speed_label == null:
		_speed_label = Label.new()
		_speed_label.name = "SpeedLabel"
		_owner.add_child(_speed_label)
	_speed_label.text = "速度"
	_speed_label.modulate = Color(0.2, 0.2, 0.2)
	_speed_label.add_theme_font_size_override("font_size", 26)

	_speed_slider = _owner.get_node_or_null("SpeedSlider") as HSlider
	if _speed_slider == null:
		_speed_slider = HSlider.new()
		_speed_slider.name = "SpeedSlider"
		_owner.add_child(_speed_slider)
	_speed_slider.min_value = _speed_min
	_speed_slider.max_value = _speed_max
	_speed_slider.step = 0.5

	_speed_input = _owner.get_node_or_null("SpeedInput") as SpinBox
	if _speed_input == null:
		_speed_input = SpinBox.new()
		_speed_input.name = "SpeedInput"
		_owner.add_child(_speed_input)
	_speed_input.min_value = _speed_min
	_speed_input.max_value = _speed_max
	_speed_input.step = 0.5
	_speed_input.suffix = " m/s"
	_speed_input.add_theme_font_size_override("font_size", 22)
	_speed_input.size = Vector2(110, 28)   # 保证文字不被裁掉

func _bind_signals() -> void:
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if not _speed_slider.value_changed.is_connected(_on_slider_changed):
		_speed_slider.value_changed.connect(_on_slider_changed)
	if not _speed_input.value_changed.is_connected(_on_input_changed):
		_speed_input.value_changed.connect(_on_input_changed)

func _apply_default_speed() -> void:
	_speed_slider.value = _default_speed
	_speed_input.value = _default_speed

func layout_for_intersections(intersections: PackedFloat32Array, road_y: float, tick_size: float) -> void:
	if intersections.size() < 2:
		return
	var left_x: float = intersections[0]
	var right_x: float = intersections[intersections.size() - 1]
	var center_x: float = (left_x + right_x) * 0.5
	var row_up_y: float = road_y - tick_size - 100.0

	var sl_w: float = maxf(_speed_slider.size.x, 420.0)
	_speed_slider.size = Vector2(sl_w, 20.0)
	_speed_slider.position = Vector2(center_x - sl_w * 0.5, row_up_y)

	_speed_label.position = Vector2(_speed_slider.position.x - 96.0, row_up_y - 4.0)
	_speed_label.size = Vector2(80.0, 30.0)

	_start_button.position = Vector2(center_x - 160 * 0.5, row_up_y - 64.0)

	_speed_input.position = Vector2(
		_speed_slider.position.x + _speed_slider.size.x + 14.0,
		row_up_y - 4.0
	)

func set_running(is_running: bool) -> void:
	_locked = is_running
	_start_button.disabled = is_running
	_speed_slider.editable = not is_running
	_speed_input.editable = not is_running
	_start_button.text = "运行中..." if is_running else "开始"

func get_speed_mps() -> float:
	return clampf(_speed_slider.value, _speed_min, _speed_max)

func set_speed_mps(v: float) -> void:
	var c := clampf(v, _speed_min, _speed_max)
	_speed_slider.value = c
	_speed_input.value = c

func get_start_button_x() -> float:
	if _start_button:
		return _start_button.position.x
	return 0.0

func _on_start_pressed() -> void:
	emit_signal("start_requested")

func _on_slider_changed(v: float) -> void:
	if _locked:
		_speed_slider.value = clampf(_speed_slider.value, _speed_min, _speed_max)
		return
	var c := clampf(v, _speed_min, _speed_max)
	if absf(_speed_input.value - c) > 1e-4:
		_speed_input.value = c
	emit_signal("speed_changed", c)

func _on_input_changed(v: float) -> void:
	if _locked:
		_speed_input.value = clampf(_speed_input.value, _speed_min, _speed_max)
		return
	var c := clampf(v, _speed_min, _speed_max)
	if absf(_speed_slider.value - c) > 1e-4:
		_speed_slider.value = c
	emit_signal("speed_changed", c)
