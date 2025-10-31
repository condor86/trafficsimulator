extends Resource
class_name TrafficSim

var running: bool = false
var t: float = 0.0                        # 仿真时间（秒）
var car_x: float = 0.0                    # 车当前的 x（像素）
var road_y: float = 0.0

var intersection_x: PackedFloat32Array = PackedFloat32Array()  # 各路口 x
var lights: Array = []                    # Array[LightConfig]

var current_passed_idx: int = 0           # 最后一个通过的路口下标
var waiting_at_red: bool = false
var waiting_idx: int = -1

var time_scale: float = 1.0
var speed_mps: float = 20.0
var px_per_meter: float = 1.0             # 米→像素

func setup_layout(intersections: PackedFloat32Array, pxpm: float, road_y_in: float) -> void:
	intersection_x = intersections
	px_per_meter = maxf(pxpm, 0.0001)
	road_y = road_y_in
	if intersection_x.size() > 0:
		# 从第一个路口左侧一点点起步
		car_x = intersection_x[0] - 0.0001
	else:
		car_x = 0.0

func apply_lights(lights_in: Array) -> void:
	lights = lights_in

func set_speed_mps(v: float) -> void:
	speed_mps = maxf(v, 0.0)

func set_time_scale(v: float) -> void:
	time_scale = maxf(v, 0.0)

func reset() -> void:
	t = 0.0
	current_passed_idx = 0
	waiting_at_red = false
	waiting_idx = -1
	if intersection_x.size() > 0:
		car_x = intersection_x[0] - 0.0001
	else:
		car_x = 0.0
	running = false

func start() -> void:
	running = true

# 返回：{"finished": bool}
func step(delta: float) -> Dictionary:
	if not running:
		return {"finished": false}

	var scaled_delta: float = delta * time_scale
	t += scaled_delta
	var v_pxps: float = speed_mps * px_per_meter

	# 速度为 0 时，仍要尝试红灯→绿灯
	if v_pxps <= 1e-6:
		_try_leave_red()
		return {"finished": false}

	var remaining_time: float = scaled_delta

	while remaining_time > 0.0:
		# 正在红灯前等待
		if waiting_at_red:
			if _try_leave_red():
				# 通过了一个路口
				if current_passed_idx == intersection_x.size() - 1:
					running = false
					return {"finished": true}
			else:
				# 仍在等：车停在该路口
				car_x = intersection_x[waiting_idx]
				break

		# 还有下一个路口
		var next_idx: int = current_passed_idx + 1
		if next_idx >= intersection_x.size():
			# 没有更多路口，走完这一点距离就结束
			car_x += v_pxps * remaining_time
			remaining_time = 0.0
			running = false
			return {"finished": true}

		var target_x: float = intersection_x[next_idx]
		var dist_to_stop: float = maxf(target_x - car_x, 0.0)
		var max_step_px: float = v_pxps * remaining_time

		if max_step_px < dist_to_stop - 1e-6:
			# 这一帧到不了下一个路口
			car_x += max_step_px
			remaining_time = 0.0
			break
		else:
			# 能到下一个路口，要算到达时刻
			var time_to_stop: float = dist_to_stop / v_pxps if dist_to_stop > 1e-6 else 0.0
			var t_arrive: float = t - (remaining_time - time_to_stop)

			# 车先到停止线
			car_x = target_x

			var st_at_arrive = lights[next_idx].state_at(t_arrive)
			if int(st_at_arrive["state"]) == LightConfig.LightState.RED:
				# 到达时是红灯 → 停
				waiting_at_red = true
				waiting_idx = next_idx
				break
			else:
				# 到达时是绿灯 → 通过
				current_passed_idx = next_idx
				remaining_time -= time_to_stop

				# 已经是最后一个路口，再用剩余时间走完
				if current_passed_idx == intersection_x.size() - 1:
					car_x += v_pxps * remaining_time
					remaining_time = 0.0
					running = false
					return {"finished": true}

	return {"finished": false}

func _try_leave_red() -> bool:
	if not waiting_at_red:
		return false
	if waiting_idx < 0 or waiting_idx >= lights.size():
		waiting_at_red = false
		return false

	var st_now = lights[waiting_idx].state_at(t)
	if int(st_now["state"]) == LightConfig.LightState.GREEN:
		waiting_at_red = false
		current_passed_idx = waiting_idx
		waiting_idx = -1
		return true
	return false
