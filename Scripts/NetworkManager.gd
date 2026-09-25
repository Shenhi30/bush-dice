extends Node

const DEFAULT_PORT: int = 8910 # High ports are much safer for custom games!
var peer: ENetMultiplayerPeer

# We need a brain to remember who is sitting at our table
var players: Dictionary = {}
var local_player_name: String = ""
var local_player_uuid: String = "" # Store our secret ID

# UPnP Setup
var upnp: UPNP = null
var upnp_thread: Thread = null
var public_ip: String = ""

# Signals to tell the UI what just happened
signal server_started
signal connected_to_server
signal connection_failed
signal upnp_completed(server_ip: String) # Emits the public IP for easy UI display!

func _ready():
	# Create safe storage folders on the user's hard drive
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("maps"):
		dir.make_dir("maps")
	if not dir.dir_exists("tokens"):
		dir.make_dir("tokens")

func _exit_tree():
	# Clean up port forwarding when the game exits
	_close_upnp()

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
	players[1] = {
		"name": local_player_name, 
		"uuid": local_player_uuid, 
		"is_gm": true
	}
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	server_started.emit()
	print("Server started on port ", DEFAULT_PORT)
	
	# Start UPnP on a background thread so the UI doesn't stutter
	_start_upnp_thread(DEFAULT_PORT)

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

# --- UPNP LOGIC ---

func _start_upnp_thread(port: int) -> void:
	upnp_thread = Thread.new()
	upnp_thread.start(_setup_upnp.bind(port))

func _setup_upnp(port: int) -> void:
	upnp = UPNP.new()
	print("UPnP: Discovering gateway...")
	
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		push_warning("UPnP Discover failed with code: %s" % discover_result)
		_notify_upnp_result.call_deferred("")
		return
		
	var gateway = upnp.get_gateway()
	if not gateway or not gateway.is_valid_gateway():
		push_warning("UPnP: No valid gateway found.")
		_notify_upnp_result.call_deferred("")
		return
		
	var map_result = upnp.add_port_mapping(port, port, "BushDice VTT", "UDP")
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		push_warning("UPnP Port Mapping failed with code: %s" % map_result)
		_notify_upnp_result.call_deferred("")
		return
		
	public_ip = upnp.query_external_address()
	print("UPnP: Successfully opened port %d! Public IP: %s" % [port, public_ip])
	_notify_upnp_result.call_deferred(public_ip)

func _notify_upnp_result(ip_found: String) -> void:
	if upnp_thread and upnp_thread.is_started():
		upnp_thread.wait_to_finish()
	upnp_completed.emit(ip_found)

func _close_upnp() -> void:
	if upnp_thread and upnp_thread.is_alive():
		upnp_thread.wait_to_finish()
	if upnp:
		upnp.delete_port_mapping(DEFAULT_PORT, "UDP")
		print("UPnP: Port mapping removed.")
		upnp = null

# --- NETWORK CALLBACKS ---

func _on_peer_connected(id: int):
	print("New computer connected with Network ID: ", id)

func _on_peer_disconnected(id: int):
	print("Player disconnected: ID ", id)
	players.erase(id)
	if multiplayer.is_server():
		rpc("sync_player_list", players)

func _on_connected_to_server():
	print("Successfully connected to the Host!")
	rpc_id(1, "register_player", local_player_name, local_player_uuid)
	connected_to_server.emit()

func _on_connection_failed():
	print("Failed to connect to the Host. Is the IP correct?")
	connection_failed.emit()

func _on_server_disconnected():
	print("The Host has closed the server.")
	players.clear()
	_close_upnp()

# --- THE HANDSHAKE PROTOCOL ---

@rpc("any_peer", "call_remote", "reliable")
func register_player(new_name: String, new_uuid: String):
	var peer_id = multiplayer.get_remote_sender_id()
	print("Registering player: ", new_name, " | UUID: ", new_uuid.substr(0, 8), "...")
	
	players[peer_id] = {
		"name": new_name,
		"uuid": new_uuid,
		"is_gm": false
	}
	
	rpc("sync_player_list", players)

@rpc("authority", "call_local", "reliable")
func sync_player_list(updated_players: Dictionary):
	players = updated_players
	print("Player list synchronized! Total players at the table: ", players.size())

# --- IMAGE SYNC SYSTEM ---

signal image_received(local_path: String, type: String)

func send_image_to_all(file_path: String, type: String):
	if not FileAccess.file_exists(file_path): return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var buffer = file.get_buffer(file.get_length())
	var file_name = file_path.get_file()
	
	rpc("receive_image_data", file_name, buffer, type)

@rpc("authority", "call_remote", "reliable")
func receive_image_data(file_name: String, buffer: PackedByteArray, type: String):
	var folder_path = "user://" + type + "s/"
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_recursive_absolute(folder_path)
	
	var save_path = "user://" + type + "s/" + file_name
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(buffer)
	file.close()
	
	print("Downloaded custom ", type, " to: ", save_path)
	image_received.emit(save_path, type)
