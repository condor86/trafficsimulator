extends RefCounted
class_name TrafficUILightTable

signal lights_changed

const DIST_ROW_IDX := 4
const DIST_MIN_GAP := 50.0
const DIST_MAX_D := 3000.0

const _ROW_TITLES := [
	"绿灯间隔(s)",
	"红灯间隔(s)",
	"初始状态",
	"初始时间(s)",
	"距离起点(m)"
]
const _COL_TITLES := ["A", "B", "C", "D"]

# 默认值，和你原来的一样
const DEF_GREEN := [30.0, 30.0, 30.0, 30.0]
const DEF_RED   := [30.0, 30.0, 30.0, 30.0]
const DEF_STATE := [0, 1, 1, 1]      # A 绿，BCD 红
const DEF_ELAP  := [0.0, 0.0, 20.0, 20.0]
const DEF_DIST  := [0.0, 800.0, 1400.0, 2400.0]

var _owner: Control
var _panel: Panel
var _title_bg: ColorRect
var _title: Label
var _grid: GridContainer
var _fields: Array = []     # 5 × 4

var _reset_btn: Button      # 新增按钮

var _table_border: Rect2 = Rect2()
var _locked: bool = false
var _updating: bool = false

func _init(owner: Control) -> void:
	_owner = owner
	_build_table()
	_hide_legacy_light_panels()

func _build_table() -> void:
	_title_bg = ColorRect.new()
	_title_bg.name = "LightTitleBG"
	_title_bg.color = Color(1, 1, 1, 0.75)
	_owner.add_child(_title_bg)

	_title = Label.new()
	_title.text = "红绿灯设置修改"
	_title.add_theme_font_size_override("font_size", 20)
	_owner.add_child(_title)

	_panel = Panel.new()
	_panel.name = "LightTable"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.size = Vector2(420, 210)
	_owner.add_child(_panel)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.custom_minimum_size = Vector2(400, 190)
	_panel.add_child(_grid)

	# 第一行：空 + A/B/C/D
	var empty_lbl := Label.new()
	empty_lbl.text = ""
	empty_lbl.add_theme_font_size_override("font_size", 20)
	_grid.add_child(empty_lbl)
	for c in _COL_TITLES:
		var lbl := Label.new()
		lbl.text = c
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.modulate = Color(1, 1, 1)
		_grid.add_child(lbl)

	_fields.clear()

	for row_idx in range(_ROW_TITLES.size()):
		var row_arr := []

		var row_lbl := Label.new()
		row_lbl.text = _ROW_TITLES[row_idx]
		row_lbl.add_theme_font_size_override("font_size", 18)
		_grid.add_child(row_lbl)

		for col_idx in range(_COL_TITLES.size()):
			var node: Control
			if row_idx == 2:
				var ob := OptionButton.new()
				ob.add_item("绿", 0)
				ob.add_item("红", 1)
				ob.custom_minimum_size = Vector2(70, 26)
				ob.add_theme_font_size_override("font_size", 18)
				ob.item_selected.connect(_on_state_selected.bind(row_idx, col_idx))
				_grid.add_child(ob)
				node = ob
			elif row_idx == DIST_ROW_IDX:
				var le_dist := LineEdit.new()
				le_dist.custom_minimum_size = Vector2(70, 26)
				le_dist.add_theme_font_size_override("font_size", 18)
				if col_idx == 0:
					le_dist.text = "0"
					le_dist.editable = false
				else:
					le_dist.text = "800"
					le_dist.text_submitted.connect(_on_distance_submitted.bind(col_idx))
					le_dist.focus_exited.connect(_on_distance_focus_exited.bind(col_idx))
				_grid.add_child(le_dist)
				node = le_dist
			else:
				var le := LineEdit.new()
				le.custom_minimum_size = Vector2(70, 26)
				le.add_theme_font_size_override("font_size", 18)
				le.text_changed.connect(_on_light_line_changed.bind(row_idx, col_idx))
				_grid.add_child(le)
				node = le
			row_arr.append(node)
		_fields.append(row_arr)

	# —— 默认值 —— 
	_apply_defaults_to_fields()

	# —— 新增：重置按钮（先创建，不定位，等 layout_for_intersections 给坐标） —— 
	_reset_btn = Button.new()
	_reset_btn.text = "重置红绿灯设置"
	_reset_btn.size = Vector2(160, 48)
	_reset_btn.add_theme_font_size_override("font_size", 16)
	_reset_btn.pressed.connect(_on_reset_pressed)
	_owner.add_child(_reset_btn)

	_table_border = Rect2(
		_panel.position.x,
		_panel.position.y - 32.0,
		_panel.size.x,
		_panel.size.y + 32.0
	)
	_owner.queue_redraw()

