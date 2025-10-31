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

@export var ui_row_up_offset: float = 100.0
@export var show_light_panels: bool = false

@export var road_y: float = 240.0
@export var road_length: float = 1000.0
@export var road_x_start: float = 100.0
@export var tick_size: float = 16.0
@export var light_bulb_radius: float = 8.0
@export var car_radius: float = 6.0

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

# 新增：距离约束
const DIST_MIN_GAP := 50.0
const DIST_MAX_D := 3000.0

@onready var ui = $CanvasLayer/UI
@onready var dlg: AcceptDialog = $ResultDialog

var _sim: TrafficSim
var _px_per_meter: float = 1.0
var _intersection_positions: PackedFloat32Array = PackedFloat32Array([0.0, 300.0, 600.0, 900.0])
var _car_sprite: Sprite2D

var _waiting_dialog_unlock: bool = false

func _ready() -> void:
	_auto_layout_positions()

	_sim = TrafficSim.new()
	_sim.set_speed_mps(speed_default_mps)
	_sim.set_time_scale(clampf(default_time_scale, 1.0, 15.0))

	ui.set_show_light_panels(show_light_panels)
	ui.layout_for_intersections(_intersection_positions, road_y, tick_size)

	# 把当前导出的 ABCD 距离回写给 UI，保证一致
	ui.set_distances_from_root([
		0.0,
		dist_B_from_A_m,
		dist_C_from_A_m,
		dist_D_from_A_m
	])

	var lights = ui.read_all_lights()
	_sim.apply_lights(lights)
	_sim.setup_layout(_intersection_positions, _px_per_meter, road_y)

	ui.start_pressed.connect(_on_ui_start_pressed)
	ui.lights_changed.connect(_on_ui_lights_changed)
	ui.speed_changed.connect(_on_ui_speed_changed)

	_car_setup_sprite()
	_sync_car_visual()

	if not dlg.confirmed.is_connected(_on_result_confirmed):
		dlg.confirmed.connect(_on_result_confirmed)

	if not get_window().size_changed.is_connected(_on_window_size_changed):
		get_window().size_changed.connect(_on_window_size_changed)

	queue_redraw()

func _on_window_size_changed() -> void:
	_auto_layout_positions()
	ui.layout_for_intersections(_intersection_positions, road_y, tick_size)
	queue_redraw()

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
	_intersection_positions[0] = x_left + dists[0] * _px_per_meter
	_intersection_positions[1] = x_left + dists[1] * _px_per_meter
	_intersection_positions[2] = x_left + dists[2] * _px_per_meter
	_intersection_positions[3] = x_left + dists[3] * _px_per_meter

	if _sim:
		_sim.setup_layout(_intersection_positions, _px_per_meter, road_y)

func _process(delta: float) -> void:
	if _sim and _sim.running:
		var r = _sim.step(delta)
		if r["finished"]:
			_finish(true)
	_sync_car_visual()
	queue_redraw()

func _on_ui_start_pressed() -> void:
	# 开始之前再读一遍 UI 的距离，做一次兜底
	var dists_from_ui = ui.read_all_distances()
	_apply_distances_from_ui(dists_from_ui)

	var lights = ui.read_all_lights()
	_sim.apply_lights(lights)

	var ui_speed: float = ui.get_speed_mps()
	var clamped_speed: float = clampf(ui_speed, speed_min_mps, speed_max_mps)
	_sim.set_speed_mps(clamped_speed)

	_sim.reset()
	_sim.set_time_scale(clampf(default_time_scale, 1.0, 15.0))
	_sim.start()

	ui.set_running(true)
	_waiting_dialog_unlock = false

func _on_ui_lights_changed() -> void:
	# 不在运行时才能变
	if _sim and not _sim.running:
		var lights = ui.read_all_lights()
		_sim.apply_lights(lights)

		# ★ 新增：读位置并应用
		var dists_from_ui = ui.read_all_distances()
		_apply_distances_from_ui(dists_from_ui)

		queue_redraw()

