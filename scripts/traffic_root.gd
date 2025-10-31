extends Node2D

@export var dist_B_from_A_m: float = 800.0
@export var dist_C_from_A_m: float = 1400.0
@export var dist_D_from_A_m: float = 2400.0

@export var speed_default_mps: float = 20.0
@export var speed_min_mps: float = 5.0
@export var speed_max_mps: float = 23.0

@export var default_time_scale: float = 15.0

@export var car_texture_path: String = "res://assets/car.png"
@export var car_size_px: Vector2 = Vector2(75, 75)
@export var car_face_left: bool = false
@export var car_rotation_deg: float = 0.0
@export var car_flip_h: bool = true
@export var car_flip_v: bool = false

@export var show_light_panels: bool = false

@export var road_y: float = 240.0
@export var road_x_start: float = 100.0
@export var road_length: float = 1000.0
@export var tick_size: float = 16.0
@export var light_bulb_radius: float = 8.0

const COL_SKY: Color    = Color(0.45, 0.75, 1.00)
const COL_GROUND: Color = Color(0.08, 0.08, 0.09)
const COL_ROAD: Color   = Color(1, 1, 1)
const COL_GREEN: Color  = Color(0.25, 0.85, 0.30)
const COL_RED: Color    = Color(0.95, 0.20, 0.20)
const COL_TEXT: Color   = Color(1, 1, 1)
const COL_LABEL: Color  = Color(0.2, 0.2, 0.2)

@export var light_housing_w: float = 28.0
@export var light_housing_h: float = 28.0
@export var light_pole_thickness: float = 3.0
@export var light_housing_color: Color = Color(0.10, 0.10, 0.12)
@export var light_pole_color: Color   = Color(0.12, 0.12, 0.12)

const LIGHT_SCALE := 1.5
const DIST_MIN_GAP := 50.0
const DIST_MAX_D := 3000.0

@onready var ui: TrafficUI = $CanvasLayer/UI
@onready var dlg: AcceptDialog = $ResultDialog

var _sim: TrafficSim
var _px_per_meter: float = 1.0
var _intersection_positions: PackedFloat32Array = PackedFloat32Array([0.0, 300.0, 600.0, 900.0])
var _car_sprite: Sprite2D
var _waiting_dialog_unlock: bool = false

func _ready() -> void:
	_init_sim()
	_init_ui()
	_refresh_layout()
	_sync_car_visual()

	if not dlg.confirmed.is_connected(_on_result_confirmed):
		dlg.confirmed.connect(_on_result_confirmed)
	if not get_window().size_changed.is_connected(_on_window_size_changed):
		get_window().size_changed.connect(_on_window_size_changed)

	queue_redraw()

func _init_sim() -> void:
	_sim = TrafficSim.new()
	_sim.set_speed_mps(speed_default_mps)
	_sim.set_time_scale(clampf(default_time_scale, 1.0, 15.0))

func _init_ui() -> void:
	ui.set_show_light_panels(show_light_panels)
	ui.set_distances_from_root([
		0.0,
		dist_B_from_A_m,
		dist_C_from_A_m,
		dist_D_from_A_m
	])
	ui.set_plot_signals([
		0.0,
		dist_B_from_A_m,
		dist_C_from_A_m,
		dist_D_from_A_m
	])

	var lights = ui.read_all_lights()
	_sim.apply_lights(lights)

	var def_spd := clampf(speed_default_mps, speed_min_mps, speed_max_mps)
	ui.set_speed_mps(def_spd)
	_sim.set_speed_mps(def_spd)

	ui.start_pressed.connect(_on_ui_start_pressed)
	ui.lights_changed.connect(_on_ui_lights_changed)
	ui.speed_changed.connect(_on_ui_speed_changed)

	_car_setup_sprite()

func _on_window_size_changed() -> void:
	_refresh_layout()
	queue_redraw()

func _refresh_layout() -> void:
	_auto_layout_positions()
	ui.layout_for_intersections(_intersection_positions, road_y, tick_size)
	_sim.setup_layout(_intersection_positions, _px_per_meter, road_y)

