extends Control


@onready var host: Button = $VBoxContainer/Host
@onready var join: Button = $VBoxContainer/Join
@onready var title: Label = $Control/Label
@onready var text_edit: TextEdit = $TextEdit

@onready var root = $"../../"
@onready var current_scene_container: Node = $"../"
@export var next_scene_packed : PackedScene

func _on_host_pressed() -> void:
	if text_edit.text == "":
		return
	
	root.network_manager.create_server(text_edit.text)
	
	var next_scene = next_scene_packed.instantiate()
	root.network_manager.lobby_ui = next_scene
	current_scene_container.add_child(next_scene)
	
	queue_free()

func _on_join_pressed() -> void:
	if text_edit.text == "":
		return
	
	root.network_manager.create_client(text_edit.text)
	var next_scene = next_scene_packed.instantiate()
	root.network_manager.lobby_ui = next_scene
	current_scene_container.add_child(next_scene)
   
	queue_free()

func _on_exit_pressed() -> void:
	get_tree().quit()
