extends Node
onready var selected
export(int) var main_player = 0
var player = preload('res://general-objects/players-objects/player-obj.tscn')
class_name PlayersContainer
onready var p_obj = $PlayersObj
onready var spawner = $Spawner
func _ready():
	
	for i in spawner.get_children():
		var point : Vector2 = i.position
		var player_obj = player.instance()
		player_obj.position = point
		player_obj.my_spawn_point = i
		p_obj.add_child(player_obj)
	
	var children = p_obj.get_children()
	for p in children:
		for e in children:
			var player:PlayerPhysics = p as PlayerPhysics
			player.add_collision_exception_with(e)
			player.left_wall.add_exception(e)
			player.left_wall_bottom.add_exception(e)
			player.right_wall.add_exception(e)
			player.right_wall_bottom.add_exception(e)
			player.left_ground.add_exception(e)
			player.right_ground.add_exception(e)
			player.middle_ground.add_exception(e)
	set_main_player(p_obj.get_child(main_player))

func set_main_player(child : PlayerPhysics):
	selected = child.get_position_in_parent()
	child.im_main_player = true

func _unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_released('ui_end'):
		var sel_player = p_obj
		if sel_player:
			var children : Array = sel_player.get_children()
			#print(selected)
			selected += 1
			selected = (selected % children.size())
			var child = sel_player.get_child(selected)
			main_player = children.find(children)
			set_main_player(child)