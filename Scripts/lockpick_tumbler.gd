extends PanelContainer

signal minigame_finished(success: bool)

@onready var timer_bar = $MarginContainer/VBoxContainer/TimerBar
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var pins_grid = $MarginContainer/VBoxContainer/PinsGrid

var time_left: float = 30.0
var minigame_active: bool = true

var total_pins: int = 5
var current_pin_index: int = 0
var pin_nodes = []

var stat_mod_cache: int = 0
var time_limit_cache: int = 30
var initialized_from_code: bool = false

func _ready():
	if get_parent() == get_tree().root and not initialized_from_code:
		initialize(0, 30)
	else:
		_setup_tumbler(stat_mod_cache, time_limit_cache)

func initialize(stat_modifier: int, time_limit: int = 30):
	stat_mod_cache = stat_modifier
	time_limit_cache = time_limit
	initialized_from_code = true
	
	if is_inside_tree():
		_setup_tumbler(stat_mod_cache, time_limit_cache)

func _setup_tumbler(stat_modifier: int, time_limit: int):
	time_left = float(time_limit)
	if timer_bar:
		timer_bar.max_value = time_left
		timer_bar.value = time_left
		
	# Scale pin count based on stats: Lower stats = more pins (harder), higher stats = fewer pins
	total_pins = clampi(12 - stat_modifier, 3, 12)
	if title_label:
		title_label.text = "Lockpicking... (" + str(total_pins) + " Pins)"
		
	_generate_pins()

func _generate_pins():
	# If PinsGrid doesn't exist or isn't assigned, create it via code to prevent blank screens
	if not pins_grid:
		pins_grid = HBoxContainer.new()
		pins_grid.name = "PinsGrid"
		pins_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pins_grid.offset_left = 20
		pins_grid.offset_top = 70
		pins_grid.offset_right = -20
		pins_grid.offset_bottom = -20
		$MarginContainer/VBoxContainer.add_child(pins_grid)
	
	for child in pins_grid.get_children():
		child.queue_free()
	pin_nodes.clear()
	
	# Configure container properties
	if pins_grid is BoxContainer:
		pins_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for i in range(total_pins):
		# Create a visual container for each pin column
		var pin_wrapper = Control.new()
		pin_wrapper.custom_minimum_size = Vector2(35, 230)
		pin_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Background track
		var bg = ColorRect.new()
		bg.color = Color(0.05, 0.08, 0.05, 0.9)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pin_wrapper.add_child(bg)
		
		# Sweet spot zone (randomized vertical range)
		var sweet_spot = ColorRect.new()
		sweet_spot.color = Color(0.1, 0.5, 0.2, 0.9)
		sweet_spot.custom_minimum_size = Vector2(35, 30)
		var random_y = randf_range(30.0, 160.0)
		sweet_spot.position = Vector2(0, random_y)
		pin_wrapper.add_child(sweet_spot)
		
		# Moving pin handle
		var handle = ColorRect.new()
		handle.color = Color(0.7, 0.7, 0.7, 1.0)
		handle.size = Vector2(35, 15)
		handle.position = Vector2(0, 200)
		pin_wrapper.add_child(handle)
		
		pins_grid.add_child(pin_wrapper)
		pin_nodes.append({
			"wrapper": pin_wrapper,
			"handle": handle,
			"sweet_spot": sweet_spot,
			"speed": randf_range(1.5, 3.0),
			"direction": 1,
			"locked": false
		})
		
	current_pin_index = 0
	_update_active_pin_visuals()


func _process(delta):
	if not minigame_active: return
	
	time_left -= delta
	if timer_bar:
		timer_bar.value = time_left
		
	if time_left <= 0:
		_fail_minigame("LOCKOUT: TIME EXPIRED")
		
	# Animate active pin handles moving up and down
	if current_pin_index < pin_nodes.size():
		var p = pin_nodes[current_pin_index]
		if not p["locked"]:
			var handle = p["handle"]
			handle.position.y += p["speed"] * p["direction"] * 150 * delta
			if handle.position.y <= 0 or handle.position.y >= 235:
				p["direction"] *= -1

func _unhandled_input(event):
	if not minigame_active: return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_attempt_lock_pin()

func _attempt_lock_pin():
	if current_pin_index >= pin_nodes.size(): return
	
	var p = pin_nodes[current_pin_index]
	var handle = p["handle"]
	var sweet_spot = p["sweet_spot"]
	
	# Check if handle is inside the sweet spot vertical bounds
	var handle_center = handle.position.y + (handle.size.y / 2.0)
	var spot_top = sweet_spot.position.y
	var spot_bottom = spot_top + sweet_spot.size.y
	
	if handle_center >= spot_top and handle_center <= spot_bottom:
		# SUCCESS
		p["locked"] = true
		handle.color = Color(0.3, 1.0, 0.4)
		current_pin_index += 1
		
		if current_pin_index >= pin_nodes.size():
			_win_minigame()
		else:
			_update_active_pin_visuals()
	else:
		# FAILURE (-5 seconds & shake)
		time_left -= 5.0
		_trigger_screen_shake()

func _update_active_pin_visuals():
	for i in range(pin_nodes.size()):
		var p = pin_nodes[i]
		if i == current_pin_index:
			p["handle"].color = Color(1.0, 0.8, 0.2) # Active gold
		elif not p["locked"]:
			p["handle"].color = Color(0.4, 0.4, 0.4) # Inactive

func _win_minigame():
	minigame_active = false
	minigame_finished.emit(true)
	if title_label:
		title_label.text = "LOCK BYPASSED"
		title_label.add_theme_color_override("font_color", Color(0, 1, 0))
	await get_tree().create_timer(1.2).timeout
	queue_free()

func _fail_minigame(msg: String):
	minigame_active = false
	minigame_finished.emit(false)
	if title_label:
		title_label.text = msg
		title_label.add_theme_color_override("font_color", Color(1, 0, 0))
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _trigger_screen_shake():
	var tween = create_tween()
	var margin_node = $MarginContainer
	if not margin_node: return
	var original_pos = margin_node.position
	for i in range(6):
		var offset = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		tween.tween_property(margin_node, "position", original_pos + offset, 0.04)
	tween.tween_property(margin_node, "position", original_pos, 0.04)
