extends Node

const DEFAULT_PORT: int = 8910 # High ports are much safer for custom games!
var peer: ENetMultiplayerPeer

# We need a brain to remember who is sitting at our table
var players: Dictionary = {}
var local_player_name: String = ""
var local_player_uuid: String = "" # NEW: Store our secret ID

# Signals to tell the UI what just happened
signal server_started
signal connected_to_server
signal connection_failed

func _ready():
	# Create safe storage folders on the user's hard drive
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("maps"):
		dir.make_dir("maps")
	if not dir.dir_exists("tokens"):
		dir.make_dir("tokens")

func host_game(player_name: String) -> void:
	local_player_name = player_name
	local_player_uuid = GameState.user_id # Grab our UUID!
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT)
	if error != OK:
		print("ERROR: Cannot host! Port already in use?")
		return
		
	multiplayer.multiplayer_peer = peer
	
	# In Godot networking, the Host is ALWAYS assigned the Network ID of 1.
	# NEW: We now save the UUID into the host's dictionary slot
	players[1] = {
		"name": local_player_name, 
		"uuid": local_player_uuid, 
		"is_gm": true
	}
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	server_started.emit()
	print("Server started on port ", DEFAULT_PORT)

func join_game(ip_address: String, player_name: String) -> void:
	local_player_name = player_name
	local_player_uuid = GameState.user_id # Grab our UUID!
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, DEFAULT_PORT)
	if error != OK:
		print("ERROR: Could not create client!")
		return
		
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- NETWORK CALLBACKS ---

func _on_peer_connected(id: int):
	print("New computer connected with Network ID: ", id)
	# The host waits for the client to send their info via RPC!

func _on_peer_disconnected(id: int):
	print("Player disconnected: ID ", id)
	players.erase(id)
	# If the host is still here, update the remaining players
	if multiplayer.is_server():
		rpc("sync_player_list", players)

func _on_connected_to_server():
	print("Successfully connected to the Host!")
	# THE HANDSHAKE: We are a client, so we immediately tell the Host (ID 1) who we are!
	rpc_id(1, "register_player", local_player_name, local_player_uuid)
	connected_to_server.emit()

func _on_connection_failed():
	print("Failed to connect to the Host. Is the IP correct?")
	connection_failed.emit()

func _on_server_disconnected():
	print("The Host has closed the server.")
	players.clear()

# --- THE HANDSHAKE PROTOCOL ---

# 1. A client calls this on the Host to register themselves
@rpc("any_peer", "call_remote", "reliable")
func register_player(new_name: String, new_uuid: String):
	var peer_id = multiplayer.get_remote_sender_id()
	print("Registering player: ", new_name, " | UUID: ", new_uuid.substr(0, 8), "...")
	
	# The Host saves the info
	players[peer_id] = {
		"name": new_name,
		"uuid": new_uuid,
		"is_gm": false
	}
	
	# 2. The Host broadcasts the updated master list to EVERYONE
	rpc("sync_player_list", players)

# 3. Everyone updates their local dictionary to match the Host
@rpc("authority", "call_local", "reliable")
func sync_player_list(updated_players: Dictionary):
	players = updated_players
	print("Player list synchronized! Total players at the table: ", players.size())



# --- IMAGE SYNC SYSTEM ---

# Signal to tell the board: "Hey, a new map just finished downloading!"
signal image_received(local_path: String, type: String)

func send_image_to_all(file_path: String, type: String):
	if not FileAccess.file_exists(file_path): return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var buffer = file.get_buffer(file.get_length()) # Convert image to raw bytes
	var file_name = file_path.get_file() # Get just "dragon.png" from the path
	
	# Send the raw bytes to everyone!
	rpc("receive_image_data", file_name, buffer, type)

@rpc("authority", "call_remote", "reliable")
func receive_image_data(file_name: String, buffer: PackedByteArray, type: String):
	var folder_path = "user://" + type + "s/"
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_recursive_absolute(folder_path)
	
	var save_path = "user://" + type + "s/" + file_name # e.g., user://maps/dungeon.jpg
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(buffer)
	file.close()
	
	print("Downloaded custom ", type, " to: ", save_path)
	image_received.emit(save_path, type)
	
