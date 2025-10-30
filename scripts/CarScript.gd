# res://scripts/CarSprite.gd
class_name CarSprite
extends Node2D

@export var car_texture_path: String = "res://assets/car.png"
@export var car_size_px: Vector2 = Vector2(50, 50)
@export var car_face_left: bool = true
@export var car_rotation_deg: float = 0.0
@export var car_flip_h: bool = true
@export var car_flip_v: bool = true

var sprite: Sprite2D

func _ready() -> void:
	_setup_sprite()

func _setup_sprite() -> void:
	if sprite:
		_apply_transform()
		return
	sprite = Sprite2D.new()
	add_child(sprite)
	if ResourceLoader.exists(car_texture_path):
		var tex: Texture2D = load(car_texture_path)
		if tex:
			sprite.texture = tex
	sprite.centered = true
	sprite.z_index = 10
	_apply_transform()

func _apply_transform() -> void:
	if not sprite or not sprite.texture:
		return
	var tw: float = float(sprite.texture.get_width())
	var th: float = float(sprite.texture.get_height())
	if tw <= 0.0: tw = 1.0
	if th <= 0.0: th = 1.0
	sprite.scale = Vector2(car_size_px.x / tw, car_size_px.y / th)
	sprite.rotation = 0.0
	if car_face_left:
		sprite.rotation = PI
	sprite.rotation += deg_to_rad(car_rotation_deg)
	sprite.flip_h = car_flip_h
	sprite.flip_v = car_flip_v

# 外部接口：设置位置（像素坐标）
func set_position_px(pos: Vector2) -> void:
	if sprite:
		sprite.position = pos
