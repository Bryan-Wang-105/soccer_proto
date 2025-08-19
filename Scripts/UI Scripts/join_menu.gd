extends Control


@onready var host: Button = $VBoxContainer/Host
@onready var join: Button = $VBoxContainer/Join
@onready var title: Label = $Control/Label
@onready var lineEdit: LineEdit = $LineEdit
@onready var loading: Label = $Loading

@onready var root = $"../../"
@onready var current_scene_container: Node = $"../"
@export var next_scene_packed : PackedScene


func _on_host_pressed() -> void:
	if lineEdit.text == "":
		return
	
	print(loading.visible)
	loading.visible = true
	print(loading.visible)
	
	root.network_manager.create_server(lineEdit.text)
	
	var next_scene = next_scene_packed.instantiate()
	root.network_manager.lobby_ui = next_scene
	current_scene_container.add_child(next_scene)
	
	queue_free()

func _on_join_pressed() -> void:
	if lineEdit.text == "":
		return
	
	root.network_manager.create_client(lineEdit.text)
	var next_scene = next_scene_packed.instantiate()
	root.network_manager.lobby_ui = next_scene
	current_scene_container.add_child(next_scene)
   
	queue_free()

func _on_exit_pressed() -> void:
	get_tree().quit()
