extends RefCounted

## Makes a popup window draggable by its title/header control.
static func attach(handle: Control, window: Control) -> void:
	if handle == null or window == null:
		return

	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE

	var state := {
		"dragging": false,
		"offset": Vector2.ZERO,
	}

	handle.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			state["dragging"] = event.pressed
			if event.pressed:
				window.move_to_front()
				state["offset"] = window.get_global_mouse_position() - window.global_position
		elif event is InputEventMouseMotion and state["dragging"]:
			window.global_position = window.get_global_mouse_position() - state["offset"]
	)
