extends Node2D

# Configurable settings for your grid
var grid_size: int = 64 # How many pixels wide/tall each square is
var grid_color: Color = Color(0.584, 0.125, 0.17, 0.555) # White color with 30% opacity
var line_thickness: float = 2.0

var map_size: Vector2 = Vector2.ZERO

# Godot's built-in function for custom drawing
func _draw():
	# Don't draw anything if a map hasn't been loaded yet
	if map_size == Vector2.ZERO:
		return
		
	# Draw vertical lines (Start at 0, go up to map width, stepping by grid_size)
	for x in range(0, map_size.x, grid_size):
		draw_line(Vector2(x, 0), Vector2(x, map_size.y), grid_color, line_thickness)
		
	# Draw horizontal lines (Start at 0, go up to map height, stepping by grid_size)
	for y in range(0, map_size.y, grid_size):
		draw_line(Vector2(0, y), Vector2(map_size.x, y), grid_color, line_thickness)

# We will call this from the GameBoard whenever a new map is loaded
func update_grid(new_map_size: Vector2):
	map_size = new_map_size
	queue_redraw() # Tells Godot to wipe the old lines and run _draw() again
