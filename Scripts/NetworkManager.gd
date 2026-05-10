extends Node

const DEFAULT_PORT: int = 8910 # High ports are much safer for custom games!
var peer: ENetMultiplayerPeer

# We need a brain to remember who is sitting at our table
var players: Dictionary = {}
var local_player_name: String = ""

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
	peer = ENetMultiplayerPeer.new()
	
	var error = peer.create_server(DEFAULT_PORT)
	if error != OK:
		print("ERROR: Cannot host! Port already in use?")
		return
		
	multiplayer.multiplayer_peer = peer
	
	# In Godot networking, the Host is ALWAYS assigned the Network ID of 1.
	players[1] = {"name": player_name, "is_gm": true}
	
	# Listen for meatbags joining or leaving
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	server_started.emit()
	print("Server started on port ", DEFAULT_PORT)

func join_game(ip_address: String, player_name: String) -> void:
	local_player_name = player_name
	peer = ENetMultiplayerPeer.new()
	
	var error = peer.create_client(ip_address, DEFAULT_PORT)
	if error != OK:
		print("ERROR: Could not create client!")
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Listen for the server accepting or rejecting our connection
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- NETWORK CALLBACKS ---

func _on_peer_connected(id: int):
	print("New computer connected with Network ID: ", id)
	# Next up: We will send an RPC here to ask them what their name is!

func _on_peer_disconnected(id: int):
	print("Player disconnected: ID ", id)
	players.erase(id)

func _on_connected_to_server():
	print("Successfully connected to the Host!")
	connected_to_server.emit()

func _on_connection_failed():
	print("Failed to connect to the Host. Is the IP correct?")
	connection_failed.emit()

func _on_server_disconnected():
	print("The Host has closed the server.")
	players.clear()

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
	var save_path = "user://" + type + "s/" + file_name # e.g., user://maps/dungeon.jpg
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(buffer)
	file.close()
	
	print("Downloaded custom ", type, " to: ", save_path)
	image_received.emit(save_path, type)
	
