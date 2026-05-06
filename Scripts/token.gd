extends CharacterBody2D


# --- STATS & STATE ---

# The Token's "Brain"
var data: Dictionary = {
	"name": "Unknown",
	"hp": 20,
	"max_hp": 20,
	"ac": 10,
	"speed": 30,
	"faction": "neutral", # Can be "neutral", "enemy", or "ally"
	"is_dead": false,
	"is_status_active": false,
	"status_color": "c45500b2", # Saved as a hex string so it can be written to JSON later!
	"init_bonus": 2,
	"current_init": 0
}

var current_aura_radius: float = 0.0
var current_aura_color: Color = Color(0.0, 1.0, 0.0, 0.2) 
var name_color:Color = Color.WHITE
var current_main_btns: Array = []

var manual_stretch: Vector2 = Vector2(1.0, 1.0)
var is_resizing: bool = false

var art_path: String = ""
var height_offset: float = 0.0

# --- DISPLAY SETTINGS ---
@export var grid_size_in_squares: int = 1 
@export var is_standee: bool = false
@export var label_y_offset: float = 0.0
var base_cell_size: float = 64.0 
@export var grid_offset: Vector2 = Vector2.ZERO 

# --- MOVEMENT VARIABLES ---
@export var move_speed: float = 300.0
var dragging: bool = false
var is_hovered: bool = false
var is_selected: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO

# --- NODE REFERENCES ---
@onready var name_label = $UI/NameLabel
@onready var hp_bar = $UI/HPBar
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var vision_light = $VisionLight


@onready var highlight_ring = $HightLightRing
# --- MENU REFERENCES ---
@onready var token_menu = $UI/TokenMenu
@onready var main_menu = $UI/TokenMenu/MainMenu
@onready var hp_main_btn = $UI/TokenMenu/MainMenu/HPMainBtn
@onready var hide_btn = $UI/TokenMenu/MainMenu/HideBtn
@onready var status_btn = $UI/TokenMenu/MainMenu/StatusBtn
@onready var aura_btn = $UI/TokenMenu/MainMenu/AuraBtn
@onready var light_btn = $UI/TokenMenu/MainMenu/LightBtn
@onready var state_btn = $UI/TokenMenu/MainMenu/StateBtn
@onready var edit_btn = $UI/TokenMenu/MainMenu/EditBtn

@onready var hp_action_menu = $UI/TokenMenu/HPActionMenu
@onready var amount_spinbox = $UI/TokenMenu/HPActionMenu/AmountSpinBox
@onready var damage_btn = $UI/TokenMenu/HPActionMenu/DamageBtn
@onready var heal_btn = $UI/TokenMenu/HPActionMenu/HealBtn
@onready var level_up_btn = $UI/TokenMenu/HPActionMenu/LevelUpBtn

@onready var status_menu = $UI/TokenMenu/StatusMenu
@onready var status_color_picker = $UI/TokenMenu/StatusMenu/StatusColorPicker
@onready var clear_status_btn = $UI/TokenMenu/StatusMenu/ClearStatusBtn

@onready var aura_menu = $UI/TokenMenu/AuraMenu
@onready var aura_radius_spin = $UI/TokenMenu/AuraMenu/AuraRadiusSpinBox
@onready var aura_color_picker = $UI/TokenMenu/AuraMenu/AuraColorPicker
@onready var clear_aura_btn = $UI/TokenMenu/AuraMenu/ClearAuraBtn

@onready var light_menu = $UI/TokenMenu/LightMenu
@onready var light_radius_spin = $UI/TokenMenu/LightMenu/LightRadiusSpinBox
@onready var clear_light_btn = $UI/TokenMenu/LightMenu/ClearLightBtn

@onready var edit_menu = $UI/TokenMenu/EditMenu
@onready var name_input = $UI/TokenMenu/EditMenu/NameInput
@onready var base_color_picker = $UI/TokenMenu/EditMenu/BaseColorPicker
@onready var ac_spinbox = $UI/TokenMenu/EditMenu/ACSpinBox
@onready var speed_spinbox = $UI/TokenMenu/EditMenu/SpeedSpinBox
@onready var init_bonus_spinbox = $UI/TokenMenu/EditMenu/InitBonusSpinBox
@onready var close_edit_btn = $UI/TokenMenu/EditMenu/CloseEditBtn

