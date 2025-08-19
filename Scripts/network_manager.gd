extends Node

# Variables
var peer = ENetMultiplayerPeer.new()
var is_host = false
var display_name
var network_id
var PORT = 1231
var ip_addy = "104.175.194.109"
var local = "localhost"

# Player information
var player_information = {}

# UI Node
var lobby_ui

signal update_ui

# Create server to host a game
func create_server(name) -> void:
	# Create server
	peer.create_server(PORT)
	
	upnp_setup()
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Add host player
	is_host = true
	display_name = name
	network_id = multiplayer.get_unique_id()
	print("[Host] Hosting on port ", PORT)
	
	# Create game-lobby state
	player_information[network_id] = display_name  # Fixed: Store name directly
	player_information["RED"] = [network_id]     # Host goes to red team
	player_information["BLUE"] = []
	player_information["SPECTATOR"] = []
	
	print("[Host] created player information dict: ", player_information)

# Create client to join a hosted game lobby
func create_client(name) -> void:
	display_name = name
	peer.create_client(ip_addy, PORT)
	
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	network_id = multiplayer.get_unique_id()
	
	print("[Client] Joining local host on port: ", PORT)

# --- SERVER SIDE ---
#region UPNP Setup
## Sets up UPNP for internet connectivity
func upnp_setup() -> void:
	var upnp := UPNP.new()
	
	# Try to discover UPNP gateway
	var discover_result := upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, 
		"UPNP Discover Failed! Error %s" % discover_result)
	
	# Verify gateway validity
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), 
		"UPNP Invalid Gateway!")
	
	# Setup port forwarding
	var map_result := upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, 
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Host launch Success! Join IP Address: %s\n" % upnp.query_external_address())
#endregion

func _on_peer_connected(id: int):
	print("[Server] Peer connected: ", id)
	# Add placeholder for new player (will be updated when they send their name)
	player_information[id] = "TEMP NAME"
	player_information["SPECTATOR"].append("TEMP NAME")

func _on_peer_disconnected(id: int):
	print("[Server] Peer disconnected: ", id)
	if id in player_information:
		var player_name = player_information[id]
		
		# Remove from all teams
		player_information["RED"].erase(id)
		player_information["BLUE"].erase(id)
		player_information["SPECTATOR"].erase(id)
		
		# Remove from player dict
		player_information.erase(id)
		
		# Sync updated state to all clients
		_rpc_sync_clients.rpc(player_information)

# This RPC is defined here so clients can send their name to the server
@rpc("any_peer", "reliable")
func _rpc_set_player_name(peer_id: int, name: String):
	if not is_host:
		return  # Only server should handle this
		
	print("[Server] Updating name for peer ", peer_id, " -> ", name)
	
	# Remove old temp name from spectator
	player_information["SPECTATOR"].erase("TEMP NAME")
	
	# Update player name
	player_information[peer_id] = name
	
	# Add to spectator team by default
	player_information["SPECTATOR"].append(peer_id)
	
	print("[Server] Updated player_information: ", player_information)
	
	# Sync to all clients
	_rpc_sync_clients.rpc(player_information)
	emit_signal("update_ui")

@rpc("authority", "reliable")  # Fixed: Only server should call this
func _rpc_sync_clients(new_player_information):
	print("[CLIENT ", network_id, "] Updating the player information dict")
	player_information = new_player_information
	print("[CLIENT ", network_id, "] New player_information: ", player_information)
	
	print()
	emit_signal("update_ui")

# Host calls this when UI btn is pressed and calls RPC on all clients
func start_match():
	if is_host:
		lobby_ui.visible = false
		_rpc_start_match.rpc()

# Host makes all clients run this
@rpc("authority", "reliable")
func _rpc_start_match():
	lobby_ui.visible = false
	lobby_ui._on_start_match_pressed()

# --- CLIENT SIDE ---
func _on_connected_to_server():
	print("[Client] Connected to server, sending display name: ", display_name)
	# Fixed: Use correct RPC call
	_rpc_set_player_name.rpc_id(1, multiplayer.get_unique_id(), display_name)

# Helper functions for team management (call these from UI)
@rpc("any_peer", "reliable")
func _rpc_move_player_to_team(peer_id: int, target_team: String):
	if not is_host:
		return  # Only server handles team changes
		
	if peer_id not in player_information:
		return
		
	var player_name = player_information[peer_id]
	
	# Remove from all teams
	player_information["RED"].erase(peer_id)
	player_information["BLUE"].erase(peer_id)
	player_information["SPECTATOR"].erase(peer_id)
	
	# Add to target team
	if target_team in ["RED", "BLUE", "SPECTATOR"]:
		player_information[target_team].append(peer_id)
		print("[Server] Moved ", player_name, " to ", target_team, " team")
		print("[Server] Updated player_information: ", player_information)
		
		emit_signal("update_ui")
		
		# Sync to all clients
		_rpc_sync_clients.rpc(player_information)


# UI Helper functions (call these from buttons)
func move_player_to_red(peer_id: int):
	if is_host:
		_rpc_move_player_to_team(peer_id, "RED")
	else:
		_rpc_move_player_to_team.rpc_id(1, peer_id, "RED")

func move_player_to_blue(peer_id: int):
	if is_host:
		_rpc_move_player_to_team(peer_id, "BLUE")
	else:
		_rpc_move_player_to_team.rpc_id(1, peer_id, "BLUE")

func move_player_to_spectator(peer_id: int):
	if is_host:
		_rpc_move_player_to_team(peer_id, "SPECTATOR")
	else:
		_rpc_move_player_to_team.rpc_id(1, peer_id, "SPECTATOR")

# Debug function to print current state
func print_lobby_state():
	print("=== LOBBY STATE ===")
	print("RED Team: ", player_information.get("RED", []))
	print("BLUE Team: ", player_information.get("BLUE", []))
	print("SPECTATORS: ", player_information.get("SPECTATOR", []))
	print("All Players: ")
	for pid in player_information:
		if pid is int:  # Skip team arrays
			print("  ", pid, ": ", player_information[pid])
	print("===================")
