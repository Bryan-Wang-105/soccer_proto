# main.gd
extends Node

@onready var current_scene_container = $CurrentSceneContainer
@onready var network_manager: Node = $NetworkManager

@export var start_scene : PackedScene

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) 
	# Load initial scene (typically title screen)
	var join_menu = start_scene.instantiate()
	current_scene_container.add_child(join_menu)
