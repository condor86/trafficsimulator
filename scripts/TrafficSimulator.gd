extends Node2D

# —— 道路 & 车辆参数 —— 
@export var dist_B_from_A_m: float = 800.0
@export var dist_C_from_A_m: float = 1400.0
@export var dist_D_from_A_m: float = 2400.0
@export var speed_default_mps: float = 20.0

# —— 红绿灯管理 —— 
var lights: Array = []

# —— 车辆状态 —— 
var car_x: float = 0.0
var current_passed_idx: int = 0

# —— UIManager 引用（无需 preload，全局类型） —— 
@onready var ui_manager: UIManager = get_node("/root/UIManager")

func _ready() -> void:
	_setup_lights()
	_connect_signals()
	print("Traffic Simulator ready. UIManager speed:", ui_manager.speed_mps)

# —— 初始化灯光示例 —— 
func _setup_lights() -> void:
	lights.append(LightConfig.new(30.0, 30.0, LightConfig.LightState.GREEN, 0.0))
	lights.append(LightConfig.new(30.0, 30.0, LightConfig.LightState.RED, 5.0))

# —— 信号连接 —— 
func _connect_signals() -> void:
	var cb_start = Callable(self, "_on_start_pressed")
	if not ui_manager.start_button.pressed.is_connected(cb_start):
		ui_manager.start_button.pressed.connect(cb_start)

	var cb_speed = Callable(self, "_on_speed_changed")
	if not ui_manager.speed_slider.value_changed.is_connected(cb_speed):
		ui_manager.speed_slider.value_changed.connect(cb_speed)

# —— 回调函数 —— 
func _on_start_pressed() -> void:
	print("Simulation started!")

func _on_speed_changed(value: float) -> void:
	print("Speed changed to:", value)
	# 更新内部参数
	speed_default_mps = value
