extends Control
class_name TrafficUIPlot

# 实时曲线：x = 时间(s)，y = 距离(m)

var _samples: Array[Vector2] = []               # (t, d)
var _signal_dists: PackedFloat32Array = PackedFloat32Array()

var _min_x_step: float = 10.0                   # 横轴刻度
var _max_time: float = 30.0                     # 当前坐标系的最大时间
var _max_dist: float = 10.0                     # 当前坐标系的最大距离

var _plot_size: Vector2 = Vector2(360, 200)
var _margin_left: float = 48.0
var _margin_right: float = 12.0
var _margin_top: float = 18.0
var _margin_bottom: float = 28.0

# ✔ 新增：轴是否已锁定
var _axes_locked: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func layout_for_intersections(road_y: float, tick_size: float) -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var x: float = sz.x - _plot_size.x - 24.0
	var y: float = road_y + tick_size + 90.0
	position = Vector2(x, y)
	size = _plot_size
	queue_redraw()

# 仅清曲线，坐标系不一定清 → 方便和“锁轴”配合
func reset_plot() -> void:
	_samples.clear()
	queue_redraw()

# ✔ 新增：在开始那一刻由 root 调用，固定坐标系
func lock_axes(max_time: float, max_dist: float, dists: Array) -> void:
	_axes_locked = true
	_max_time = max(max_time, 1.0)
	_max_dist = max(max_dist, 1.0)

	# 锁的时候也要把 A/B/C/D 同步进去，但不能再据此改 _max_dist
	_signal_dists = PackedFloat32Array()
	for v in dists:
		_signal_dists.append(float(v))
	queue_redraw()

# 可选：root 不跑的时候想恢复成“自适应”
func unlock_axes() -> void:
	_axes_locked = false
	queue_redraw()

# UI 在未运行时改距离会走到这里
func set_signal_distances(dists: Array) -> void:
	if _axes_locked:
		# 轴已锁，只换标签，不改范围
		_signal_dists = PackedFloat32Array()
		for v in dists:
			_signal_dists.append(float(v))
		queue_redraw()
		return

	# 未锁轴 → 自适应
	_signal_dists = PackedFloat32Array()
	var maxv: float = 0.0
	for v in dists:
		var fv: float = float(v)
		_signal_dists.append(fv)
		if fv > maxv:
			maxv = fv
	_max_dist = max(_max_dist, maxv + 10.0)
	queue_redraw()

func add_sample(t_sec: float, dist_m: float) -> void:
	_samples.append(Vector2(t_sec, dist_m))

	if not _axes_locked:
		# 未锁 → 跟随数据放大
		if t_sec > _max_time - 1.0:
			_max_time = t_sec + 5.0
		if dist_m > _max_dist - 1.0:
			_max_dist = dist_m + 10.0

	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# 背景
	draw_rect(rect, Color(0, 0, 0, 0.45), true)
	# 边框
	draw_rect(rect, Color(1, 1, 1, 0.45), false, 1.0)

	var plot_w: float = rect.size.x - _margin_left - _margin_right
	var plot_h: float = rect.size.y - _margin_top - _margin_bottom
	if plot_w <= 0.0 or plot_h <= 0.0:
		return

	var origin := Vector2(_margin_left, rect.size.y - _margin_bottom)

	# 坐标轴
	draw_line(origin, Vector2(origin.x + plot_w, origin.y), Color(1, 1, 1, 0.7), 1.0)
	draw_line(origin, Vector2(origin.x, origin.y - plot_h), Color(1, 1, 1, 0.7), 1.0)

	var font: Font = ThemeDB.fallback_font

	# 横轴刻度：每 10s
	var step_x: float = _min_x_step
	var t0: float = 0.0
	while t0 <= _max_time + 0.1:
		var x_rel: float = (t0 / _max_time) * plot_w
		var x_pos: float = origin.x + x_rel
		draw_line(
			Vector2(x_pos, origin.y),
			Vector2(x_pos, origin.y + 4.0),
			Color(1, 1, 1, 0.35),
			1.0
		)
		draw_string(
			font,
			Vector2(x_pos - 6.0, origin.y + 16.0),
			str(int(t0)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1, 1, 1, 0.75)
		)
		t0 += step_x

	# 纵轴刻度：A/B/C/D
	for i in range(_signal_dists.size()):
		var d: float = _signal_dists[i]
		var y_rel: float = (d / _max_dist) if _max_dist > 1e-6 else 0.0
		var y_pos: float = origin.y - y_rel * plot_h
		draw_line(
			Vector2(origin.x - 4.0, y_pos),
			Vector2(origin.x + plot_w, y_pos),
			Color(1, 1, 1, 0.25),
			1.0
		)
		var label := "A"
		if i == 1: label = "B"
		elif i == 2: label = "C"
		elif i == 3: label = "D"
		draw_string(
			font,
			Vector2(origin.x - 32.0, y_pos + 4.0),
			label + " " + str(int(d)) + "m",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1, 1, 1, 0.8)
		)

	# 曲线
	if _samples.size() >= 2:
		var pts: PackedVector2Array = PackedVector2Array()
		for s: Vector2 in _samples:
			var sx: float = s.x
			var sy: float = s.y
			var xx: float = origin.x + (sx / _max_time) * plot_w
			var yy: float = origin.y - (sy / _max_dist) * plot_h
			pts.append(Vector2(xx, yy))
		draw_polyline(pts, Color(0.2, 1.0, 0.3, 0.95), 2.0, true)
	elif _samples.size() == 1:
		var s0: Vector2 = _samples[0]
		var xx0: float = origin.x + (s0.x / _max_time) * plot_w
		var yy0: float = origin.y - (s0.y / _max_dist) * plot_h
		draw_circle(Vector2(xx0, yy0), 2.0, Color(0.2, 1.0, 0.3, 0.95))
