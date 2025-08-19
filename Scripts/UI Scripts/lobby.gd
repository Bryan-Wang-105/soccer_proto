extends Control

# UI Nodes 
@onready var host_message: Label = $"HostMessage"
@onready var spectator_list: Label = $SpectatorList
@onready var join_red: Button = $JoinRed
@onready var join_blue: Button = $JoinBlue
@onready var start_match: Button = $"StartMatch"

@onready var red_team_label: Label = $RedTeam/RedTeamLabel
@onready var r_v_box_container: VBoxContainer = $RedTeam/VBoxContainer
@onready var blue_team_label: Label = $BlueTeam/BlueTeamLabel
@onready var b_v_box_container: VBoxContainer = $BlueTeam/VBoxContainer

# Player nodes:
var network_id

# Scene Management
@onready var network_manager = $"../../NetworkManager"
@onready var current_scene_container: Node = $"../"
@export var next_scene_packed : PackedScene

var ID

func _ready():
	# If not host, different appearance
	if not network_manager.is_host:
		ID = "[Client]"
		start_match.visible = false
	else:
		ID = "[Server]"
	
	# Get network ID
	network_id = network_manager.network_id
	print(ID + " Lobby UI -> Ready")
	
	network_manager.connect("update_ui", update_lobby)
	
	# Initialize the lobby UI if host
	if network_manager.is_host:
		_initialize_lobby_ui()
	
	# Don't know fix here still
	var deleteMenu = $"../".has_node("JoinMenu")
	if deleteMenu:
		$"../".get_node("JoinMenu").queue_free()

func _initialize_lobby_ui():
	print(ID + " Lobby UI: Initializing lobby UI")
	# Try to get lobby info with timeout
	var lobby_info = network_manager.player_information
	if lobby_info:
		print(ID + " Lobby UI: Found lobby info, updating UI")
		update_lobby()
	else:
		print(ID +  " Lobby UI: No lobby info found, will wait for signal")

func update_lobby():
	# Try to get lobby info with timeout
	var lobby_info = network_manager.player_information
	if lobby_info:
		print(ID + " Lobby UI: Found lobby info, updating UI")
	else:
		print(ID +  " Lobby UI: No lobby info found, will wait for signal")
		return
	
	_populate_spectator_list(lobby_info)
	_populate_team_lists(lobby_info)

func _populate_spectator_list(lobby_state):
	if len(lobby_state["SPECTATOR"]) == 0:
		spectator_list.text = "None"
	else:
		print(lobby_state["SPECTATOR"])
		var combined_list = []
		var spectators = lobby_state["SPECTATOR"]
		
		if len(spectators) == 1:
			combined_list = lobby_state[spectators[0]]
		else:
			for id in spectators:
				combined_list.append(lobby_state[id])
				
			combined_list = ", ".join(combined_list)
		
		spectator_list.text = combined_list

func _populate_team_lists(lobby_state):
	# Clear existing team lists
	for child in r_v_box_container.get_children():
		child.queue_free()
	for child in b_v_box_container.get_children():
		child.queue_free()
	
	# Populate red team
	if lobby_state["RED"].size() > 0:
		if lobby_state["RED"].size() == 2:
			join_red.disabled = true
		else:
			join_red.disabled = false
		red_team_label.text = "Red Team (" + str(lobby_state["RED"].size()) + ")"
		for player_id in lobby_state["RED"]:
			var label = Label.new()
			label.text = lobby_state[player_id]
			r_v_box_container.add_child(label)
	else:
		red_team_label.text = "Red Team (0)"
	
	# Populate blue team
	if lobby_state["BLUE"].size() > 0:
		if lobby_state["BLUE"].size() == 2:
			join_blue.disabled = true
		else:
			join_blue.disabled = false
		blue_team_label.text = "Blue Team (" + str(lobby_state["BLUE"].size()) + ")"
		for player_id in lobby_state["BLUE"]:
			var label = Label.new()
			label.text = lobby_state[player_id]
			b_v_box_container.add_child(label)
	else:
		blue_team_label.text = "Blue Team (0)"

#func 

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_join_red_pressed() -> void:
	print(ID + " Changing Teams to RED")
	network_manager.move_player_to_red(network_id)

func _on_join_blue_pressed() -> void:
	print(ID + " Changing Teams to BLUE")
	network_manager.move_player_to_blue(network_id)

func _on_start_match_pressed() -> void:
	# Don't know fix here still
	var deleteMenu = $"../".has_node("JoinMenu")
	if deleteMenu:
		$"../".get_node("JoinMenu").queue_free()
		
	# Get the spawner
	var multi_spawner = get_node("../MultiplayerSpawner")

	# Create world and add it to tree
	var next_scene = next_scene_packed.instantiate()
	current_scene_container.add_child(next_scene)
	
	# Let the world know what team the player is on
	if network_id in network_manager.player_information["RED"]:
		next_scene.team = "RED"
	elif network_id in network_manager.player_information["BLUE"]:
		next_scene.team = "BLUE"
	else:
		next_scene.team = "SPECTATOR"

	# Set spawn path
	multi_spawner.spawn_path = "Root/CurrentSceneContainer/Sandbox"
	
	# Tune the world
	next_scene.player_info = network_manager.player_information
	next_scene.print_player_info()
	
	# Initialize the world
	next_scene.initialize()
	
	# Start match
	network_manager.start_match()
