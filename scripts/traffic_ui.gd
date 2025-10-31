extends Control
class_name TrafficUI

signal start_pressed
signal speed_changed(new_speed: float)
signal lights_changed

@export var speed_min_mps: float = 5.0
@export var speed_max_mps: float = 23.0

const DEFAULT_SPEED := 20.0

# 距离行配置
const DIST_ROW_IDX := 4
const DIST_MIN_GAP := 50.0
const DIST_MAX_D := 3000.0

var start_button: Button
var speed_label: Label
var speed_slider: HSlider
var speed_input: SpinBox

var _light_title_bg: ColorRect
var _light_title: Label
var _light_panel: Panel
var _light_grid: GridContainer
var _light_fields: Array = []     # 5 行，每行 4 个控件

var _table_border_rect: Rect2 = Rect2()
var _locked_during_run: bool = false
var _updating_distances: bool = false

const _ROW_TITLES = [
	"绿灯间隔(s)",
	"红灯间隔(s)",
	"初始状态",
	"初始时间(s)",
	"距离起点(m)"
]
const _COL_TITLES = ["A", "B", "C", "D"]

func _ready() -> void:
	# 顶部控件
	start_button = get_node_or_null("StartButton") as Button
	if start_button == null:
		start_button = Button.new()
		start_button.name = "StartButton"
		add_child(start_button)

	speed_label = get_node_or_null("SpeedLabel") as Label
	if speed_label == null:
		speed_label = Label.new()
		speed_label.name = "SpeedLabel"
		add_child(speed_label)

	speed_slider = get_node_or_null("SpeedSlider") as HSlider
	if speed_slider == null:
		speed_slider = HSlider.new()
		speed_slider.name = "SpeedSlider"
		add_child(speed_slider)

	speed_input = get_node_or_null("SpeedInput") as SpinBox
	if speed_input == null:
		speed_input = SpinBox.new()
		speed_input.name = "SpeedInput"
		add_child(speed_input)

	_ensure_speed_controls()
	_ensure_light_table()
	_hide_legacy_light_panels()

	# 信号
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not speed_slider.value_changed.is_connected(_on_speed_slider_changed):
		speed_slider.value_changed.connect(_on_speed_slider_changed)
	if not speed_input.value_changed.is_connected(_on_speed_input_changed):
		speed_input.value_changed.connect(_on_speed_input_changed)

	# 默认速度
	var def := clampf(DEFAULT_SPEED, speed_min_mps, speed_max_mps)
	speed_slider.value = def
	speed_input.value = def

func _ensure_speed_controls() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	start_button.text = "开始"
	start_button.size = Vector2(160, 48)
	start_button.add_theme_font_size_override("font_size", 30)

	speed_label.text = "速度"
	speed_label.modulate = Color(0.2, 0.2, 0.2)
	speed_label.add_theme_font_size_override("font_size", 26)

	speed_slider.min_value = speed_min_mps
	speed_slider.max_value = speed_max_mps
	speed_slider.step = 0.5
	if speed_slider.size.x < 380.0:
		speed_slider.size = Vector2(420, 20)

	speed_input.min_value = speed_min_mps
	speed_input.max_value = speed_max_mps
	speed_input.step = 0.5
	speed_input.suffix = " m/s"
	speed_input.size = Vector2(110, 28)
	speed_input.add_theme_font_size_override("font_size", 22)

