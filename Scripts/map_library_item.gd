extends TextureRect

var map_image_path: String = ""

func _gui_input(event):
	# Listen for a standard Left-Click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var main_board = get_tree().get_first_node_in_group("board")
		
		if main_board:
			# Call your fully-featured map loading function!
			main_board._on_gm_dashboard_map_loaded(map_image_path)
