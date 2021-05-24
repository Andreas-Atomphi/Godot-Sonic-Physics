extends KinematicBody2D

class_name PlayerPhysics

signal damaged

export(float) var ACC = 4.6875
export(float) var DEC = 30
export(float) var ROLLDEC = 7.5
export(float) var FRC = 4.6875
export(float) var SLP = 7.5
export(float) var SLPROLLUP = 4.6875
export(float) var SLPROLLDOWN = 18.75
export(float) var TOP = 460
export(float) var TOPROLL = 960
export(float) var JMP = 390
export(float) var FALL = 150
export(float) var AIR = 5.625
export(float) var GRV = 13.125
export(bool) var instaShield = true;
export(bool) var superPeelOut = true;
export(bool) var dropDash = true;
export(bool) var spinDash = true;

onready var fsm = $StateMachine
onready var player_camera = $'../../PlayerCamera'
onready var player_vfx = $Characters/VFX
onready var GLOBAL = get_node("/root/Global");

onready var low_collider = $LowCollider
onready var ray_collider = $Ray

onready var left_ground:RayCast2D = $LeftGroundSensor
onready var right_ground:RayCast2D = $RightGroundSensor
onready var middle_ground:RayCast2D = $MiddleGroundSensor
onready var high_sensor = $HighCollider
onready var left_wall:RayCast2D = $LeftWallSensor
onready var right_wall:RayCast2D = $RightWallSensor
onready var left_wall_bottom:RayCast2D = $LeftWallSensorBottom
onready var right_wall_bottom:RayCast2D = $RightWallSensorBottom

onready var character = $Characters
onready var sprite = character.get_node('Sonic');
onready var animation = sprite.get_node("CharAnimation");
onready var audio_player = $AudioPlayer
onready var main_scene = $"/root/main"
var snap_margin = 32.0

var ring_scene = preload("res://general-objects/ring-object.tscn")

var direction : Vector2 = Vector2.ZERO;
var gsp : float
var velocity : Vector2
var ground_mode : int
var control_locked : bool
var control_unlock_time = .5
var control_unlock_timer : float
var can_fall : bool
var is_ray_colliding : bool
var is_grounded : bool
var ground_point : Vector2
var ground_normal : Vector2
var has_jumped : bool
var is_floating : bool
var is_rolling : bool setget set_is_rolling
var is_braking : bool
var was_damaged : bool
var is_wall_left : bool
var is_wall_right : bool
var is_pushing : bool
var is_looking_down : bool
var is_looking_up : bool
var has_pushed : bool
var invulnerable : bool;
var constant_roll : bool
var up_direction : Vector2 = Vector2.UP

func _ready():
	control_unlock_timer = control_unlock_time

func _process(delta):
	var roll_anim = animation.current_animation == 'Rolling'
	high_sensor.set_deferred("disabled", roll_anim)
	low_collider.set_deferred("disabled", !roll_anim)
	left_ground.position.x = -9 if !roll_anim else -7
	right_ground.position.x = 9 if !roll_anim else 7
	ray_collider.set_deferred("disabled", fsm.current_state == 'OnAir' && velocity.y < 0)
	
	direction.x = \
	-Input.get_action_strength("ui_left") +\
	Input.get_action_strength("ui_right")
	
	direction.y = \
	-Input.get_action_strength("ui_up") +\
	Input.get_action_strength("ui_down")
	
	if (control_locked and is_grounded) or control_unlock_timer < control_unlock_time:
		control_unlock_timer -= delta
		if control_unlock_timer <= 0:
			control_unlock_timer = control_unlock_time
			control_locked = false

func physics_step():
	position.x = max(position.x, 9.0)
	var ground_ray = get_ground_ray()
	is_ray_colliding = (ground_ray != null)
	
	if is_on_ground():
		is_grounded = true
	
	var can_break = abs(gsp) > 270 && is_rolling
	
	var coll = [self, middle_ground, left_ground, right_ground, right_wall, right_wall_bottom, left_wall, left_wall_bottom]
	
	for i in coll:
		i.set_collision_mask_bit(5, !can_break)
		if !i.is_class("RayCast2D"):
			i.set_collision_layer_bit(5, !can_break)
	
	if is_grounded && ground_ray:
		ground_point = ground_ray.get_collision_point()
		ground_normal = ground_ray.get_collision_normal()
		ground_mode = int(round(rad2deg(ground_angle()) / 90.0)) % 4
		ground_mode = -ground_mode if ground_mode == -2 else ground_mode
	else:
		ground_mode = 0
		ground_normal = Vector2(0, -1)
		is_grounded = false
	var j : int = 0
	for i in [left_wall, left_wall_bottom, right_wall, right_wall_bottom]:
		var rs : RayCast2D = i
		var collider = rs.get_collider()
		if collider:
			if collider is TileMap:
				var tmap : TileMap = collider
				var cell = tmap.get_cellv(tmap.world_to_map(rs.get_collision_point()))
				var shape = rs.get_collider_shape()
				var tile = tmap.get_tileset().tile_get_shape_one_way(cell, shape)
				print(tile)
				if tile:
					continue
			if j < 2:
				is_wall_left = is_wall_left || rs.is_colliding()
			else:
				is_wall_right = is_wall_right || rs.is_colliding()
		else:
			if j < 2:
				is_wall_left = false
			else:
				is_wall_right = false
		j+=1
	
	is_wall_left = is_wall_left || position.x - 9 <= 0
	is_wall_right
	
	if constant_roll:
		control_locked = true
		control_unlock_timer = 0.1
		if abs(gsp) < 500:
			gsp += 100 * character.scale.x
		is_rolling = true
		if !is_grounded:
			constant_roll = false

