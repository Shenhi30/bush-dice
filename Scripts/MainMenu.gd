extends Control

# Grab references to our UI nodes
@onready var name_input = $CenterContainer/VBoxContainer/NameInput
@onready var ip_input = $CenterContainer/VBoxContainer/IPInput
@onready var host_button = $CenterContainer/VBoxContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/JoinButton
@onready var load_campaign_btn = $CenterContainer/VBoxContainer/LoadCampaignBtn
@onready var load_dialog = $LoadCampaignDialog


func _ready():
	# Connect the buttons so they trigger our functions when clicked
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	load_campaign_btn.pressed.connect(func(): load_dialog.popup_centered_ratio(0.5))
	load_dialog.file_selected.connect(_on_file_selected)
	
	# When the NetworkManager says we successfully connected, THEN load the board!
	NetworkManager.connected_to_server.connect(func():
		get_tree().change_scene_to_file("res://Scenes/main_board.tscn")
	)
	
func _on_host_pressed():
	var player_name = name_input.text
	if player_name == "":
		player_name = "GM"
		
	GameState.player_name = player_name
	GameState.set_gm_mode(true)
	
	# BOOT UP THE SERVER!
	NetworkManager.host_game(player_name)
	
	# Wipe the invisible brain clean for a fresh start:
	CampaignManager.current_save_path = ""
	CampaignManager.campaign_data = {
		"campaign_name": "New Campaign",
		"quests": [],
		"active_scene_id": "map_1",
		"scenes": { "map_1": {"map_image_path": "", "map_scale": 1.0, "tokens": [], "walls": []} }
	}
	get_tree().change_scene_to_file("res://Scenes/main_board.tscn")
	

func _on_file_selected(path: String):
	var player_name = name_input.text
	if player_name == "":
		player_name = "GM"
		
	GameState.player_name = player_name
	GameState.set_gm_mode(true)
	
	# BOOT UP THE SERVER!
	NetworkManager.host_game(player_name)
	
	CampaignManager.current_save_path = path
	get_tree().change_scene_to_file("res://Scenes/main_board.tscn")

func _on_join_pressed():
	var player_name = name_input.text
	if player_name == "":
		player_name = "Player"
		
	var ip_address = ip_input.text
	if ip_address == "":
		ip_address = "127.0.0.1" 
	
	GameState.player_name = player_name
	GameState.set_gm_mode(false)
	
	# CONNECT TO THE SERVER!
	NetworkManager.join_game(ip_address, player_name)
	
	# Notice we are NO LONGER changing scenes directly here!
	# We have to wait for the server to accept us first.
