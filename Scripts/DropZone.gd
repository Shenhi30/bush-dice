#extends Control
#
# 1. The mitt asks: "Am I allowed to catch this?"
# func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept it if it's a generic token OR a saved vault player
#	if typeof(data) == TYPE_DICTIONARY:
#		if data.get("type") == "token_drop" or data.get("type") == "vault_drop":
#			return true
#	return false
#
# 2. The mitt catches it and hands it to the Main Board!
#func _drop_data(_at_position: Vector2, data: Variant) -> void:
#	var main_board = get_tree().get_first_node_in_group("board")
#	
#	# (Optional) A quick safety check just to be sure it found it!
#	if not main_board:
#		print("ERROR: Could not find the MainBoard!")
#		return
#	
#	var world_mouse_pos = main_board.get_global_mouse_position()
#	
#	if data["type"] == "token_drop":
#		main_board.spawn_dropped_token(data["path"], data["is_enemy"], world_mouse_pos)
#	elif data["type"] == "vault_drop":
#		main_board.spawn_single_vault_token(data["pc_name"], world_mouse_pos)

extends Control

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# This should print EVERY frame while you are dragging a token
	print("DROPZONE DETECTED DRAG: ", data)
	return true 

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("DROPZONE DROPPED: ", data)
	var main_board = get_tree().get_first_node_in_group("board")
	if main_board:
		var world_mouse_pos = main_board.get_global_mouse_position()
		if data["type"] == "token_drop":
			main_board.spawn_dropped_token(data["path"], data["is_enemy"], world_mouse_pos)
		elif data["type"] == "vault_drop":
			main_board.spawn_single_vault_token(data["pc_name"], world_mouse_pos)