func layout_for_intersections(road_y: float, tick_size: float, start_btn_x: float) -> void:
	if not _panel:
		return
	var panel_x: float = 24.0
	var panel_y: float = road_y + tick_size + 90.0
	_panel.position = Vector2(panel_x, panel_y)

	_title_bg.position = Vector2(panel_x, panel_y - 32.0)
	_title_bg.size = Vector2(_panel.size.x, 28.0)

	_title.position = Vector2(panel_x, panel_y - 30.0)
	_title.size = Vector2(_panel.size.x, 26.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color.BLACK)

	# ✔ 新按钮：在表格右边，x 用上面 start 按钮的 x，y 和表格顶对齐
	if _reset_btn:
		var btn_x := start_btn_x
		if btn_x <= 0.0:
			# 万一拿不到，就放在表格右侧稍微右一点
			btn_x = panel_x + _panel.size.x + 24.0
		var btn_y := panel_y
		_reset_btn.position = Vector2(btn_x, btn_y)

	_table_border = Rect2(Vector2(panel_x, panel_y - 32.0), Vector2(_panel.size.x, _panel.size.y + 32.0))
	_owner.queue_redraw()

# 恢复成“永远显示”
func set_show_light_panels(_show: bool) -> void:
	if _panel:
		_panel.visible = true
	if _title_bg:
		_title_bg.visible = true
	if _title:
		_title.visible = true
	if _reset_btn:
		_reset_btn.visible = true

func set_distances_from_root(dists: Array) -> void:
	if _fields.size() <= DIST_ROW_IDX:
		return
	var dist_row = _fields[DIST_ROW_IDX]
	_updating = true
	(dist_row[0] as LineEdit).text = "0"
	if dists.size() >= 2:
		(dist_row[1] as LineEdit).text = str(roundi(dists[1]))
		_clamp_single_col(1)
	if dists.size() >= 3:
		(dist_row[2] as LineEdit).text = str(roundi(dists[2]))
		_clamp_single_col(2)
	if dists.size() >= 4:
		(dist_row[3] as LineEdit).text = str(roundi(dists[3]))
		_clamp_single_col(3)
	_updating = false

func read_all_distances() -> Array:
	var res := [0.0, 800.0, 1400.0, 2400.0]
	if _fields.size() <= DIST_ROW_IDX:
		return res
	var dist_row = _fields[DIST_ROW_IDX]
	res[1] = _to_nonneg((dist_row[1] as LineEdit).text, 800.0)
	res[2] = _to_nonneg((dist_row[2] as LineEdit).text, 1400.0)
	res[3] = _to_nonneg((dist_row[3] as LineEdit).text, 2400.0)
	return res

