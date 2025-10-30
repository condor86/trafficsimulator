# res://scripts/SimulationEngine.gd
class_name SimulationEngine
extends Node

signal finished(success: bool, total_time: float)
signal tick_updated(t: float, car_x: float, passed_idx: int)

@export var intersection_positions: PackedFloat32Array = PackedFloat32Array([0.0])
@export var px_per_meter: float = 1.0
@export var speed_mps: float = 20.0
@export var time_scale: float = 1.0
@export var lights: Array = []  # Array[LightConfig] (RefCounted instances)

# internal
var _running: bool = false
var _t: float = 0.0
var _car_x: float = 0.0
var _current_passed_idx: int = 0
var _waiting_at_red: bool = false
var _waiting_idx: int = -1

enum LightState { GREEN, RED }

func start(initial_car_x: float) -> void:
	_reset_internal()
	_car_x = initial_car_x
	_running = true
	# immediate update
	emit_signal("tick_updated", _t, _car_x, _current_passed_idx)

func stop() -> void:
	_running = false

func reset(initial_car_x: float) -> void:
	_reset_internal()
	_car_x = initial_car_x
	emit_signal("tick_updated", _t, _car_x, _current_passed_idx)

func _reset_internal() -> void:
	_t = 0.0
	_current_passed_idx = 0
	_running = false
	_waiting_at_red = false
	_waiting_idx = -1

# call every frame from parent: delta is real delta seconds
func step(delta: float) -> void:
	if not _running:
		return
	var scaled_delta: float = delta * time_scale
	_t += scaled_delta

	var v_pxps: float = speed_mps * px_per_meter
	if v_pxps <= 1e-9:
		emit_signal("tick_updated", _t, _car_x, _current_passed_idx)
		return

	var remaining_time: float = scaled_delta
	while remaining_time > 0.0:
		# waiting at red: check current global time _t
		if _waiting_at_red:
			if _waiting_idx >= 0 and _waiting_idx < lights.size():
				var st_now = lights[_waiting_idx].state_at(_t)
				if int(st_now["state"]) == LightState.GREEN:
					_waiting_at_red = false
					_current_passed_idx = _waiting_idx
					_waiting_idx = -1
					if _current_passed_idx == intersection_positions.size() - 1:
						_running = false
						emit_signal("finished", true, _t)
						return
				else:
					# still red -> stay at stop line
					var stop_x2 = intersection_positions[_waiting_idx]
					_car_x = stop_x2
					emit_signal("tick_updated", _t, _car_x, _current_passed_idx)
					return
			else:
				# invalid waiting index reset
				_waiting_at_red = false
				_waiting_idx = -1

		var next_idx: int = _current_passed_idx + 1
		if next_idx >= intersection_positions.size():
			# reached final segment: move outward using remaining time then finish
			_car_x -= v_pxps * remaining_time
			remaining_time = 0.0
			_running = false
			emit_signal("finished", true, _t)
			emit_signal("tick_updated", _t, _car_x, _current_passed_idx)
			return

		var target_x: float = intersection_positions[next_idx]
		var dist_to_stop: float = maxf(_car_x - target_x, 0.0)
		var max_step_px: float = v_pxps * remaining_time

		if max_step_px < dist_to_stop - 1e-6:
			_car_x -= max_step_px
			remaining_time = 0.0
			break
		else:
			var time_to_stop: float = 0.0
			if dist_to_stop > 1e-6:
				time_to_stop = dist_to_stop / v_pxps
			var t_arrive: float = _t - (remaining_time - time_to_stop)
			var st_at_arrive = null
			if next_idx >= 0 and next_idx < lights.size():
				st_at_arrive = lights[next_idx].state_at(t_arrive)
			else:
				# no light -> treat as green
				st_at_arrive = {"state": LightState.GREEN, "elapsed": 0.0, "remain": 0.0}

			_car_x = target_x
			if int(st_at_arrive["state"]) == LightState.RED:
				_waiting_at_red = true
				_waiting_idx = next_idx
				break
			else:
				_current_passed_idx = next_idx
				remaining_time -= time_to_stop
				if _current_passed_idx == intersection_positions.size() - 1:
					_car_x -= v_pxps * remaining_time
					remaining_time = 0.0
					_running = false
					emit_signal("finished", true, _t)
					break

	# frame end update
	emit_signal("tick_updated", _t, _car_x, _current_passed_idx)
