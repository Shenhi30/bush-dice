extends Node2D

@onready var map_layer = $MapLayer
@onready var grid_overlay = $MapLayer/GridOverlay # Get our new node

# Preload the token blueprint so the board knows how to build one
var token_scene = preload("res://Scenes/Token.tscn")


func apply_new_map(path: String):
	var image = Image.load_from_file(path)
	if image != null:
		var texture = ImageTexture.create_from_image(image)
		map_layer.texture = texture
		
		# Get the exact pixel dimensions of the newly loaded map
		var map_dimensions = texture.get_size()
		
		# Tell the grid to calculate and draw the lines over the new dimensions
		grid_overlay.update_grid(map_dimensions)
		
		print("Board updated. Size: ", map_dimensions)
	else:
		push_error("Failed to load map.")
# NEW: The function that builds and places the token
func spawn_new_token(image_path: String, y_offset: float, is_enemy_flag: bool):
	# 1. Create a brand new token from your scene
	var new_token = token_scene.instantiate()
	
	# 2. Load the art from your PC
	var image = Image.load_from_file(image_path)
	if image != null:
		var texture = ImageTexture.create_from_image(image)
		new_token.get_node("Sprite2D").texture = texture
	
	# 3. Apply the custom Y-Offset from your Dashboard spinbox
		new_token.label_y_offset = y_offset
	
	# 4. Give it a default name based on the file name (e.g., "Samurai.png" -> "Samurai")
		new_token.character_name = image_path.get_file().get_basename()
	
	# NEW: Apply the checkbox status to the token before adding it
		new_token.is_enemy = is_enemy_flag
	
	# 5. Add it to the board!
		add_child(new_token)
	
	# 6. Put it right in the center of the GM's screen
		var camera = $GMCamera
		new_token.global_position = camera.get_screen_center_position()
	
	# 7. Tell the token to run its math so it scales the new image correctly
		new_token.normalize_size()
	
	print("Spawned token: ", new_token.character_name)
