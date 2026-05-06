extends Node2D

# --- MODES & TOOLS ---
enum Mode { SELECT, DRAW_WALL, ERASE_WALL, MEASURE }
var current_mode: Mode = Mode.SELECT

# --- SELECTION & DRAGGING VARIABLES ---
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO
var is_drawing_box: bool = false      # Used for the blue selection square
var is_dragging_tokens: bool = false  # Used for moving the actual characters
var last_mouse_pos: Vector2 = Vector2.ZERO
var selected_tokens: Array = []

# --- WALL DRAWING VARIABLES ---
var is_drawing_wall: bool = false
var wall_start_pos: Vector2 = Vector2.ZERO
var wall_end_pos: Vector2 = Vector2.ZERO
@onready var wall_layer = $WallLayer # Make sure this matches your new node name!

# --- RULER VARIABLES ---
var is_measuring: bool = false
var measure_start_pos: Vector2 = Vector2.ZERO
var measure_end_pos: Vector2 = Vector2.ZERO

@onready var map_layer = $MapLayer/MapSprite
@onready var gm_layer = $GMLayer
@onready var token_layer = $TokenLayer
@onready var darkness = $Darkness


# Initiative
@onready var token_list = $UILayer/InitiativeTracker/MarginContainer/VBoxContainer/TokenList

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
	# ==========================================
	# MODE 1: SELECTING & DRAGGING TOKENS
	# ==========================================
	if current_mode == Mode.SELECT:
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
	# ==========================================
	# MODE 2: DRAWING WALLS
	# ==========================================
	elif current_mode == Mode.DRAW_WALL:
		if event is InputEventMouseButton:
			# LEFT CLICK: Start drawing or place the wall
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					# We just clicked! Anchor the start point.
					is_drawing_wall = true
					wall_start_pos = get_global_mouse_position()
					wall_end_pos = wall_start_pos
				else:
					# We let go! Save the permanent wall and stop drawing.
					if is_drawing_wall:
						_spawn_permanent_wall(wall_start_pos, wall_end_pos)
						is_drawing_wall = false
						
			# RIGHT CLICK: Cancel the current wall (changed our mind)
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				is_drawing_wall = false
				
			# Tell the board to update our preview line
			queue_redraw() 
			
		# MOUSE MOVE: Update the preview line as we drag
		elif event is InputEventMouseMotion and is_drawing_wall:
			wall_end_pos = get_global_mouse_position()
			queue_redraw()
			
	# ==========================================
	# MODE 3: ERASING WALLS
	# ==========================================
	elif current_mode == Mode.ERASE_WALL:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 1. Ask our helper if we clicked a wall
				var wall_to_delete = _get_wall_under_mouse(get_global_mouse_position())
				
				# 2. If we found one, destroy it!
				if wall_to_delete:
					wall_to_delete.queue_free()
	# ==========================================
	# MODE 4: MEASURING DISTANCE
	# ==========================================
	elif current_mode == Mode.MEASURE:
		if event is InputEventMouseButton:
			# LEFT CLICK: Anchor the start of the tape measure
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_measuring = true
					measure_start_pos = get_snapped_center(get_global_mouse_position())
					measure_end_pos = measure_start_pos
				else:
					# Let go to stop measuring
					is_measuring = false
					
			# RIGHT CLICK: Cancel the measurement
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				is_measuring = false
				
			token_layer.queue_redraw()
			
		# MOUSE MOVE: Stretch the tape measure
		elif event is InputEventMouseMotion and is_measuring:
			measure_end_pos =get_snapped_center(get_global_mouse_position())
			token_layer.queue_redraw()
			##print("Measuring line to: ", measure_end_pos)

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
		
	if is_drawing_wall:
		# Draw a bright red line, 4 pixels thick, to show where the wall goes
		token_layer.draw_line(wall_start_pos, wall_end_pos, Color.RED, 4.0)
	# --- DRAW RULER ---
	if is_measuring:
		# 1. Draw a thick, slightly transparent golden line
		token_layer.draw_line(measure_start_pos, measure_end_pos, Color(0.987, 0.536, 0.942, 0.7), 6.0)
		
		# 2. Calculate the distance in feet (Assuming 64px = 1 grid square = 5ft)
		var pixel_distance = measure_start_pos.distance_to(measure_end_pos)
		var grid_size = 64.0 # Change this if your grid squares are a different size!
		var feet_distance = (pixel_distance / grid_size) * 5.0
		
		# 3. Create the text (e.g., "30 ft.")
		var distance_text = str(round(feet_distance)) + " ft."
		
		# 4. Find the middle of the line to place the text
		var mid_point = (measure_start_pos + measure_end_pos) / 2.0
		var font = ThemeDB.fallback_font # Built-in Godot font
		var font_size = 24
		
		# Draw a black "shadow" text first so it's readable over light maps
		token_layer.draw_string(font, mid_point + Vector2(2, 22), distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
		# Draw the bright white text on top
		token_layer.draw_string(font, mid_point + Vector2(0, 20), distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _spawn_permanent_wall(start: Vector2, end: Vector2):
	if start.distance_to(end) < 5.0:
		return 

	# 1. CREATE THE VISUAL LINE
	var new_wall = Line2D.new()
	new_wall.add_point(start)
	new_wall.add_point(end)
	new_wall.default_color = Color(0.8, 0.1, 0.1, 0.8)
	new_wall.width = 5.0
	
	# 2. ADD PHYSICAL COLLISION (Blocks Tokens)
	var static_body = StaticBody2D.new()
	var collision_shape = CollisionShape2D.new()
	var segment = SegmentShape2D.new()
	segment.a = start
	segment.b = end
	collision_shape.shape = segment
	
	static_body.add_child(collision_shape)
	new_wall.add_child(static_body)
	
	# 3. ADD SHADOW CASTER (Blocks Light)
	var occluder = LightOccluder2D.new()
	var poly = OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([start, end])
	poly.closed = false # CRITICAL: Tells Godot this is a line, not a closed box
	occluder.occluder = poly
	
	new_wall.add_child(occluder)
	
	# 4. ADD TO THE BOARD
	wall_layer.add_child(new_wall)

# INITIATIVE
func _on_roll_init_btn_pressed():
	var all_tokens = $TokenLayer.get_children()
	var active_tokens = []
	
	# 1. Roll the dice for everyone!
	for token in all_tokens:
		if "data" in token: # Make sure it's actually a token with a brain
			# Roll a random number between 1 and 20, then add their bonus
			var roll = randi_range(1, 20)
			token.update_data("current_init", roll + token.data["init_bonus"])
			active_tokens.append(token)
			
	# 2. Sort the list from highest to lowest
	active_tokens.sort_custom(_sort_highest_init)
	
	# 3. Update the UI Panel
	_populate_initiative_ui(active_tokens)

func _sort_highest_init(a, b):
	return a.data["current_init"] > b.data["current_init"]

func _populate_initiative_ui(sorted_tokens: Array):
	# Clear the old names out of the UI
	for child in token_list.get_children():
		child.queue_free()
		
	# Spawn a new label for each token in order
	for token in sorted_tokens:
		var row = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = token.data["name"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Pushes the score to the right
		
		var score_label = Label.new()
		score_label.text = str(token.data["current_init"])
		
		# (Optional Quality of Life: Color the text based on their faction!)
		if token.data["faction"] == "enemy":
			name_label.modulate = Color.RED
			score_label.modulate = Color.RED
		elif token.data["faction"] == "ally":
			name_label.modulate = Color.GREEN
			score_label.modulate = Color.GREEN
			
		row.add_child(name_label)
		row.add_child(score_label)
		
		token_list.add_child(row)

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
	if is_enemy_flag:
		new_token.data["faction"] = "enemy"
	else:
		new_token.data["faction"] = "neutral"
	
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

func _on_gm_dashboard_tool_mode_changed(mode_index: int) -> void:
	# mode_index exactly matches the order of our enum Mode { SELECT, DRAW_WALL }
	current_mode = mode_index as Mode
	
	# If we switch tools while drawing a wall, cancel the wall
	is_drawing_wall = false
	queue_redraw()
	
	print("Tool changed to mode: ", current_mode)

func _get_wall_under_mouse(mouse_pos: Vector2) -> Node2D:
	var best_wall = null
	var min_dist = 15.0 # The "click radius". Adjust if it's too hard to click walls!
	
	# Check every wall we have drawn
	for wall in wall_layer.get_children():
		if wall is Line2D and wall.points.size() >= 2:
			var start = wall.points[0]
			var end = wall.points[1]
			
			# Find the closest point on this line segment to our mouse
			var closest_point = Geometry2D.get_closest_point_to_segment(mouse_pos, start, end)
			var dist = mouse_pos.distance_to(closest_point)
			
			# If it's within our click radius, we found our wall!
			if dist < min_dist:
				min_dist = dist
				best_wall = wall
				
	return best_wall

func get_snapped_center(pos: Vector2) -> Vector2:
	var grid_size = 64.0 # Change this if your base grid size is different!
	
	# 1. Divide by grid size and floor it to find which "column" and "row" we are in
	var snapped_x = floor(pos.x / grid_size) * grid_size
	var snapped_y = floor(pos.y / grid_size) * grid_size
	
	# 2. Add half the grid size to push the coordinate exactly into the center
	var center_offset = grid_size / 2.0
	
	return Vector2(snapped_x + center_offset, snapped_y + center_offset)