func _on_ui_speed_changed(v: float) -> void:
	if _sim and not _sim.running:
		_sim.set_speed_mps(clampf(v, speed_min_mps, speed_max_mps))

func _apply_distances_from_ui(dists: Array) -> void:
	if dists.size() < 4:
		return

	var a := 0.0
	var b := float(dists[1])
	var c := float(dists[2])
	var d := float(dists[3])

	# 和 UI 一样的规则，再夹一遍
	b = maxf(b, a + DIST_MIN_GAP)
	c = maxf(c, b + DIST_MIN_GAP)
	d = maxf(d, c + DIST_MIN_GAP)
	d = minf(d, DIST_MAX_D)

	if c > d - DIST_MIN_GAP:
		c = d - DIST_MIN_GAP
	if b > c - DIST_MIN_GAP:
		b = c - DIST_MIN_GAP
	b = maxf(b, a + DIST_MIN_GAP)

	# 更新导出量
	dist_B_from_A_m = b
	dist_C_from_A_m = c
	dist_D_from_A_m = d

	# 重新布局 + 同步 UI + 同步模拟
	_auto_layout_positions()
	ui.layout_for_intersections(_intersection_positions, road_y, tick_size)
	if _sim:
		_sim.setup_layout(_intersection_positions, _px_per_meter, road_y)

func _finish(success: bool) -> void:
	if not _sim:
		return
	_sim.running = false
	_waiting_dialog_unlock = true

	dlg.title = "结果"
	if success:
		dlg.dialog_text = "车辆通过！"
	else:
		dlg.dialog_text = "已停止。"
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
	var tw: float = float(_car_sprite.texture.get_width())
	var th: float = float(_car_sprite.texture.get_height())
	if tw <= 0.0:
		tw = 1.0
	if th <= 0.0:
		th = 1.0
	_car_sprite.scale = Vector2(car_size_px.x / tw, car_size_px.y / th)
	_car_sprite.rotation = 0.0
	if car_face_left:
		_car_sprite.rotation = PI
	_car_sprite.rotation += deg_to_rad(car_rotation_deg)
	_car_sprite.flip_h = car_flip_h
	_car_sprite.flip_v = car_flip_v

func _sync_car_visual() -> void:
	if _car_sprite and _sim:
		_car_sprite.position = Vector2(
			_sim.car_x - car_size_px.x * 0.5,
			road_y
		)

func _draw() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var mid_y: float = floor(sz.y * 0.5)
	draw_rect(Rect2(Vector2(0, 0), Vector2(sz.x, mid_y)), COL_SKY, true)
	draw_rect(Rect2(Vector2(0, mid_y), Vector2(sz.x, sz.y - mid_y)), COL_GROUND, true)

	var x0: float = road_x_start
	var x1: float = road_x_start + road_length
	draw_line(Vector2(x0, road_y), Vector2(x1, road_y), COL_ROAD, 3.0)

	var font: Font = ThemeDB.fallback_font
	var abcd_size: int = 28
	var dist_size: int = 26

	var dist_labels = PackedFloat32Array([0.0, dist_B_from_A_m, dist_C_from_A_m, dist_D_from_A_m])

	# 用当前 _sim.t 来算灯的状态，避免结束那一帧回到 0
	var t_for_lights: float = 0.0
	if _sim:
		t_for_lights = _sim.t

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

		# ABCD 标签
		draw_string(
			font,
			Vector2(ix - 10.0, y_bulb - (16.0 * LIGHT_SCALE)),
			str(char(65 + i)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			abcd_size,
			COL_LABEL
		)

		# 距离标签
		var dist_text: String = str(roundi(dist_labels[i])) + " m"
		draw_string(
			font,
			Vector2(ix - 34.0, road_y + tick_size + 30.0),
			dist_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			dist_size,
			COL_TEXT
		)
