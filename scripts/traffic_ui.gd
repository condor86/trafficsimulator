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

func _ready() -> void:
	# 上面那排
	_topbar = TrafficUITopBar.new(self, speed_min_mps, speed_max_mps, DEFAULT_SPEED)
	_topbar.start_requested.connect(func ():
		emit_signal("start_pressed")
	)
	_topbar.speed_changed.connect(func (v: float):
		emit_signal("speed_changed", v)
	)

	# 下面那张表
	_light_table = TrafficUILightTable.new(self)
	_light_table.lights_changed.connect(func ():
		emit_signal("lights_changed")
	)

func layout_for_intersections(intersections: PackedFloat32Array, road_y: float, tick_size: float) -> void:
	if _topbar:
		_topbar.layout_for_intersections(intersections, road_y, tick_size)
	if _light_table:
		_light_table.layout_for_intersections(road_y, tick_size)

func set_show_light_panels(show: bool) -> void:
	if _light_table:
		_light_table.set_show_light_panels(show)

func set_distances_from_root(dists: Array) -> void:
	if _light_table:
		_light_table.set_distances_from_root(dists)

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

# ✔ 给 root 专用的设置接口，避免它去碰内部节点
func set_speed_mps(v: float) -> void:
	if _topbar:
		_topbar.set_speed_mps(v)
