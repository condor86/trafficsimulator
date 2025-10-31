extends RefCounted
class_name LightConfig

# —— 灯状态 —— 
enum LightState { GREEN, RED }

var green_sec: float
var red_sec: float
var start_state: int
var start_elapsed: float

func _init(g: float, r: float, st: int, el: float) -> void:
	# 基础防护，防止 0 秒
	green_sec = maxf(g, 0.1)
	red_sec = maxf(r, 0.1)
	start_state = st
	start_elapsed = maxf(el, 0.0)

func cycle() -> float:
	return green_sec + red_sec

func _start_offset_in_cycle() -> float:
	var offset: float = start_elapsed
	if start_state == LightState.RED:
		offset += green_sec
	return fmod(offset, cycle())

# 返回：
# {
#   "state": LightState.GREEN / LightState.RED,
#   "elapsed": 当前状态已运行时间,
#   "remain":  当前状态剩余时间
# }
func state_at(t: float) -> Dictionary:
	var T: float = cycle()
	var x: float = fmod(_start_offset_in_cycle() + maxf(t, 0.0), T)
	if x < green_sec:
		return {"state": LightState.GREEN, "elapsed": x, "remain": green_sec - x}
	var xr: float = x - green_sec
	return {"state": LightState.RED, "elapsed": xr, "remain": red_sec - xr}
