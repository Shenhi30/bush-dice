extends Node

@onready var game_board = $GameBoard
@onready var gm_dashboard = $GMDashboard

func _ready():
	# When the Dashboard emits 'map_loaded', send the path directly to the Board's 'apply_new_map' function
	gm_dashboard.map_loaded.connect(game_board.apply_new_map)
	# NEW Token connection
	gm_dashboard.spawn_token_requested.connect(game_board.spawn_new_token)
