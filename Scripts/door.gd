extends Node2D

# --- INTERACTIVE DOOR ---
# A door is a line segment placed on a grid edge. Closed doors block token
# movement; open doors do not. Doors can be locked, secret, and named.

var door_id: String = ""
var start_point: Vector2 = Vector2.ZERO
var end_point: Vector2 = Vector2.ZERO

var is_open: bool = false
var is_locked: bool = false
var is_secret: bool = false
var label: String = "Door"
var lock_difficulty: int = 0

var _body: StaticBody2D
var _collision: CollisionShape2D
var _shape: RectangleShape2D

func setup(data: Dictionary) -> void:
	door_id = str(data.get("door_id", ""))
	start_point = Vector2(float(data.get("start_x", 0.0)), float(data.get("start_y", 0.0)))
	end_point = Vector2(float(data.get("end_x", 0.0)), float(data.get("end_y", 0.0)))
	is_open = bool(data.get("is_open", false))
	is_locked = bool(data.get("is_locked", false))
	is_secret = bool(data.get("is_secret", false))
	label = str(data.get("label", "Door"))
	lock_difficulty = int(data.get("lock_difficulty", 0))
	position = start_point

	if is_inside_tree():
		_build_collision()
		_apply_state()
		visible = not is_secret or GameState.is_gm_mode
		queue_redraw()

func _ready() -> void:
	_build_collision()
	_apply_state()
	visible = not is_secret or GameState.is_gm_mode
	queue_redraw()

func _process(_delta: float) -> void:
	# Secret doors are invisible to players until the GM reveals them.
	var should_be_visible = not is_secret or GameState.is_gm_mode
	if visible != should_be_visible:
		visible = should_be_visible

	# Give the GM a subtle translucent look at secret doors so they can edit them.
	if is_secret and GameState.is_gm_mode:
		modulate = Color(1.0, 1.0, 1.0, 0.6)
	else:
		modulate = Color.WHITE

func _build_collision() -> void:
	if _body:
		return

	_body = StaticBody2D.new()
	_body.name = "DoorBody"

	_shape = RectangleShape2D.new()
	_collision = CollisionShape2D.new()
	_collision.name = "DoorCollision"
	_collision.shape = _shape

	_body.add_child(_collision)
	add_child(_body)

func _apply_state() -> void:
	if not _collision:
		return

	var segment = end_point - start_point
	var length = maxf(segment.length(), 1.0)

	_collision.disabled = is_open
	_shape.size = Vector2(length, 12.0)
	_body.position = segment / 2.0
	_collision.rotation = segment.angle()

	queue_redraw()

func apply_state(key: String, value, _is_from_network: bool = false) -> void:
	match key:
		"is_open":
			is_open = bool(value)
		"is_locked":
			is_locked = bool(value)
		"is_secret":
			is_secret = bool(value)
		"label":
			label = str(value)
		"lock_difficulty":
			lock_difficulty = int(value)
		_:
			return

	_apply_state()

func to_dict() -> Dictionary:
	return {
		"door_id": door_id,
		"start_x": start_point.x,
		"start_y": start_point.y,
		"end_x": end_point.x,
		"end_y": end_point.y,
		"is_open": is_open,
		"is_locked": is_locked,
		"is_secret": is_secret,
		"label": label,
		"lock_difficulty": lock_difficulty
	}

func distance_to_segment(world_position: Vector2) -> float:
	var world_start = to_global(Vector2.ZERO)
	var world_end = to_global(end_point - start_point)
	var closest = Geometry2D.get_closest_point_to_segment(world_position, world_start, world_end)
	return world_position.distance_to(closest)

func _draw() -> void:
	var local_end = end_point - start_point
	var length = local_end.length()
	if length < 1.0:
		return

	var direction = local_end / length
	var normal = direction.orthogonal()
	var middle = local_end / 2.0

	if is_open:
		# Threshold line plus a door leaf swung open around the hinge.
		draw_line(Vector2.ZERO, local_end, Color(0.35, 0.75, 0.4, 0.75), 3.0)
		draw_line(Vector2.ZERO, normal * (length * 0.82), Color(0.48, 0.3, 0.15), 8.0)
		draw_line(Vector2.ZERO, normal * (length * 0.82), Color(0.72, 0.48, 0.23), 4.0)
	else:
		# The door slab.
		draw_line(Vector2.ZERO, local_end, Color(0.18, 0.11, 0.05), 20.0)
		draw_line(Vector2.ZERO, local_end, Color(0.48, 0.3, 0.15), 14.0)
		draw_line(Vector2.ZERO, local_end, Color(0.7, 0.46, 0.22), 8.0)

		# Simple plank detail.
		draw_line(
			middle + normal * 3.0 - direction * (length * 0.22),
			middle + normal * 3.0 + direction * (length * 0.22),
			Color(0.32, 0.19, 0.09, 0.8),
			2.0
		)
		draw_line(
			middle - normal * 3.0 - direction * (length * 0.22),
			middle - normal * 3.0 + direction * (length * 0.22),
			Color(0.32, 0.19, 0.09, 0.8),
			2.0
		)

		# Knob.
		var knob = local_end * 0.5 + direction * (length * 0.32) + normal * 5.0
		draw_circle(knob, 4.0, Color(1.0, 0.84, 0.25))

	if is_locked:
		var lock_pos = middle + Vector2(0, -18)
		draw_circle(lock_pos, 10.0, Color(0.05, 0.05, 0.06, 0.9))
		draw_arc(lock_pos, 6.0, PI, TAU, 10, Color(1.0, 0.82, 0.2), 2.0)
		draw_rect(Rect2(lock_pos + Vector2(-5, -3), Vector2(10, 9)), Color(1.0, 0.82, 0.2))
		draw_circle(lock_pos + Vector2(0, 1), 1.4, Color(0.1, 0.06, 0.02))

	if is_secret and GameState.is_gm_mode:
		draw_arc(middle, 16.0, 0, TAU, 24, Color(0.65, 0.4, 1.0, 0.7), 2.0)

	if label != "" and label != "Door":
		var font = ThemeDB.fallback_font
		draw_string(
			font,
			middle + Vector2(-60, -26),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			120,
			14,
			Color.WHITE
		)
