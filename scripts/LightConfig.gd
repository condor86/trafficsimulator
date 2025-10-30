# res://scripts/LightConfig.gd
class_name LightConfig
extends RefCounted

enum LightState { GREEN, RED }

@export var green_sec: float = 30.0
@export var red_sec: float = 30.0
@export var start_state: int = LightState.GREEN
@export var start_elapsed: float = 0.0

func _init(g: float = 30.0, r: float = 30.0, st: int = LightState.GREEN, el: float = 0.0) -> void:
	green_sec = maxf(g, 0.1)
	red_sec = maxf(r, 0.1)
	start_state = st
	start_elapsed = maxf(el, 0.0)

func _cycle() -> float:
	return green_sec + red_sec

func _start_offset_in_cycle() -> float:
	var offset: float = start_elapsed
	if start_state == LightState.RED:
		offset += green_sec
	return fmod(offset, _cycle())

# 返回字典：{"state": LightState.*, "elapsed": float, "remain": float}
func state_at(t: float) -> Dictionary:
	var T: float = _cycle()
	var x: float = fmod(_start_offset_in_cycle() + maxf(t, 0.0), T)
	if x < green_sec:
		return {"state": LightState.GREEN, "elapsed": x, "remain": green_sec - x}
	var xr: float = x - green_sec
	return {"state": LightState.RED, "elapsed": xr, "remain": red_sec - xr}