@onready var resize_handle = $UI/ResizeHandle

func _ready():
	name_label.text = data["name"]
	hp_bar.max_value = data["max_hp"]
	hp_bar.value = data["hp"]
	name_label.modulate = name_color
	
	
	_style_radial_spinbox(ac_spinbox)
	_style_radial_spinbox(speed_spinbox)
	_style_radial_spinbox(init_bonus_spinbox)
	
	update_visuals()
	
	if art_path != "":
		var new_texture = load(art_path)
		if new_texture:
			sprite.texture = new_texture
			
	# Apply the custom height offset we passed in from the dashboard
	if height_offset != 0.0:
		label_y_offset = height_offset
	
	normalize_size()
	input_event.connect(_on_input_event) 
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resize_handle.gui_input.connect(_on_resize_handle_input)
	
	
	
	
	_setup_menu_signals()

# --- MOVEMENT (HYBRID DRAG + WASD) ---
func _physics_process(_delta):
	var is_moving = false

	if dragging:
		var target = get_global_mouse_position()
		var distance = global_position.distance_to(target)
		if distance > 5.0: 
			velocity = global_position.direction_to(target) * distance * 15.0
			move_and_slide()
		is_moving = true

	elif is_selected:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			velocity = input_dir * move_speed
			move_and_slide()
			is_moving = true

	if not is_moving and velocity != Vector2.ZERO:
		velocity = Vector2.ZERO
		snap_to_grid(global_position)

func snap_to_grid(target_pos: Vector2 = global_position):
	var current_x = target_pos.x - grid_offset.x
	var current_y = target_pos.y - grid_offset.y
	
	var snapped_x = floor(current_x / base_cell_size) * base_cell_size
	var snapped_y = floor(current_y / base_cell_size) * base_cell_size
	
	var center_offset = base_cell_size / 2.0
	global_position = Vector2(snapped_x + center_offset, snapped_y + center_offset) + grid_offset

# --- DATA MANAGEMENT ---
func update_data(key: String, new_value):
	# Update or add the value to the dictionary
	data[key] = new_value
	
	# Automatically update visuals/UI based on what changed
	if key == "name":
		name_label.text = data["name"]
	elif key == "hp" or key == "max_hp":
		hp_bar.max_value = data["max_hp"]
		hp_bar.value = data["hp"]
	elif key == "faction" or key == "is_dead":
		update_visuals()
	elif key == "is_status_active" or key == "status_color":
		update_visuals()
	



# --- INPUT LOGIC ---
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		
		# 1. LEFT CLICK DOWN: Start Dragging
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dragging = true
			drag_start_pos = global_position 

		# 2. RIGHT CLICK DOWN: Open Menu (Only for the token you are touching!)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			token_menu.visible = !token_menu.visible
			if token_menu.visible:
				main_menu.visible = true
				hp_action_menu.visible = false 
				status_menu.visible = false
				aura_menu.visible = false
				light_menu.visible = false
				edit_menu.visible = false
				resize_handle.visible = false
				amount_spinbox.value = 0
				token_menu.sub_button_count = 0 
				update_radial_menu()

func _input(event):
	# 1. GLOBAL LEFT CLICK UP: Stop Dragging
	# (This MUST stay global so the token stops dragging even if your mouse moves off of it)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and dragging:
			dragging = false
			
			var was_quick_click = global_position.distance_to(drag_start_pos) < 10.0
			
			if was_quick_click:
				is_selected = !is_selected
				update_visuals()
				snap_to_grid(global_position) 
			else:
				is_selected = true
				update_visuals()
				snap_to_grid(get_global_mouse_position()) 
	
	# 2. KEYBOARD HOTKEYS
	if is_hovered and event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL: 
			grid_size_in_squares += 1
			normalize_size()
		elif event.keycode == KEY_MINUS: 
			if grid_size_in_squares > 1:
				grid_size_in_squares -= 1
				normalize_size()
		elif event.keycode == KEY_X: 
			# Cycle through factions: Neutral -> Enemy -> Ally -> Neutral
			if data["faction"] == "neutral": update_data("faction", "enemy")
			elif data["faction"] == "enemy": update_data("faction", "ally")
			else: update_data("faction", "neutral")
			update_visuals()

