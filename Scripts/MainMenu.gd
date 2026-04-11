extends Control

# Grab references to our UI nodes
@onready var name_input = $CenterContainer/VBoxContainer/NameInput
@onready var ip_input = $CenterContainer/VBoxContainer/IPInput
@onready var host_button = $CenterContainer/VBoxContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/JoinButton

func _ready():
	# Connect the buttons so they trigger our functions when clicked
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	var player_name = name_input.text
	if player_name == "":
		player_name = "GM"
		
	print("Starting host for: ", player_name)
	# Next phase: We will trigger the NetworkManager to start the server here
	# NetworkManager.host_game(player_name)

func _on_join_pressed():
	var player_name = name_input.text
	if player_name == "":
		player_name = "Player"
		
	var ip_address = ip_input.text
	if ip_address == "":
		ip_address = "127.0.0.1" # Default to localhost for local testing
		
	print(player_name, " is attempting to join IP: ", ip_address)
	# Next phase: We will trigger the NetworkManager to connect to the IP
	# NetworkManager.join_game(ip_address, player_name)
