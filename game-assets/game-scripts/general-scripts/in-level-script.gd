extends Node
var count:float = 0;
var seconds:float = 0;
var milliseconds:float;
var minutes:float;
var rings:int = 100 setget set_ring;
var time:String;
onready var HUD = get_node_or_null("./HUD")
onready var HUD_count = HUD.get_node_or_null("./Separate/STRCounters/Count")

func _ready():
	set_ring(rings)
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func set_ring(value:int):
	rings = value;
	var ring_counter = HUD_count.get_node_or_null('RingCounter')
	if (ring_counter != null):
		ring_counter.text = String(rings);


func get_global_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()

func _process(delta):
	count += delta;
	seconds = int(count) % 60;
	minutes = floor(count / 60);
	milliseconds = floor((fmod(count, 60) - seconds) * 100);
	time = "%02d'%02d''%02d" % [minutes, seconds, milliseconds]
	var timer_counter = HUD_count.get_node_or_null('TimeCounter')
	if timer_counter != null:
		timer_counter.text = time;

func _unhandled_key_input(event: InputEventKey) -> void:
	if Input.is_action_just_pressed("ui_full_screen"):
		OS.window_fullscreen = !OS.window_fullscreen
