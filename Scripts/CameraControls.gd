extends Camera2D

# Camera Settings
var zoom_speed = 0.1
var min_zoom = Vector2(0.2, 0.2)
var max_zoom = Vector2(4.0, 4.0)
var is_panning = false

func _unhandled_input(event):
	# 1. Handle Zooming (Scroll Wheel)
	# We still check for mouse buttons here for the scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom -= Vector2(zoom_speed, zoom_speed)
		
		# Keep the zoom within our minimum and maximum limits
		zoom = zoom.clamp(min_zoom, max_zoom)
		
	# 2. Handle Panning State (Spacebar)
	# We now check specifically for a keyboard event and the Space key
	if event is InputEventKey and event.keycode == KEY_CTRL:
		# event.pressed is true when holding the key, and false when you let go
		is_panning = event.pressed

	# 3. Handle Map Dragging (Mouse Movement)
	if event is InputEventMouseMotion and is_panning:
		# Move the camera in the opposite direction of the mouse swipe
		position -= event.relative / zoom
