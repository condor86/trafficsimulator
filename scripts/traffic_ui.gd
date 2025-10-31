extends Control
class_name TrafficUI

signal start_pressed
signal speed_changed(new_speed: float)
signal lights_changed

@export var speed_min_mps: float = 5.0
@export var speed_max_mps: float = 23.0

const DEFAULT_SPEED := 20.0

var _topbar: TrafficUITopBar
var _light_table: TrafficUILightTable
var _plot: TrafficUIPlot

func _ready() -> void:
	_topbar = TrafficUITopBar.new(self, speed_min_mps, speed_max_mps, DEFAULT_SPEED)
	_topbar.start_requested.connect(func ():
		emit_signal("start_pressed")
	)
	_topbar.speed_changed.connect(func (v: float):
		emit_signal("speed_changed", v)
	)

	_light_table = TrafficUILightTable.new(self)
	_light_table.lights_changed.connect(func ():
		emit_signal("lights_changed")
	)

	_plot = TrafficUIPlot.new()
	add_child(_plot)
	_plot.z_index = 99

func layout_for_intersections(intersections: PackedFloat32Array, road_y: float, tick_size: float) -> void:
	var start_x: float = 0.0
	if _topbar:
		_topbar.layout_for_intersections(intersections, road_y, tick_size)
		start_x = _topbar.get_start_button_x()
	if _light_table:
		_light_table.layout_for_intersections(road_y, tick_size, start_x)
	if _plot:
		_plot.layout_for_intersections(road_y, tick_size)

func set_show_light_panels(_show: bool) -> void:
	if _light_table:
		_light_table.set_show_light_panels(true)

func set_distances_from_root(dists: Array) -> void:
	if _light_table:
		_light_table.set_distances_from_root(dists)
	if _plot:
		_plot.set_signal_distances(dists)

func read_all_distances() -> Array:
	if _light_table:
		return _light_table.read_all_distances()
	return [0.0, 800.0, 1400.0, 2400.0]

func read_all_lights() -> Array:
	if _light_table:
		return _light_table.read_all_lights()
	return []

func set_running(is_running: bool) -> void:
	if _topbar:
		_topbar.set_running(is_running)
	if _light_table:
		_light_table.set_running(is_running)

func get_speed_mps() -> float:
	if _topbar:
		return _topbar.get_speed_mps()
	return DEFAULT_SPEED

func set_speed_mps(v: float) -> void:
	if _topbar:
		_topbar.set_speed_mps(v)

# —— 图表相关 —— 
func reset_plot() -> void:
	if _plot:
		_plot.reset_plot()

func push_plot_sample(t_sec: float, dist_m: float) -> void:
	if _plot:
		_plot.add_sample(t_sec, dist_m, false)

func push_plot_sample_state(t_sec: float, dist_m: float, is_waiting_red: bool) -> void:
	if _plot:
		_plot.add_sample(t_sec, dist_m, is_waiting_red)

func set_plot_signals(dists: Array) -> void:
	if _plot:
		_plot.set_signal_distances(dists)

# ✔ 新增：把灯配置也传给图像
func set_plot_lights(lights: Array) -> void:
	if _plot:
		_plot.set_light_configs(lights)

func lock_plot_axes(max_time: float, max_dist: float, dists: Array) -> void:
	if _plot:
		_plot.lock_axes(max_time, max_dist, dists)

func unlock_plot_axes() -> void:
	if _plot:
		_plot.unlock_axes()