func layout_for_intersections(intersections: PackedFloat32Array, road_y: float, tick_size: float) -> void:
	# 顶部一排
	if intersections.size() >= 2:
		var left_x: float = intersections[0]
		var right_x: float = intersections[intersections.size() - 1]
		var center_x: float = (left_x + right_x) * 0.5
		var row_up_y: float = road_y - tick_size - 100.0

		var sl_w: float = maxf(speed_slider.size.x, 420.0)
		speed_slider.size = Vector2(sl_w, 20.0)
		speed_slider.position = Vector2(center_x - sl_w * 0.5, row_up_y)

		var lbl_w: float = 80.0
		speed_label.position = Vector2(
			speed_slider.position.x - lbl_w - 16.0,
			row_up_y - 4.0
		)
		speed_label.size = Vector2(lbl_w, 30.0)

		start_button.size = Vector2(160, 48)
		start_button.position = Vector2(
			center_x - 160 * 0.5,
			row_up_y - (48 + 16.0)
		)

		speed_input.position = Vector2(
			speed_slider.position.x + speed_slider.size.x + 14.0,
			row_up_y - 4.0
		)

	# 下方表格
	if _light_panel:
		var panel_x: float = 24.0
		var panel_y: float = road_y + tick_size + 90.0
		_light_panel.position = Vector2(panel_x, panel_y)

		if _light_title_bg:
			_light_title_bg.position = Vector2(panel_x, panel_y - 32.0)
			_light_title_bg.size = Vector2(_light_panel.size.x, 28.0)
			_light_title_bg.color = Color(1, 1, 1, 0.75)
			_light_title_bg.visible = true

		if _light_title:
			_light_title.position = Vector2(panel_x, panel_y - 30.0)
			_light_title.size = Vector2(_light_panel.size.x, 26.0)
			_light_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_light_title.add_theme_color_override("font_color", Color.BLACK)

		var border_top: float = panel_y - 32.0
		var border_left: float = panel_x
		var border_w: float = _light_panel.size.x
		var border_h: float = _light_panel.size.y + 32.0
		_table_border_rect = Rect2(Vector2(border_left, border_top), Vector2(border_w, border_h))
		queue_redraw()

func _on_start_pressed() -> void:
	emit_signal("start_pressed")

func _on_speed_slider_changed(v: float) -> void:
	if _locked_during_run:
		speed_slider.value = clampf(speed_slider.value, speed_min_mps, speed_max_mps)
		return
	var clamped := clampf(v, speed_min_mps, speed_max_mps)
	if absf(speed_input.value - clamped) > 1e-4:
		speed_input.value = clamped
	emit_signal("speed_changed", clamped)

func _on_speed_input_changed(v: float) -> void:
	if _locked_during_run:
		speed_input.value = clampf(speed_input.value, speed_min_mps, speed_max_mps)
		return
	var clamped := clampf(v, speed_min_mps, speed_max_mps)
	if absf(speed_slider.value - clamped) > 1e-4:
		speed_slider.value = clamped
	emit_signal("speed_changed", clamped)

# —— 创建表格 —— 
func _ensure_light_table() -> void:
	if _light_panel:
		return

	_light_title_bg = ColorRect.new()
	_light_title_bg.name = "LightTitleBG"
	_light_title_bg.color = Color(1, 1, 1, 0.75)
	add_child(_light_title_bg)

	_light_title = Label.new()
	_light_title.text = "红绿灯设置修改"
	_light_title.add_theme_font_size_override("font_size", 20)
	add_child(_light_title)

	_light_panel = Panel.new()
	_light_panel.name = "LightTable"
	add_child(_light_panel)
	_light_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_light_panel.size = Vector2(420, 210)

	_light_grid = GridContainer.new()
	_light_grid.columns = 5
	_light_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_light_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_light_grid.custom_minimum_size = Vector2(400, 190)
	_light_panel.add_child(_light_grid)

	# 第一行：空 + A/B/C/D
	var empty_lbl := Label.new()
	empty_lbl.text = ""
	empty_lbl.add_theme_font_size_override("font_size", 20)
	_light_grid.add_child(empty_lbl)

	for col_name in _COL_TITLES:
		var lbl := Label.new()
		lbl.text = col_name
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.modulate = Color(1, 1, 1)
		_light_grid.add_child(lbl)

	_light_fields.clear()

	for row_idx in range(_ROW_TITLES.size()):
		var row_arr := []

		var row_lbl := Label.new()
		row_lbl.text = _ROW_TITLES[row_idx]
		row_lbl.add_theme_font_size_override("font_size", 18)
		_light_grid.add_child(row_lbl)

		for col_idx in range(_COL_TITLES.size()):
			var node: Control
			if row_idx == 2:
				# 初始状态 → 下拉
				var ob := OptionButton.new()
				ob.add_item("绿", 0)
				ob.add_item("红", 1)
				ob.custom_minimum_size = Vector2(70, 26)
				ob.add_theme_font_size_override("font_size", 18)
				ob.item_selected.connect(_on_light_state_selected.bind(row_idx, col_idx))
				_light_grid.add_child(ob)
				node = ob
			elif row_idx == DIST_ROW_IDX:
				# 距离起点(m)
				var le_dist := LineEdit.new()
				le_dist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le_dist.custom_minimum_size = Vector2(70, 26)
				le_dist.add_theme_font_size_override("font_size", 18)
				if col_idx == 0:
					le_dist.text = "0"
					le_dist.editable = false
				else:
					le_dist.text = "800"
					# ✔ 这里带上列号
					le_dist.text_submitted.connect(_on_distance_cell_submitted.bind(col_idx))
					le_dist.focus_exited.connect(_on_distance_cell_focus_exited.bind(col_idx))
				_light_grid.add_child(le_dist)
				node = le_dist
			else:
				# 普通数值
				var le := LineEdit.new()
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le.custom_minimum_size = Vector2(70, 26)
				le.add_theme_font_size_override("font_size", 18)
				le.text_changed.connect(_on_light_line_changed.bind(row_idx, col_idx))
				_light_grid.add_child(le)
				node = le
			row_arr.append(node)
		_light_fields.append(row_arr)

	# 默认值
	(_light_fields[0][0] as LineEdit).text = "30"
	(_light_fields[1][0] as LineEdit).text = "30"
	(_light_fields[2][0] as OptionButton).selected = 0
	(_light_fields[3][0] as LineEdit).text = "0"

	(_light_fields[0][1] as LineEdit).text = "30"
	(_light_fields[1][1] as LineEdit).text = "30"
	(_light_fields[2][1] as OptionButton).selected = 1
	(_light_fields[3][1] as LineEdit).text = "0"

	(_light_fields[0][2] as LineEdit).text = "30"
	(_light_fields[1][2] as LineEdit).text = "30"
	(_light_fields[2][2] as OptionButton).selected = 1
	(_light_fields[3][2] as LineEdit).text = "20"

	(_light_fields[0][3] as LineEdit).text = "30"
	(_light_fields[1][3] as LineEdit).text = "30"
	(_light_fields[2][3] as OptionButton).selected = 1
	(_light_fields[3][3] as LineEdit).text = "20"

	# 距离行初始
	var dist_row = _light_fields[DIST_ROW_IDX]
	(dist_row[0] as LineEdit).text = "0"
	(dist_row[1] as LineEdit).text = "800"
	(dist_row[2] as LineEdit).text = "1400"
	(dist_row[3] as LineEdit).text = "2400"

	_table_border_rect = Rect2(
		_light_panel.position.x,
		_light_panel.position.y - 32.0,
		_light_panel.size.x,
		_light_panel.size.y + 32.0
	)
	queue_redraw()

