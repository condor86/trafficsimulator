extends Resource
class_name TrafficSim

var running: bool = false
var t: float = 0.0            # 全局仿真时间
var car_x: float = 0.0        # 车的当前 x
var road_y: float = 0.0
var intersection_x: PackedFloat32Array = PackedFloat32Array()
var lights: Array = []        # Array[LightConfig]
var current_passed_idx: int = 0
var waiting_at_red: bool = false
var waiting_idx: int = -1
var time_scale: float = 1.0
var speed_mps: float = 20.0
var px_per_meter: float = 1.0

func setup_layout(intersections: PackedFloat32Array, pxpm: float, road_y_in: float) -> void:
	intersection_x = intersections
	px_per_meter = maxf(pxpm, 0.0001)
	road_y = road_y_in
	if intersection_x.size() > 0:
		# 从左往右，车起点在 A 的左侧一点点
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

# 返回值：{"finished": bool}
func step(delta: float) -> Dictionary:
	if not running:
		return {"finished": false}

	var scaled_delta: float = delta * time_scale
	t += scaled_delta

	var v_pxps: float = speed_mps * px_per_meter

	# 速度为 0 时，仍要尝试“等红灯→变绿”
	if v_pxps <= 1e-6:
		if waiting_at_red and waiting_idx >= 0 and waiting_idx < lights.size():
			var st_now = lights[waiting_idx].state_at(t)
			if int(st_now["state"]) == LightConfig.LightState.GREEN:
				waiting_at_red = false
				current_passed_idx = waiting_idx
				waiting_idx = -1
				if current_passed_idx == intersection_x.size() - 1:
					running = false
					return {"finished": true}
		return {"finished": false}

	var remaining_time: float = scaled_delta

	while remaining_time > 0.0:
		# 1) 等红灯阶段：只看变绿，不往前挪
		if waiting_at_red:
			var st_now2 = lights[waiting_idx].state_at(t)
			if int(st_now2["state"]) == LightConfig.LightState.GREEN:
				waiting_at_red = false
				current_passed_idx = waiting_idx
				waiting_idx = -1
				if current_passed_idx == intersection_x.size() - 1:
					running = false
					return {"finished": true}
			else:
				# 停在当前等待的路口
				car_x = intersection_x[waiting_idx]
				break

		# 2) 正常行驶到下一个路口
		var next_idx: int = current_passed_idx + 1
		if next_idx >= intersection_x.size():
			# 没有下一个路口了，就继续往右走一段然后结束
			car_x += v_pxps * remaining_time
			remaining_time = 0.0
			running = false
			return {"finished": true}

		var target_x: float = intersection_x[next_idx]
		# 从左往右：路口在右边，所以用 target_x - car_x
		var dist_to_stop: float = maxf(target_x - car_x, 0.0)
		var max_step_px: float = v_pxps * remaining_time

		if max_step_px < dist_to_stop - 1e-6:
			# 到不了下一路口，走完这一帧
			car_x += max_step_px
			remaining_time = 0.0
			break
		else:
			# 能到下一路口，要算抵达时刻
			var time_to_stop: float = 0.0
			if dist_to_stop > 1e-6:
				time_to_stop = dist_to_stop / v_pxps
			# 到达这一刻的全局时间
			var t_arrive: float = t - (remaining_time - time_to_stop)

			# 先把车放到停止线
			car_x = target_x

			var st_at_arrive = lights[next_idx].state_at(t_arrive)

			if int(st_at_arrive["state"]) == LightConfig.LightState.RED:
				# 到达时是红灯 → 进入等待
				waiting_at_red = true
				waiting_idx = next_idx
				break
			else:
				# 到达时是绿灯 → 通过该路口，继续推进剩余时间
				current_passed_idx = next_idx
				remaining_time -= time_to_stop
				# 如果这就是最后一个路口，再用剩余时间往右走，走完就结束
				if current_passed_idx == intersection_x.size() - 1:
					car_x += v_pxps * remaining_time
					remaining_time = 0.0
					running = false
					return {"finished": true}

	return {"finished": false}