func _auto_layout_positions() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	road_y = floor(sz.y * 0.5)

	var left_margin: float = 80.0
	var right_margin: float = 80.0
	var usable_w: float = maxf(sz.x - left_margin - right_margin, 200.0)

	var dists = PackedFloat32Array([0.0, dist_B_from_A_m, dist_C_from_A_m, dist_D_from_A_m])
	var max_dist: float = maxf(dists[0], maxf(dists[1], maxf(dists[2], dists[3])))
	if max_dist <= 0.0:
		max_dist = 1.0

	_px_per_meter = usable_w / max_dist

	var center_x: float = sz.x * 0.5
	var x_left: float = center_x - usable_w * 0.5

	road_x_start = center_x - usable_w * 0.5 - 20.0
	road_length  = usable_w + 40.0

	_intersection_positions.resize(4)
	for i in range(4):
		_intersection_positions[i] = x_left + dists[i] * _px_per_meter

func _process(delta: float) -> void:
	if _sim and _sim.running:
		var r = _sim.step(delta)

		# 像素 → 米
		var car_m: float = 0.0
		if _intersection_positions.size() > 0:
			car_m = (_sim.car_x - _intersection_positions[0]) / _px_per_meter
			if car_m < 0.0:
				car_m = 0.0

		# ✔ 把“当前是否在等红灯”一并传给 UI
		var is_waiting: bool = _sim.waiting_at_red
		ui.push_plot_sample_state(_sim.t, car_m, is_waiting)

		if r["finished"]:
			_finish(true)

	_sync_car_visual()
	queue_redraw()

func _on_ui_start_pressed() -> void:
	_apply_ui_to_model()

	var cur_speed: float = ui.get_speed_mps()
	cur_speed = clampf(cur_speed, speed_min_mps, speed_max_mps)
	if cur_speed <= 0.01:
		cur_speed = speed_min_mps

	var dists_now: Array = [
		0.0,
		dist_B_from_A_m,
		dist_C_from_A_m,
		dist_D_from_A_m
	]

	var est_dist_max: float = dist_D_from_A_m + 50.0

	var est_time_max: float = (dist_D_from_A_m + 200.0) / cur_speed
	est_time_max *= 1.25
	if est_time_max < 30.0:
		est_time_max = 30.0

	ui.reset_plot()
	ui.lock_plot_axes(est_time_max, est_dist_max, dists_now)
	# ✔ 起始是绿的（不等待）
	ui.push_plot_sample_state(0.0, 0.0, false)

	_sim.reset()
	_sim.set_time_scale(clampf(default_time_scale, 1.0, 15.0))
	_sim.start()
	ui.set_running(true)
	_waiting_dialog_unlock = false

func _on_ui_lights_changed() -> void:
	if _sim and not _sim.running:
		_apply_ui_to_model()
		queue_redraw()

func _on_ui_speed_changed(v: float) -> void:
	if _sim and not _sim.running:
		_sim.set_speed_mps(clampf(v, speed_min_mps, speed_max_mps))

func _apply_ui_to_model() -> void:
	var dists = ui.read_all_distances()
	if dists.size() >= 4:
		dist_B_from_A_m = clampf(float(dists[1]), 0.0 + DIST_MIN_GAP, DIST_MAX_D)
		dist_C_from_A_m = clampf(float(dists[2]), dist_B_from_A_m + DIST_MIN_GAP, DIST_MAX_D)
		dist_D_from_A_m = clampf(float(dists[3]), dist_C_from_A_m + DIST_MIN_GAP, DIST_MAX_D)

	_refresh_layout()

	var lights = ui.read_all_lights()
	_sim.apply_lights(lights)

	ui.set_plot_signals([
		0.0,
		dist_B_from_A_m,
		dist_C_from_A_m,
		dist_D_from_A_m
	])

	var ui_speed: float = ui.get_speed_mps()
	_sim.set_speed_mps(clampf(ui_speed, speed_min_mps, speed_max_mps))