# —— 普通数值行变更 —— 
func _on_light_line_changed(_new_text: String, row_idx: int, _col_idx: int) -> void:
	if _locked_during_run:
		return
	if row_idx == DIST_ROW_IDX:
		return
	emit_signal("lights_changed")

# —— 距离行：按回车 —— 
func _on_distance_cell_submitted(_text: String, col_idx: int) -> void:
	if _locked_during_run:
		return
	if col_idx == 0:
		return
	_updating_distances = true
	_apply_single_distance_clamp(col_idx)
	_updating_distances = false
	emit_signal("lights_changed")

# —— 距离行：失焦 —— 
func _on_distance_cell_focus_exited(col_idx: int) -> void:
	if _locked_during_run:
		return
	if col_idx == 0:
		return
	_updating_distances = true
	_apply_single_distance_clamp(col_idx)
	_updating_distances = false
	emit_signal("lights_changed")

# ✔ 关键改动：只 clamp 当前列，不去动别的
func _apply_single_distance_clamp(col_idx: int) -> void:
	if _light_fields.size() <= DIST_ROW_IDX:
		return
	var dist_row = _light_fields[DIST_ROW_IDX]

	var a := 0.0
	var b := _to_nonneg_time((dist_row[1] as LineEdit).text, 800.0)
	var c := _to_nonneg_time((dist_row[2] as LineEdit).text, 1400.0)
	var d := _to_nonneg_time((dist_row[3] as LineEdit).text, 2400.0)

	match col_idx:
		1:
			var min_b = a + DIST_MIN_GAP
			var max_b = minf(c - DIST_MIN_GAP, DIST_MAX_D)
			if max_b < min_b:
				b = minf(min_b, DIST_MAX_D)
			else:
				b = clampf(b, min_b, max_b)
			(dist_row[1] as LineEdit).text = str(roundi(b))
		2:
			var min_c = b + DIST_MIN_GAP
			var max_c = minf(d - DIST_MIN_GAP, DIST_MAX_D)
			if max_c < min_c:
				c = minf(min_c, DIST_MAX_D)
			else:
				c = clampf(c, min_c, max_c)
			(dist_row[2] as LineEdit).text = str(roundi(c))
		3:
			var min_d = c + DIST_MIN_GAP
			d = clampf(d, min_d, DIST_MAX_D)
			(dist_row[3] as LineEdit).text = str(roundi(d))