func read_all_lights() -> Array:
	var res := []
	for col_idx in range(_COL_TITLES.size()):
		var le_g := _fields[0][col_idx] as LineEdit
		var le_r := _fields[1][col_idx] as LineEdit
		var ob_st := _fields[2][col_idx] as OptionButton
		var le_el := _fields[3][col_idx] as LineEdit

		var g_val: float = _to_pos(le_g.text, 30.0)
		var r_val: float = _to_pos(le_r.text, 30.0)
		var el_val: float = _to_nonneg(le_el.text, 0.0)
		var st_val: int = LightConfig.LightState.GREEN
		if ob_st.selected == 1:
			st_val = LightConfig.LightState.RED

		var cfg := LightConfig.new(g_val, r_val, st_val, el_val)
		res.append(cfg)
	return res

func set_running(is_running: bool) -> void:
	_locked = is_running
	for row in _fields:
		for ctrl in row:
			if ctrl is LineEdit:
				var le := ctrl as LineEdit
				if le == _fields[DIST_ROW_IDX][0]:
					le.editable = false
				else:
					le.editable = not is_running
			elif ctrl is OptionButton:
				(ctrl as OptionButton).disabled = is_running
	if _reset_btn:
		_reset_btn.disabled = is_running

# ——— 信号回调 ———
func _on_light_line_changed(_t: String, row_idx: int, _col_idx: int) -> void:
	if _locked:
		return
	if row_idx == DIST_ROW_IDX:
		return
	emit_signal("lights_changed")

func _on_state_selected(_i: int, _row_idx: int, _col_idx: int) -> void:
	if _locked:
		return
	emit_signal("lights_changed")

func _on_distance_submitted(_t: String, col_idx: int) -> void:
	if _locked:
		return
	if col_idx == 0:
		return
	_updating = true
	_clamp_single_col(col_idx)
	_updating = false
	emit_signal("lights_changed")

func _on_distance_focus_exited(col_idx: int) -> void:
	if _locked:
		return
	if col_idx == 0:
		return
	_updating = true
	_clamp_single_col(col_idx)
	_updating = false
	emit_signal("lights_changed")

# ✔ 新加的：一键恢复
func _on_reset_pressed() -> void:
	if _locked:
		return
	_updating = true
	_apply_defaults_to_fields()
	_updating = false
	emit_signal("lights_changed")

# —— 工具 —— 
func _apply_defaults_to_fields() -> void:
	# 绿/红/状态/初始时间
	for col in range(4):
		(_fields[0][col] as LineEdit).text = str(int(DEF_GREEN[col]))
		(_fields[1][col] as LineEdit).text = str(int(DEF_RED[col]))
		(_fields[2][col] as OptionButton).selected = DEF_STATE[col]
		(_fields[3][col] as LineEdit).text = str(DEF_ELAP[col])
	# 距离
	var dist_row = _fields[DIST_ROW_IDX]
	for col in range(4):
		(dist_row[col] as LineEdit).text = str(roundi(DEF_DIST[col]))
	# 按各自的列再 clamp 一次，保证合法
	_clamp_single_col(1)
	_clamp_single_col(2)
	_clamp_single_col(3)

func _clamp_single_col(col_idx: int) -> void:
	if _fields.size() <= DIST_ROW_IDX:
		return
	var dist_row = _fields[DIST_ROW_IDX]

	var a := 0.0
	var b := _to_nonneg((dist_row[1] as LineEdit).text, 800.0)
	var c := _to_nonneg((dist_row[2] as LineEdit).text, 1400.0)
	var d := _to_nonneg((dist_row[3] as LineEdit).text, 2400.0)

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

func _hide_legacy_light_panels() -> void:
	var names = [
		"LightA", "LightB", "LightC", "LightD",
		"PanelA", "PanelB", "PanelC", "PanelD"
	]
	for n in names:
		var nd := _owner.get_node_or_null(n)
		if nd:
			nd.visible = false

func _to_pos(txt: String, fallback: float) -> float:
	var v := float(txt)
	if v <= 0.0:
		v = fallback
	return maxf(v, 0.1)

func _to_nonneg(txt: String, fallback: float) -> float:
	var v := float(txt)
	if v < 0.0:
		v = fallback
	return v