func _finish(success: bool) -> void:
	if not _sim:
		return
	_sim.running = false
	_waiting_dialog_unlock = true

	dlg.title = "结果"
	dlg.dialog_text = "车辆通过！" if success else "已停止。"
	dlg.popup_centered()

func _on_result_confirmed() -> void:
	if _waiting_dialog_unlock:
		ui.set_running(false)
		_waiting_dialog_unlock = false

func _car_setup_sprite() -> void:
	if _car_sprite:
		_car_apply_size_and_transform()
		return
	_car_sprite = Sprite2D.new()
	add_child(_car_sprite)
	var tex: Texture2D = load(car_texture_path) as Texture2D
	if tex:
		_car_sprite.texture = tex
	_car_sprite.centered = true
	_car_sprite.z_index = 10
	_car_apply_size_and_transform()

func _car_apply_size_and_transform() -> void:
	if not _car_sprite or not _car_sprite.texture:
		return
	var tw: float = maxf(float(_car_sprite.texture.get_width()), 1.0)
	var th: float = maxf(float(_car_sprite.texture.get_height()), 1.0)
	_car_sprite.scale = Vector2(car_size_px.x / tw, car_size_px.y / th)
	_car_sprite.rotation = 0.0
	if car_face_left:
		_car_sprite.rotation = PI
	_car_sprite.rotation += deg_to_rad(car_rotation_deg)
	_car_sprite.flip_h = car_flip_h
	_car_sprite.flip_v = car_flip_v

func _sync_car_visual() -> void:
	if _car_sprite and _sim:
		_car_sprite.position = Vector2(_sim.car_x - car_size_px.x * 0.5, road_y)

func _draw() -> void:
	_draw_background()
	_draw_road()
	_draw_lights_and_labels()

func _draw_background() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var mid_y: float = floor(sz.y * 0.5)
	draw_rect(Rect2(Vector2(0, 0), Vector2(sz.x, mid_y)), COL_SKY, true)
	draw_rect(Rect2(Vector2(0, mid_y), Vector2(sz.x, sz.y - mid_y)), COL_GROUND, true)

func _draw_road() -> void:
	draw_line(Vector2(road_x_start, road_y), Vector2(road_x_start + road_length, road_y), COL_ROAD, 3.0)

func _draw_lights_and_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	var abcd_size: int = 28
	var dist_size: int = 26
	var dist_labels = PackedFloat32Array([0.0, dist_B_from_A_m, dist_C_from_A_m, dist_D_from_A_m])

	var t_for_lights: float = _sim.t if _sim else 0.0

	for i in range(_intersection_positions.size()):
		var ix: float = _intersection_positions[i]
		var y_bulb: float = road_y - (tick_size * LIGHT_SCALE) - (12.0 * LIGHT_SCALE)

		var side: float = light_housing_w * LIGHT_SCALE
		var housing_rect = Rect2(ix - side * 0.5, y_bulb - side * 0.5, side, side)
		draw_rect(housing_rect, light_housing_color, true)

		var pole_start = Vector2(ix, housing_rect.position.y + housing_rect.size.y)
		var pole_end   = Vector2(ix, road_y)
		draw_line(pole_start, pole_end, light_pole_color, light_pole_thickness * LIGHT_SCALE)

		var col: Color = COL_RED
		if _sim and _sim.lights.size() > i:
			var st = _sim.lights[i].state_at(t_for_lights)
			col = COL_GREEN if int(st["state"]) == LightConfig.LightState.GREEN else COL_RED
		draw_circle(Vector2(ix, y_bulb), light_bulb_radius * LIGHT_SCALE, col)

		draw_string(
			font,
			Vector2(ix - 10.0, y_bulb - (16.0 * LIGHT_SCALE)),
			str(char(65 + i)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			abcd_size,
			COL_LABEL
		)

		draw_string(
			font,
			Vector2(ix - 34.0, road_y + tick_size + 30.0),
			str(roundi(dist_labels[i])) + " m",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			dist_size,
			COL_TEXT
		)