func _on_light_state_selected(_idx: int, _row_idx: int, _col_idx: int) -> void:
	if _locked_during_run:
		return
	emit_signal("lights_changed")

# —— root 写进来时，也按单元格各自 clamp —— 
func set_distances_from_root(dists: Array) -> void:
	if _light_fields.size() <= DIST_ROW_IDX:
		return
	var dist_row = _light_fields[DIST_ROW_IDX]
	_updating_distances = true
	(dist_row[0] as LineEdit).text = "0"
	if dists.size() >= 2:
		(dist_row[1] as LineEdit).text = str(roundi(dists[1]))
		_apply_single_distance_clamp(1)
	if dists.size() >= 3:
		(dist_row[2] as LineEdit).text = str(roundi(dists[2]))
		_apply_single_distance_clamp(2)
	if dists.size() >= 4:
		(dist_row[3] as LineEdit).text = str(roundi(dists[3]))
		_apply_single_distance_clamp(3)
	_updating_distances = false

# —— root 读当前 UI 的距离 —— 
func read_all_distances() -> Array:
	var res := [0.0, 800.0, 1400.0, 2400.0]
	if _light_fields.size() <= DIST_ROW_IDX:
		return res
	var dist_row = _light_fields[DIST_ROW_IDX]
	res[0] = 0.0
	res[1] = _to_nonneg_time((dist_row[1] as LineEdit).text, 800.0)
	res[2] = _to_nonneg_time((dist_row[2] as LineEdit).text, 1400.0)
	res[3] = _to_nonneg_time((dist_row[3] as LineEdit).text, 2400.0)
	return res

func read_all_lights() -> Array:
	var res := []
	for col_idx in range(_COL_TITLES.size()):
		var le_g := _light_fields[0][col_idx] as LineEdit
		var le_r := _light_fields[1][col_idx] as LineEdit
		var ob_st := _light_fields[2][col_idx] as OptionButton
		var le_el := _light_fields[3][col_idx] as LineEdit

		var g_val: float = _to_pos_time(le_g.text, 30.0)
		var r_val: float = _to_pos_time(le_r.text, 30.0)
		var el_val: float = _to_nonneg_time(le_el.text, 0.0)

		var st_val: int = LightConfig.LightState.GREEN
		if ob_st.selected == 1:
			st_val = LightConfig.LightState.RED

		var cfg := LightConfig.new(g_val, r_val, st_val, el_val)
		res.append(cfg)
	return res

func set_show_light_panels(_show: bool) -> void:
	pass

func set_running(is_running: bool) -> void:
	_locked_during_run = is_running

	start_button.disabled = is_running
	speed_slider.editable = not is_running
	speed_slider.mouse_filter = Control.MOUSE_FILTER_PASS if not is_running else Control.MOUSE_FILTER_IGNORE
	speed_input.editable = not is_running

	_set_light_table_editable(not is_running)

	if is_running:
		start_button.text = "运行中..."
	else:
		start_button.text = "开始"

func get_speed_mps() -> float:
	return clampf(speed_slider.value, speed_min_mps, speed_max_mps)

func _set_light_table_editable(en: bool) -> void:
	for row in _light_fields:
		for ctrl in row:
			if ctrl is LineEdit:
				var le := ctrl as LineEdit
				le.editable = (le.editable and en)
			elif ctrl is OptionButton:
				(ctrl as OptionButton).disabled = not en

func _hide_legacy_light_panels() -> void:
	var names = [
		"LightA", "LightB", "LightC", "LightD",
		"PanelA", "PanelB", "PanelC", "PanelD"
	]
	for n in names:
		var nd := get_node_or_null(n)
		if nd:
			nd.visible = false

func _draw() -> void:
	if _table_border_rect.size.x > 0.0 and _table_border_rect.size.y > 0.0:
		draw_rect(_table_border_rect, Color(1, 1, 1, 1), false, 1.0)

# —— 工具 —— 
func _to_pos_time(txt: String, fallback: float) -> float:
	var v := float(txt)
	if v <= 0.0:
		v = fallback
	return maxf(v, 0.1)

func _to_nonneg_time(txt: String, fallback: float) -> float:
	var v := float(txt)
	if v < 0.0:
		v = fallback
	return v
