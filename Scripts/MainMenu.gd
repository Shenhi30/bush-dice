extends Control

# Grab references to our UI nodes
@onready var ip_input = $CenterContainer/VBoxContainer/IPInput
@onready var host_button = $CenterContainer/VBoxContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/JoinButton
@onready var load_campaign_btn = $CenterContainer/VBoxContainer/LoadCampaignBtn
@onready var load_dialog = $LoadCampaignDialog
@onready var welcome_label = $CenterContainer/VBoxContainer/WelcomeLabel

# New Settings UI
@onready var change_name_input = $CenterContainer/VBoxContainer/ChangeNameInput
@onready var change_name_btn = $CenterContainer/VBoxContainer/ChangeNameBtn
@onready var feedback_label = $CenterContainer/VBoxContainer/SettingsFeedbackLabel


func _ready():
	# 1. THE BOUNCER CHECK
	# If someone tries to run the MainMenu scene directly without logging in, kick them back.
	if not GameState.is_logged_in:
		get_tree().change_scene_to_file("res://UI/AuthScreen.tscn")
		return

	# 2. UI SETUP
	feedback_label.text = "" # Clear placeholder text
	if welcome_label:
		welcome_label.text = "Logged in as: " + GameState.player_name

	# Connect buttons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	change_name_btn.pressed.connect(_on_change_name_pressed) # CONNECTED NEW BUTTON

	load_campaign_btn.pressed.connect(func(): load_dialog.popup_centered_ratio(0.5))
	load_dialog.file_selected.connect(_on_file_selected)
	
	NetworkManager.connected_to_server.connect(func():
		get_tree().change_scene_to_file("res://Scenes/main_board.tscn")
	)
	
func _on_host_pressed():
	# We use the authenticated name from GameState instead of an input box
	var player_name = GameState.player_name
		
	GameState.set_gm_mode(true)
	
	# BOOT UP THE SERVER!
	NetworkManager.host_game(player_name)
	
	# Initial fresh campaign data
	CampaignManager.current_save_path = ""
	CampaignManager.campaign_data = {
		"campaign_name": "New Campaign",
		"quests": [],
		"active_scene_id": "map_1",
		"scenes": { "map_1": {"map_image_path": "", "map_scale": 1.0, "tokens": [], "walls": []} }
	}
	get_tree().change_scene_to_file("res://Scenes/main_board.tscn")
	

func _on_file_selected(path: String):
	var player_name = GameState.player_name
		
	GameState.set_gm_mode(true)
	
	# BOOT UP THE SERVER!
	NetworkManager.host_game(player_name)
	
	CampaignManager.current_save_path = path
	get_tree().change_scene_to_file("res://Scenes/main_board.tscn")

func _on_join_pressed():
	var player_name = GameState.player_name
		
	var ip_address = ip_input.text
	if ip_address == "":
		ip_address = "127.0.0.1" 
	
	GameState.set_gm_mode(false)
	
	# CONNECT TO THE SERVER!
	NetworkManager.join_game(ip_address, player_name)
	# Notice we are NO LONGER changing scenes directly here!
	# We have to wait for the server to accept us first.

# --- NEW: USERNAME CHANGER LOGIC ---
func _on_change_name_pressed():
	var new_name = change_name_input.text.strip_edges()
	
	# 1. Safety Check
	if new_name == "":
		feedback_label.text = "Name cannot be empty!"
		feedback_label.modulate = Color.RED
		return
		
	if new_name == GameState.player_name:
		feedback_label.text = "That is already your name!"
		feedback_label.modulate = Color.YELLOW
		return
		
	feedback_label.text = "Updating cloud database..."
	feedback_label.modulate = Color.CYAN
	
	# 2. THE CLOUD UPDATE
	# We use .eq("id", GameState.user_id) to ensure they ONLY change their own row!
	var query = SupabaseQuery.new().from("profiles").update({
		"username": new_name
	}).eq("id", GameState.user_id)
	
	var task = Supabase.database.query(query)
	await task.completed
	
	# 3. HANDLE THE RESULT
	if task.error == null:
		# Success! Update our local game brain instantly
		GameState.player_name = new_name
		
		feedback_label.text = "Name successfully changed!"
		feedback_label.modulate = Color.GREEN
		
		# Clear the input box and update the welcome text
		change_name_input.text = ""
		if welcome_label:
			welcome_label.text = "Logged in as: " + GameState.player_name
			
	else:
		# If someone else already took that username
		var err_msg = task.error.message if task.error else "Unknown Error"
		print("DB Error: ", err_msg)
		
		# Supabase usually throws a specific error code for unique constraint violations
		if "duplicate key value" in err_msg.to_lower():
			feedback_label.text = "That name is already taken!"
		else:
			feedback_label.text = "Database error. Try again."
			
		feedback_label.modulate = Color.RED
