extends Node3D

var player_info

@onready var blue_spawn_1: Node3D = $Blue1
@onready var blue_spawn_2: Node3D = $Blue2
@onready var red_spawn_1: Node3D = $Red1
@onready var red_spawn_2: Node3D = $Red2

@onready var score_label: Label = $Control/Label

# Player Scene
@export var player_scene : PackedScene
@export var ball_scene : PackedScene

var can_score = true
var ball_ref
var blue_score = 0
var red_score = 0
var team = ""

func _ready():
	print("WORLD CREATED")

func add_score(isRed):
	print("POINT SCORED FOR: ")
	if isRed:
		print("BLUE SCORED ON RED")
		blue_score += 1
	else:
		print("RED SCORED ON BLUE")
		red_score += 1
	
	print("Multiplayer ID: " , multiplayer.get_unique_id())
	print(team)
	if team == "RED" or team == "SPECTATOR":
		score_label.text = str(red_score) + " - " + str(blue_score)
	else:
		score_label.text = str(blue_score) + " - " + str(red_score)

func reset_ball():
	# Create a one-shot timer for the delay
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(_move_players_to_position)

func _move_ball_to_position():
	ball_ref.linear_velocity = Vector3(0,0,0)
	ball_ref.angular_velocity = Vector3(0,0,0)
	ball_ref.global_position = get_node("BallSpawn").global_position
	can_score = true

func _move_players_to_position():
	var i = 0
	for player in player_info["RED"]:
		get_node(str(player)).global_position = get_node("Red" + str(i + 1)).global_position
		get_node(str(player)).rotation_degrees.y = 0
	
	i = 0
	for player in player_info["BLUE"]:
		get_node(str(player)).global_position = get_node("Blue" + str(i + 1)).global_position
		get_node(str(player)).rotation_degrees.y = 180
	
	_move_ball_to_position()

func print_player_info():
	print(player_info)

func initialize():
	ball_ref = ball_scene.instantiate()
	
	add_child(ball_ref)
	ball_ref.global_position = get_node("BallSpawn").global_position
	
	print("Initializing")
	var i = 0
	for player in player_info["RED"]:
		var load_player = player_scene.instantiate()
		load_player.name = str(player)
		
		add_child(load_player)
		load_player._set_name(player_info[player])
		load_player.global_position = get_node("Red" + str(i + 1)).global_position
		#load_player.rotation_degrees.y = -90
		
		i += 1

	i = 0
	for player in player_info["BLUE"]:
		var load_player = player_scene.instantiate()
		load_player.name = str(player)
		
		add_child(load_player)
		load_player._set_name(player_info[player])
		load_player.global_position = get_node("Blue" + str(i + 1)).global_position
		load_player.rotation_degrees.y = 180
		
		i += 1