func _on_mouse_entered():
	is_hovered = true

func _on_mouse_exited():
	if not dragging:
		is_hovered = false

# --- RADIAL MENU LOGIC ---
func _setup_menu_signals():
	hp_main_btn.pressed.connect(func(): _open_submenu(hp_action_menu, hp_main_btn, [amount_spinbox, damage_btn, heal_btn, level_up_btn]))
	status_btn.pressed.connect(func(): _open_submenu(status_menu, status_btn, [status_color_picker, clear_status_btn]))
	aura_btn.pressed.connect(func(): _open_submenu(aura_menu, aura_btn, [aura_radius_spin, aura_color_picker, clear_aura_btn]))
	light_btn.pressed.connect(func(): _open_submenu(light_menu, light_btn, [light_radius_spin,clear_light_btn]))
	edit_btn.pressed.connect(_on_edit_btn_pressed)
	
	state_btn.pressed.connect(_on_state_toggle_pressed)
	
	damage_btn.pressed.connect(_on_damage_pressed)
	heal_btn.pressed.connect(_on_heal_pressed)
	level_up_btn.pressed.connect(_on_level_up_pressed)
	
	status_color_picker.color_changed.connect(_on_status_color_changed)
	clear_status_btn.pressed.connect(_on_clear_status_pressed)
	
	aura_radius_spin.value_changed.connect(_on_aura_radius_changed)
	aura_color_picker.color_changed.connect(_on_aura_color_changed)
	clear_aura_btn.pressed.connect(_on_clear_aura_pressed)
	
	light_radius_spin.value_changed.connect(_on_light_radius_changed)
	clear_light_btn.pressed.connect(_on_clear_light_pressed)
	
	name_input.text_changed.connect(_on_name_changed) # Updates in real-time as you type!
	base_color_picker.color_changed.connect(_on_base_color_changed)
	ac_spinbox.value_changed.connect(func(val): update_data("ac", val))
	speed_spinbox.value_changed.connect(func(val): update_data("speed", val))
	init_bonus_spinbox.value_changed.connect(func(val): update_data("init_bonus", val))
	close_edit_btn.pressed.connect(func(): token_menu.hide())

func place_on_circle(control_node: Control, angle_degrees: float, radius: float):
	var angle_rad = deg_to_rad(angle_degrees)
	control_node.position = Vector2(cos(angle_rad) * radius, sin(angle_rad) * radius) - (control_node.size / 2.0)

func update_radial_menu():
	token_menu.position = sprite.position 
	
	var inner_r = ((grid_size_in_squares * base_cell_size) / 2.0) + 10.0 
	var main_r = inner_r + 65.0 
	var sub_r = main_r + 75.0   
	
	token_menu.inner_radius = inner_r
	token_menu.main_radius = main_r
	token_menu.sub_radius = sub_r

	# 1. Update the Global Array so the rest of the script knows what buttons exist!
	current_main_btns = [hp_main_btn, status_btn, aura_btn, light_btn, edit_btn, state_btn]
	hide_btn.visible = false 
	
	if GameState.is_gm_mode:
		current_main_btns.append(hide_btn)
		hide_btn.visible = true

	token_menu.main_button_count = current_main_btns.size()
	var main_step = 360.0 / current_main_btns.size()
	
	for i in range(current_main_btns.size()):
		var angle = -90.0 + (i * main_step) 
		var center_of_slice = inner_r + ((main_r - inner_r) / 2.0)
		place_on_circle(current_main_btns[i], angle, center_of_slice)

	token_menu.queue_redraw() 

