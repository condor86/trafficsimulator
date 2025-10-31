extends Control
class_name TrafficUIPlot

# 每个样本：{ "t": float, "d": float, "red": bool }
var _samples: Array = []
var _signal_dists: PackedFloat32Array = PackedFloat32Array()

var _max_time: float = 30.0
var _max_dist: float = 10.0

var _plot_size: Vector2 = Vector2(360, 200)
var _margin_left: float = 48.0
var _margin_right: float = 12.0
var _margin_top: float = 18.0
var _margin_bottom: float = 28.0

var _axes_locked: bool = false

const SPLIT_10_TO_20: float = 140.0
const SPLIT_20_TO_50: float = 200.0

# 用和 traffic_root 里一致的颜色
const COL_LINE_GREEN := Color(0.25, 0.85, 0.30, 0.95)
const COL_LINE_RED   := Color(0.95, 0.20, 0.20, 0.95)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func layout_for_intersections(road_y: float, tick_size: float) -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var x: float = sz.x - _plot_size.x - 24.0
	var y: float = road_y + tick_size + 90.0
	position = Vector2(x, y)
	size = _plot_size
	queue_redraw()

func reset_plot() -> void:
	_samples.clear()
	queue_redraw()

func lock_axes(max_time: float, max_dist: float, dists: Array) -> void:
	_axes_locked = true
	_max_time = max(max_time, 1.0)
	_max_dist = max(max_dist, 1.0)

	_signal_dists = PackedFloat32Array()
	for v in dists:
		_signal_dists.append(float(v))
	queue_redraw()

func unlock_axes() -> void:
	_axes_locked = false
	queue_redraw()

func set_signal_distances(dists: Array) -> void:
	if _axes_locked:
		_signal_dists = PackedFloat32Array()
		for v in dists:
			_signal_dists.append(float(v))
		queue_redraw()
		return

	_signal_dists = PackedFloat32Array()
	var maxv: float = 0.0
	for v in dists:
		var fv: float = float(v)
		_signal_dists.append(fv)
		if fv > maxv:
			maxv = fv
	_max_dist = max(_max_dist, maxv + 10.0)
	queue_redraw()

# 带状态的新增入口
func add_sample(t_sec: float, dist_m: float, is_red: bool) -> void:
	var rec := {
		"t": float(t_sec),
		"d": float(dist_m),
		"red": bool(is_red)
	}
	_samples.append(rec)

	if not _axes_locked:
		if t_sec > _max_time - 1.0:
			_max_time = t_sec + 5.0
		if dist_m > _max_dist - 1.0:
			_max_dist = dist_m + 10.0

	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0, 0, 0, 0.45), true)
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

	# —— 横轴刻度：三档，全覆盖 —— 
	var step_x: float = 10.0
	if _max_time > SPLIT_20_TO_50 + 0.1:
		step_x = 50.0
	elif _max_time > SPLIT_10_TO_20 + 0.1:
		step_x = 20.0

	var t0: float = 0.0
	while t0 <= _max_time + 0.1:
		var x_rel: float = (t0 / _max_time) * plot_w
		var x_pos: float = origin.x + x_rel
		_draw_x_tick(font, x_pos, origin.y, int(t0))
		t0 += step_x

	# —— 纵轴刻度：A/B/C/D —— 
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

	# —— 曲线：按段着色 —— 
	if _samples.size() >= 2:
		for i in range(_samples.size() - 1):
			var a: Dictionary = _samples[i]
			var b: Dictionary = _samples[i + 1]

			var ax: float = origin.x + (a["t"] / _max_time) * plot_w
			var ay: float = origin.y - (a["d"] / _max_dist) * plot_h
			var bx: float = origin.x + (b["t"] / _max_time) * plot_w
			var by: float = origin.y - (b["d"] / _max_dist) * plot_h

			var col: Color = COL_LINE_GREEN
			if bool(a["red"]):
				col = COL_LINE_RED

			draw_line(Vector2(ax, ay), Vector2(bx, by), col, 2.0)
	elif _samples.size() == 1:
		var s0: Dictionary = _samples[0]
		var xx0: float = origin.x + (s0["t"] / _max_time) * plot_w
		var yy0: float = origin.y - (s0["d"] / _max_dist) * plot_h
		var col0: Color = COL_LINE_GREEN
		if bool(s0["red"]):
			col0 = COL_LINE_RED
		draw_circle(Vector2(xx0, yy0), 2.0, col0)

func _draw_x_tick(font: Font, x_pos: float, base_y: float, label_val: int) -> void:
	draw_line(
		Vector2(x_pos, base_y),
		Vector2(x_pos, base_y + 4.0),
		Color(1, 1, 1, 0.35),
		1.0
	)
	draw_string(
		font,
		Vector2(x_pos - 6.0, base_y + 16.0),
		str(label_val),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color(1, 1, 1, 0.75)
	)