func fall_from_ground():
	if abs(gsp) < FALL and ground_mode != 0:
		var angle = abs(rad2deg(ground_angle()))
		control_locked = true
		
		if angle >= 90 and angle <= 180:
			ground_mode = 0
			return true
		
		return false

func snap_to_ground():
	rotation_degrees = -rad2deg(ground_angle())
	velocity += -ground_normal * 150

func ground_reacquisition():
	var ground_angle = ground_angle();
	var angle = abs(rad2deg(ground_angle))
	
	if angle >= 0 and angle < 22.5:
		gsp = velocity.x
	elif angle >= 22.5 and angle < 45.0:
		if abs(velocity.x) > velocity.y:
			gsp = velocity.x
		else:
			gsp = velocity.y * .5 * -sign(sin(ground_angle))
	elif angle >= 45.0 and angle < 90:
		if abs(velocity.x) > velocity.y:
			gsp = velocity.x
		else:
			gsp = velocity.y * -sign(sin(ground_angle))
	
	rotation_degrees = -rad2deg(ground_angle)

func ground_angle():
	return ground_normal.angle_to(Vector2(0, -1))

func is_on_ground():
	var ground_ray = get_ground_ray()
	if ground_ray != null:
		var point = ground_ray.get_collision_point()
		var normal = ground_ray.get_collision_normal()
		if velocity.y >= 0:
			if abs(rad2deg(normal.angle_to(Vector2(0, -1)))) < 90:
				return position.y + 25 > point.y
	
	return false

func get_ground_ray():
	can_fall = true
	
	if !left_ground.is_colliding() && !right_ground.is_colliding():
		return null
	elif !left_ground.is_colliding() && right_ground.is_colliding():
		return right_ground
	elif !right_ground.is_colliding() && left_ground.is_colliding():
		return left_ground
	
	can_fall = false
	
	var left_point : float
	var right_point : float
	
	match ground_mode:
		0:
			left_point = -left_ground.get_collision_point().y
			right_point = -right_ground.get_collision_point().y
		1:
			left_point = -left_ground.get_collision_point().x
			right_point = -right_ground.get_collision_point().x
		2:
			left_point = left_ground.get_collision_point().y
			right_point = right_ground.get_collision_point().y
		-1:
			left_point = left_ground.get_collision_point().x
			right_point = right_ground.get_collision_point().x
	
	if left_point >= right_point:
		return left_ground
	else:
		return right_ground

func damage(side:Vector2 = Vector2.ZERO, sound_to_play:String = "hurt"):
	var have_rings:bool = false;
	emit_signal("damaged")
	var timer = Timer.new();
	timer.connect("timeout", self, "vunerable_again", [timer])
	add_child(timer);
	timer.start(2)
	timer_ivun_start(.1)
	
	if !invulnerable:
		velocity.x = side.x * 220
		velocity.y = side.y * 200
		snap_margin = 0
		fsm.change_state("OnAir")
		control_locked = true
		was_damaged = true;
		
		if main_scene:
			var rings = main_scene.ring
			main_scene.ring = 0;
			if rings > 0:
				have_rings = true
				drop_rings(rings);
		if have_rings:
			audio_player.play("ring_loss")
			var ground_angle = ground_angle()
			position += velocity * get_physics_process_delta_time()
		
	else:
		audio_player.play(sound_to_play)
	invulnerable = true;

func drop_rings(rings:int = 0):
	var n = false;
	var drop_max:int = 32;
	var drop_real:int = min(drop_max, rings); 
	var angle = 101.25
	var drop_speed = 200;
	var parent = get_node("/root/main/Level")
	var last_rings:Array = [];
		
	# Add all rings instances to last_rings
	for i in drop_real:
		var instance_ring:KinematicBody2D = ring_scene.instance();
		instance_ring.position = global_position;
		instance_ring.position.y -= 10
		instance_ring.speed.x = cos(angle) * drop_speed;
		instance_ring.speed.y = sin(angle) * drop_speed;
		if n:
			instance_ring.speed.x *= -1
			angle += 22.5;
		n = !n;
		if i == drop_real / 2:
			drop_speed /= 2
			angle = 101.25
		instance_ring.physical = true
		instance_ring.pick_box.set_deferred("disabled", was_damaged)
		last_rings.append(instance_ring);
		
	# Make all rings ignore each other collisions
	for c in last_rings:
		for e in last_rings:
			c.add_collision_exception_with(e);
		
	# Add all rings on level
	for r in last_rings:
		parent.add_child(r);

func timer_ivun_start(time:float):
	var timer_ivun = Timer.new();
	timer_ivun.connect("timeout", self, "toogle_visible", [timer_ivun])
	add_child(timer_ivun);
	timer_ivun.start(time);

func toogle_visible(timer:Timer):
	timer.queue_free();
	character.visible = !character.visible;
	if invulnerable:
		if character.visible:
			timer_ivun_start(0.1);
		else:
			timer_ivun_start(0.025)
	else:
		character.visible = true

func vunerable_again(timer:Timer):
	timer.queue_free();
	invulnerable = false;

func get_class() -> String:
	return "PlayerPhysics"

func is_class(name:String) -> bool:
	return name == get_class();

func smooth_rotate(from:float, to:float, max_speed:float) -> float:
	if from == null || to == null || max_speed == null:
		return 0.0;
	var rot = to - from;
	rot = max(min(rot / 5, max_speed), -max_speed) + max(min(rot, 1), -1)
	return rot;

func set_is_rolling(val : bool):
	if val && !is_rolling:
		audio_player.play('spin')
	is_rolling = val
