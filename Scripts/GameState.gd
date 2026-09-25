extends Node

# --- CLOUD IDENTITY ---
var user_id: String = ""         # Stores the Supabase UUID (e.g. "550e8400-e29b...")
var is_logged_in: bool = false   # Helps guards scenes from unauthorized access
var session_token: String = ""   # Optional: useful for direct API calls

# --- GM & PLAYER ROLES ---
var is_gm_mode: bool = false
var is_gm_vision_active: bool = false 
var player_name: String = ""
var player_uuid: String = ""

var show_floating_text: bool = true

signal gm_mode_changed(is_gm)

var player_color_hex: String = "#ffffff" # Білий за замовчуванням

func _ready():
	load_player_settings()

func save_player_settings(new_color_hex: String):
	player_color_hex = new_color_hex
	var config = ConfigFile.new()
	config.set_value("Player", "color", player_color_hex)
	config.save("user://player_settings.cfg")

func load_player_settings():
	var config = ConfigFile.new()
	if config.load("user://player_settings.cfg") == OK:
		player_color_hex = config.get_value("Player", "color", "#ffffff")

# --- ROLE LOGIC ---
func set_gm_mode(is_gm: bool):
	is_gm_mode = is_gm
	gm_mode_changed.emit(is_gm_mode)

func toggle_gm_mode():
	is_gm_mode = !is_gm_mode
	gm_mode_changed.emit(is_gm_mode)

# --- MULTIPLAYER RPCs ---
@rpc("authority", "call_remote", "reliable")
func receive_gm_promotion(is_now_gm: bool):
	set_gm_mode(is_now_gm)
	if is_now_gm:
		print("The Host has promoted you to Game Master!")
	else:
		print("Your Game Master privileges have been revoked.")
