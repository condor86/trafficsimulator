# res://scripts/UIManager.gd
class_name UIManager
extends Node

signal start_pressed()
signal apply_timescale(new_scale: float)
signal speed_changed(new_speed: float)

# —— UI 引用 —— 
@onready var ui: Control = get_node("CanvasLayer/UI")
@onready var start_button: Button = get_node("CanvasLayer/UI/StartButton")
@onready var speed_slider: HSlider = get_node("CanvasLayer/UI/SpeedSlider")
@onready var panel_A: Control = get_node("CanvasLayer/UI/LightA")
@onready var panel_B: Control = get_node("CanvasLayer/UI/LightB")
@onready var panel_C: Control = get_node("CanvasLayer/UI/LightC")
@onready var panel_D: Control = get_node("CanvasLayer/UI/LightD")

var speed_input: SpinBox
var timescale_slider: HSlider
var timescale_button: Button
var timer_label: Label

# ----------------- ready -----------------
func _ready() -> void:
	_ensure_speed_input()
	_ensure_timescale_controls()
	_ensure_timer_label()
	_bootstrap_panels()
	_connect_signals()

# ----------------- ensure controls -----------------
func _ensure_speed_input() -> void:
	speed_input = ui.get_node_or_null("SpeedInput") as SpinBox
	if not speed_input:
		speed_input = SpinBox.new()
		speed_input.name = "SpeedInput"
		ui.add_child(speed_input)
	speed_input.min_value = 0.0
	speed_input.max_value = 200.0
	speed_input.step = 0.5
	speed_input.value = 20.0
	speed_input.size = Vector2(96, 24)
	speed_input.suffix = " m/s"

func _ensure_timescale_controls() -> void:
	timescale_slider = ui.get_node_or_null("TimeScaleSlider") as HSlider
	if not timescale_slider:
		timescale_slider = HSlider.new()
		timescale_slider.name = "TimeScaleSlider"
		ui.add_child(timescale_slider)
	timescale_slider.min_value = 1.0
	timescale_slider.max_value = 10.0
	timescale_slider.step = 0.5
	timescale_slider.value = 10.0
	timescale_slider.size = Vector2(300, 20)

	timescale_button = ui.get_node_or_null("ApplyTimeScaleButton") as Button
	if not timescale_button:
		timescale_button = Button.new()
		timescale_button.name = "ApplyTimeScaleButton"
		ui.add_child(timescale_button)
	timescale_button.text = "应用加速"
	timescale_button.size = Vector2(96, 32)

func _ensure_timer_label() -> void:
	timer_label = ui.get_node_or_null("TimerLabel") as Label
	if not timer_label:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		ui.add_child(timer_label)
	timer_label.text = "总用时：0.0 秒"

# ----------------- panels defaults -----------------
func _bootstrap_panels() -> void:
	var panels = [panel_A, panel_B, panel_C, panel_D]
	for p in panels:
		if p and p is Control:
			var gv = p.get_node_or_null("GreenSec") as SpinBox
			var rv = p.get_node_or_null("RedSec") as SpinBox
			var ev = p.get_node_or_null("StartElapsedSec") as SpinBox
			var sv = p.get_node_or_null("StartState") as OptionButton
			if gv:
				gv.min_value = 0.1
				gv.value = 30.0
			if rv:
				rv.min_value = 0.1
				rv.value = 30.0
			if ev:
				ev.min_value = 0.0
				ev.value = 0.0
			if sv:
				if sv.item_count < 2:
					sv.clear()
					sv.add_item("绿", 0)
					sv.add_item("红", 1)
				sv.selected = 0

# ----------------- connect signals -----------------
func _connect_signals() -> void:
	if start_button:
		var cb_start = Callable(self, "_on_start_pressed")
		if not start_button.pressed.is_connected(cb_start):
			start_button.pressed.connect(cb_start)

	if timescale_button:
		var cb_ts = Callable(self, "_on_apply_timescale_pressed")
		if not timescale_button.pressed.is_connected(cb_ts):
			timescale_button.pressed.connect(cb_ts)

	if speed_slider:
		var cb_sp = Callable(self, "_on_speed_slider_changed")
		if not speed_slider.value_changed.is_connected(cb_sp):
			speed_slider.value_changed.connect(cb_sp)

	if speed_input:
		var cb_si = Callable(self, "_on_speed_input_changed")
		if not speed_input.value_changed.is_connected(cb_si):
			speed_input.value_changed.connect(cb_si)

# ----------------- signal handlers -----------------
func _on_start_pressed() -> void:
	emit_signal("start_pressed")

func _on_apply_timescale_pressed() -> void:
	if timescale_slider:
		emit_signal("apply_timescale", clampf(timescale_slider.value, 1.0, 10.0))

func _on_speed_slider_changed(v: float) -> void:
	if speed_input:
		speed_input.value = v
	emit_signal("speed_changed", v)

func _on_speed_input_changed(v: float) -> void:
	if speed_slider:
		speed_slider.value = v
	emit_signal("speed_changed", v)

# ----------------- read lights -----------------
func read_light_from_panel(panel: Control) -> LightConfig:
	var g = 30.0
	var r = 30.0
	var st_idx = 0
	var el = 0.0
	if panel:
		var gv = panel.get_node_or_null("GreenSec") as SpinBox
		var rv = panel.get_node_or_null("RedSec") as SpinBox
		var ev = panel.get_node_or_null("StartElapsedSec") as SpinBox
		var sv = panel.get_node_or_null("StartState") as OptionButton
		if gv:
			g = gv.value
		if rv:
			r = rv.value
		if ev:
			el = ev.value
		if sv:
			st_idx = sv.selected
	return LightConfig.new(g, r, st_idx, el)

func read_all_lights() -> Array:
	return [
		read_light_from_panel(panel_A),
		read_light_from_panel(panel_B),
		read_light_from_panel(panel_C),
		read_light_from_panel(panel_D)
	]

func update_timer_label(t: float) -> void:
	if timer_label:
		timer_label.text = "总用时：" + str(snappedf(t, 0.1)) + " 秒"