func _open_submenu(menu_to_show: Control, main_btn: Control, sub_items: Array):
	main_menu.visible = false
	hp_action_menu.visible = false
	status_menu.visible = false
	aura_menu.visible = false
	light_menu.visible = false
	edit_menu.visible = false # Make sure to hide the new edit menu!
	menu_to_show.visible = true
	
	# NEW: Bulletproof Math. Find exactly where this button is in the circle!
	var main_index = current_main_btns.find(main_btn)
	var main_step = 360.0 / current_main_btns.size()
	var parent_angle = -90.0 + (main_index * main_step)
	
	token_menu.active_submenu_angle = deg_to_rad(parent_angle)
	token_menu.sub_button_count = sub_items.size()
	
	var sub_step = main_step
	var start_angle = parent_angle - ((sub_items.size() * sub_step) / 2.0) + (sub_step / 2.0)
	var center_of_outer_slice = token_menu.main_radius + ((token_menu.sub_radius - token_menu.main_radius) / 2.0)
	
	for i in range(sub_items.size()):
		place_on_circle(sub_items[i], start_angle + (i * sub_step), center_of_outer_slice)
		
		
	resize_handle.visible = (menu_to_show == edit_menu)
	token_menu.queue_redraw()


# --- MECHANICAL ACTIONS ---
func _on_hp_main_pressed():
	main_menu.visible = false
	hp_action_menu.visible = true

func _on_damage_pressed():
	var new_hp = max(0, data["hp"] - amount_spinbox.value)
	update_data("hp", new_hp)
	token_menu.hide()

func _on_heal_pressed():
	var new_hp = min(data["max_hp"], data["hp"] + amount_spinbox.value)
	update_data("hp", new_hp)
	token_menu.hide()

func _on_level_up_pressed():
	update_data("max_hp", data["max_hp"] + amount_spinbox.value)
	update_data("hp", data["hp"] + amount_spinbox.value)
	token_menu.hide()

func _on_state_toggle_pressed():
	update_data("is_dead", !data["is_dead"])
	token_menu.hide()

func _on_name_changed(new_text: String):
	update_data("name", new_text)

func _on_status_btn_pressed():
	# Read the hex string from the brain and set the color picker
	status_color_picker.color = Color(data["status_color"])
	
	# Open the menu
	_open_submenu(status_menu, status_btn, [status_color_picker, clear_status_btn])

func _on_status_color_changed(color: Color):
	update_data("is_status_active", true)
	update_data("status_color", color.to_html(true)) # Converts Color to Hex String
	update_visuals() 
	# Note: We don't hide the menu here, so the GM can slide the color wheel and see it change in real-time!

func _on_clear_status_pressed():
	update_data("is_status_active", false)
	token_menu.hide()
	update_visuals()

func _draw():
	if current_aura_radius > 0:
		draw_circle(Vector2.ZERO, current_aura_radius, current_aura_color)

func _on_aura_radius_changed(value: float):
	current_aura_radius = (value / 5.0) * base_cell_size
	queue_redraw() 

func _on_aura_color_changed(color: Color):
	current_aura_color = color
	queue_redraw()

func _on_clear_aura_pressed():
	current_aura_radius = 0.0
	aura_radius_spin.value = 0 
	queue_redraw()
	token_menu.hide()

func _on_light_radius_changed(value: float):
	if value <= 0:
		vision_light.energy = 0.0
		return
		
	vision_light.energy = 1.0 
	var desired_radius_pixels = (value / 5.0) * base_cell_size
	var base_texture_radius = vision_light.texture.get_size().x / 2.0
	vision_light.texture_scale = desired_radius_pixels / base_texture_radius

func _on_light_color_changed(color: Color):
	vision_light.color = color

func _on_clear_light_pressed():
	vision_light.energy = 0.0
	light_radius_spin.value = 0 
	token_menu.hide()

func _on_base_color_changed(color: Color):
	name_color = color
	name_label.modulate = name_color

func _on_edit_btn_pressed():
	# Read current stats
	name_input.text = data["name"]
	ac_spinbox.value = data["ac"]
	speed_spinbox.value = data["speed"]
	init_bonus_spinbox.value = data["init_bonus"]
	
	# Tell the color picker to show the current name color!
	base_color_picker.color = name_color
	
	# Open menu with the new buttons added to the array
	_open_submenu(edit_menu, edit_btn, [name_input, ac_spinbox, speed_spinbox, init_bonus_spinbox, base_color_picker, close_edit_btn])

