extends RefCounted
class_name TrafficSim

# —— 布局数据（外部注入）——
var intersection_positions: PackedFloat32Array = PackedFloat32Array()
var px_per_meter: float = 1.0
var road_y: float = 240.0

# —— 运行态 —— 
var running: bool = false
var t: float = 0.0
var car_x: float = 0.0
var current_passed_idx: int = 0
var waiting_at_red: bool = false
var waiting_idx: int = -1

var time_scale: float = 1.0
var speed_mps: float = 20.0

var lights: Array = []    # Array[LightConfig]

func setup_layout(intersections: PackedFloat32Array, px_per_m: float, road_y_px: float) -> void:
	intersection_positions = intersections
	px_per_meter = px_per_m
	road_y = road_y_px
	if intersection_positions.size() > 0:
		car_x = intersection_positions[0] + 0.0001

func apply_lights(cfgs: Array) -> void:
	lights = cfgs

func set_speed_mps(v: float) -> void:
	speed_mps = maxf(v, 0.0)

func set_time_scale(v: float) -> void:
	time_scale = clampf(v, 1.0, 10.0)

func reset() -> void:
	t = 0.0
	running = false
	current_passed_idx = 0
	waiting_at_red = false
	waiting_idx = -1
	if intersection_positions.size() > 0:
		car_x = intersection_positions[0] + 0.0001

func start() -> void:
	running = true
	waiting_at_red = false
	waiting_idx = -1

# 返回 {finished: bool, t: float, car_x: float}
func step(delta: float) -> Dictionary:
	if not running:
		return {"finished": false, "t": t, "car_x": car_x}

	var scaled_delta: float = delta * time_scale
	t += scaled_delta

	var v_pxps: float = speed_mps * px_per_meter
	if v_pxps <= 1e-6:
		return {"finished": false, "t": t, "car_x": car_x}

	var remaining_time: float = scaled_delta

	while remaining_time > 0.0:
		# 1) 等红灯
		if waiting_at_red:
			var st_now = lights[waiting_idx].state_at(t)
			if int(st_now["state"]) == LightConfig.LightState.GREEN:
				waiting_at_red = false
				current_passed_idx = waiting_idx
				waiting_idx = -1
				if current_passed_idx == intersection_positions.size() - 1:
					running = false
					break
			else:
				car_x = intersection_positions[waiting_idx]
				break

		# 2) 去下一个路口
		var next_idx: int = current_passed_idx + 1
		if next_idx >= intersection_positions.size():
			# 已没有路口了
			car_x -= v_pxps * remaining_time
			remaining_time = 0.0
			running = false
			break

		var target_x: float = intersection_positions[next_idx]
		var dist_to_stop: float = maxf(car_x - target_x, 0.0)
		var max_step_px: float = v_pxps * remaining_time

		if max_step_px < dist_to_stop - 1e-6:
			# 到不了下一个路口
			car_x -= max_step_px
			remaining_time = 0.0
			break
		else:
			# 能到路口，看灯
			var time_to_stop: float = 0.0
			if dist_to_stop > 1e-6:
				time_to_stop = dist_to_stop / v_pxps

			var t_arrive: float = t - (remaining_time - time_to_stop)
			var st_at_arrive = lights[next_idx].state_at(t_arrive)

			car_x = target_x

			if int(st_at_arrive["state"]) == LightConfig.LightState.RED:
				# 红灯停
				waiting_at_red = true
				waiting_idx = next_idx
				break
			else:
				# 绿灯过
				current_passed_idx = next_idx
				remaining_time -= time_to_stop
				if current_passed_idx == intersection_positions.size() - 1:
					car_x -= v_pxps * remaining_time
					remaining_time = 0.0
					running = false
					break

	return {"finished": not running, "t": t, "car_x": car_x}
