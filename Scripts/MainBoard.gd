extends Node2D

# --- SELECTION & DRAGGING VARIABLES ---
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO
var is_drawing_box: bool = false      # Used for the blue selection square
var is_dragging_tokens: bool = false  # Used for moving the actual characters
var last_mouse_pos: Vector2 = Vector2.ZERO
var selected_tokens: Array = []

@onready var map_layer = $MapLayer/MapSprite
@onready var gm_layer = $GMLayer
@onready var token_layer = $TokenLayer
@onready var darkness = $Darkness

const TOKEN_SCENE = preload("res://Scenes/token.tscn")

func _ready():
	# By default, we want the global darkness ON to create the Fog of War
	darkness.visible = true
	# Connect to our global GM switch so the GM can toggle the darkness off!
	GameState.gm_mode_changed.connect(_on_gm_mode_changed)
	token_layer.draw.connect(_on_token_layer_draw)

func _get_token_under_mouse(mouse_pos: Vector2):
	# Loop through all tokens backwards (so we grab the one drawn on top first!)
	var tokens = token_layer.get_children()
	for i in range(tokens.size() - 1, -1, -1):
		var token = tokens[i]
		# If the mouse is within 32 pixels of the token's center, we clicked it!
		# (Adjust the 32.0 if your grid squares are bigger or smaller than 64x64)
		if token.global_position.distance_to(mouse_pos) < 32.0:
			return token
	return null # We clicked empty space

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var clicked_token = _get_token_under_mouse(get_global_mouse_position())
			
			if clicked_token:
				# 1. WE CLICKED A TOKEN
				# If we clicked a token that isn't selected yet, clear the others and select only this one
				if not clicked_token in selected_tokens:
					_clear_selection()
					selected_tokens.append(clicked_token)
					if clicked_token.has_method("set_selected"):
						clicked_token.set_selected(true)
				
				# Start moving the tokens!
				is_dragging_tokens = true
				last_mouse_pos = get_global_mouse_position()
				
			else:
				# 2. WE CLICKED EMPTY SPACE
				# Start drawing the blue selection box
				is_drawing_box = true
				drag_start = get_global_mouse_position()
				drag_end = drag_start
				
		else:
			# 3. WE LET GO OF THE MOUSE BUTTON
			if is_drawing_box:
				is_drawing_box = false
				_select_tokens_in_box()
			
			if is_dragging_tokens:
				is_dragging_tokens = false
				# (Later, we can add code right here to "Snap" the tokens perfectly to the grid!)
				
		token_layer.queue_redraw()
		
	elif event is InputEventMouseMotion:
		# 4. WE ARE MOVING THE MOUSE
		if is_drawing_box:
			drag_end = get_global_mouse_position()
			token_layer.queue_redraw()
			
		elif is_dragging_tokens:
			var current_mouse = get_global_mouse_position()
			var drag_offset = current_mouse - last_mouse_pos
			
			# Physically move every selected token by the exact amount the mouse moved
			for token in selected_tokens:
				token.global_position += drag_offset
				
			last_mouse_pos = current_mouse

func _clear_selection():
	for token in selected_tokens:
		if token.has_method("set_selected"):
			token.set_selected(false)
	selected_tokens.clear()

func _select_tokens_in_box():
	var selection_rect = Rect2(drag_start, drag_end - drag_start).abs()
	selected_tokens.clear() # Clear the old selection
	
	# Loop through every token on the board
	for token in token_layer.get_children():
		# Check if the token's center point is inside our drawn box
		if selection_rect.has_point(token.global_position):
			selected_tokens.append(token)
			
			# Shout to the token script to turn on its glowing highlight!
			if token.has_method("set_selected"):
				token.set_selected(true)
		else:
			# Token is outside the box, turn off its highlight
			if token.has_method("set_selected"):
				token.set_selected(false)

func _on_token_layer_draw():
	if is_drawing_box:
		var rect = Rect2(drag_start, drag_end - drag_start).abs() 
		
		# Notice we added "token_layer." before the draw_rect commands!
		token_layer.draw_rect(rect, Color(0.2, 0.5, 1.0, 0.3), true) 
		token_layer.draw_rect(rect, Color(0.2, 0.5, 1.0, 0.8), false, 2.0)

func _on_gm_mode_changed(is_gm: bool):
	# If the GM wants to see the whole map without shadows, 
	# we can optionally turn off the darkness here!
	# (Many GMs like to keep it on to see what the players see, so you can map this to a separate "Toggle Lighting" button later if you prefer!)
# If GM Mode is TRUE, darkness is OFF (visible = false)
	# If GM Mode is FALSE, darkness is ON (visible = true)
	darkness.visible = !is_gm
	
	# Show or hide the GM layer for traps and notes!
	gm_layer.visible = is_gm

# Helper function to spawn tokens cleanly via code later
func add_token_to_board(token_node):
	token_layer.add_child(token_node)

func _on_gm_dashboard_spawn_token_requested(image_path: String, y_offset: float, is_enemy_flag: bool) -> void:
	# 1. Create a brand new copy of the token
	var new_token = TOKEN_SCENE.instantiate()
	
	# 2. Hand over the data from the dashboard BEFORE putting it on the board
	# (Make sure these variable names match what you called them inside Token.gd!)
	new_token.art_path = image_path 
	new_token.height_offset = y_offset
	new_token.is_enemy = is_enemy_flag
	
	# 3. Drop it into the TokenLayer folder
	token_layer.add_child(new_token)
	
	# 4. Move it to the center of the GM's screen!
	var cam = $GMCamera
	if cam:
		new_token.global_position = cam.global_position

func _on_gm_dashboard_map_scale_changed(new_scale: float):
	if map_layer: # This is your MapSprite
		# 1. Apply the scale to the sprite
		map_layer.scale = Vector2(new_scale, new_scale)
		
		# 2. Re-calculate the grid size
		# We take the original image size and multiply by the scale
		if map_layer.texture:
			var original_size = map_layer.texture.get_size()
			var scaled_size = original_size * new_scale
			
			# 3. Tell the grid to redraw at the NEW scaled size
			var grid_node = $MapLayer/GridOverlay
			if grid_node:
				grid_node.update_grid(scaled_size)

func _on_gm_dashboard_map_loaded(file_path: String):
	var image = Image.load_from_file(file_path)
	if image:
		var tex = ImageTexture.create_from_image(image)
		map_layer.texture = tex
		
		# --- FIX STARTS HERE ---
		# 1. Get the actual size of the image in pixels
		var new_size = tex.get_size()
		
		# 2. Find the Grid node and call its update function
		# Based on your tree in image_a9ac20.png, the path is:
		var grid_node = $MapLayer/GridOverlay
		
		if grid_node:
			grid_node.update_grid(new_size) # This matches your screenshot!
		print("Map changed successfully!")
	else:
		push_error("Failed to load image from path: " + file_path)
