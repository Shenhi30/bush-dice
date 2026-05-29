extends Control

var inner_radius: float = 40.0
var main_radius: float = 100.0
var sub_radius: float = 160.0
var outer_radius: float = 235.0

var main_button_count: int = 5
var sub_button_count: int = 0
var outer_button_count: int = 0

var active_submenu_angle: float = 0.0 # Stored in radians

# Customization - Match the colors to your image!
var bg_color = Color(0.152, 0.152, 0.179, 0.747) # Dark grey, semi-transparent
var border_color = Color(0.85, 0.75, 0.4, 0.457) # Gold-ish outlines

func _draw():
	var center = Vector2.ZERO
	var main_step = TAU / max(1, main_button_count)
	
	# 1. Draw the Inner Ring (Main Categories)
	for i in range(main_button_count):
		# Start at the top (-90 degrees / -PI/2) and step around
		var start = -PI/2.0 + (i * main_step) - (main_step / 2.0)
		var end = start + main_step
		_draw_wedge(center, inner_radius, main_radius, start, end)

	# 2. Draw the Outer Ring (Submenus) - Only if one is open!
	if sub_button_count > 0:
		var sub_step = main_step
		var start = active_submenu_angle - ((sub_button_count * sub_step) / 2.0)
		
		for i in range(sub_button_count):
			var slice_start = start + (i * sub_step)
			var slice_end = slice_start + sub_step
			# Add a 5-pixel gap between the rings!
			_draw_wedge(center, main_radius + 5, sub_radius, slice_start, slice_end)
			
	if outer_button_count > 0:
		var start = active_submenu_angle - ((outer_button_count * main_step) / 2.0)
		for i in range(outer_button_count):
			var slice_start = start + (i * main_step)
			var slice_end = slice_start + main_step
			_draw_wedge(center, sub_radius + 5, outer_radius, slice_start, slice_end)
			


func _draw_wedge(center: Vector2, r_in: float, r_out: float, a_start: float, a_end: float):
	var pts = PackedVector2Array()
	var steps = 16 # How smooth the curves are
	
	# Calculate Outer Arc
	for i in range(steps + 1):
		var t = a_start + (a_end - a_start) * (float(i) / steps)
		pts.append(center + Vector2(cos(t), sin(t)) * r_out)
		
	# Calculate Inner Arc (Going backwards to complete the shape)
	for i in range(steps + 1):
		var t = a_end - (a_end - a_start) * (float(i) / steps)
		pts.append(center + Vector2(cos(t), sin(t)) * r_in)

	# Paint the wedge
	draw_polygon(pts, PackedColorArray([bg_color]))
	# Paint the gold outline
	pts.append(pts[0]) 
	draw_polyline(pts, border_color, 2.0, true)