# --- RESIZE LOGIC ---
func _on_resize_handle_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Start or stop resizing based on the click
		is_resizing = event.pressed
		get_viewport().set_input_as_handled() # Stop the token from moving!
		
	elif event is InputEventMouseMotion and is_resizing:
		# Add mouse movement directly to the stretch multiplier!
		# We divide by base_cell_size so dragging 1 grid square = 1.0 scale increase
		manual_stretch.x += event.relative.x / base_cell_size
		manual_stretch.y += event.relative.y / base_cell_size
		
		# Prevent the GM from turning the token inside out!
		manual_stretch.x = max(0.2, manual_stretch.x)
		manual_stretch.y = max(0.2, manual_stretch.y)
		
		normalize_size() # Recalculate everything instantly


# --- UI HELPERS ---
func _style_radial_spinbox(spinbox: SpinBox):
	# Grab the hidden text box
	var line_edit = spinbox.get_line_edit()
	
	# 1. Force the text to be bright white
	line_edit.add_theme_color_override("font_color", Color.WHITE)
	
	# 2. Create an empty background box
	var empty_style = StyleBoxEmpty.new()
	
	# 3. Apply the empty background to all states so the dark box NEVER appears
	line_edit.add_theme_stylebox_override("normal", empty_style)
	line_edit.add_theme_stylebox_override("focus", empty_style)
	line_edit.add_theme_stylebox_override("read_only", empty_style)
	
	# 4. Center the text nicely between the arrows
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER

# --- VISUAL UPDATERS ---
func update_visuals():
	if data["is_dead"]:
		sprite.rotation_degrees = 90
		sprite.modulate = Color(0.3, 0.3, 0.3) 
		return

	sprite.rotation_degrees = 0
	
	if is_selected:
		sprite.modulate = Color(1.5, 1.5, 0.5) # Yellow Piloting
	elif data["faction"] == "enemy":
		sprite.modulate = Color(1.0, 0.5, 0.5) # Red Hostile
	elif data["faction"] == "ally":
		sprite.modulate = Color(0.5, 1.0, 0.5) # Green Ally
	elif data["is_status_active"]:
		# Convert the hex string back to a real Godot Color
		var c = Color(data["status_color"])
		# Apply the color, but keep the sprite's original transparency (alpha)
		sprite.modulate = Color(c.r, c.g, c.b, sprite.modulate.a)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, sprite.modulate.a) # Normal Neutral

func normalize_size():
	if sprite.texture == null:
		return
		
	var image_size = sprite.texture.get_size()
	var target_pixels = grid_size_in_squares * base_cell_size
	var scale_factor = 1.0
	
	if is_standee:
		scale_factor = target_pixels / image_size.x
		sprite.scale = Vector2(scale_factor, scale_factor) * manual_stretch
		var actual_height = image_size.y * sprite.scale.y
		sprite.position.y = -(actual_height - target_pixels) / 2.0
	else:
		var max_dimension = max(image_size.x, image_size.y)
		scale_factor = target_pixels / max_dimension
		sprite.scale = Vector2(scale_factor, scale_factor) * manual_stretch
		sprite.position.y = 0 
	
	# Keep the handle perfectly pinned to the bottom right of the artwork!
	var extents = (image_size * sprite.scale) / 2.0
	resize_handle.position = sprite.position + extents - (resize_handle.size / 2.0)
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(target_pixels, target_pixels)
	elif collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = target_pixels / 2.0
		
	update_ui_positions()

func update_ui_positions():
	var target_pixels = grid_size_in_squares * base_cell_size
	var half_size = target_pixels / 2.0
	
	name_label.size.x = 200 
	name_label.position.x = -name_label.size.x / 2.0 
	if is_standee:
		var actual_height = sprite.texture.get_size().y * sprite.scale.y
		name_label.position.y = -(actual_height / 2.0) + sprite.position.y - name_label.size.y - 5 + label_y_offset
	else:
		name_label.position.y = -half_size - name_label.size.y - 5 + label_y_offset
	
	hp_bar.size.x = target_pixels 
	hp_bar.position.x = -hp_bar.size.x / 2.0 
	hp_bar.position.y = half_size + 5
	
	update_radial_menu()



func set_selected(is_selected: bool):
	highlight_ring.visible = is_selected
