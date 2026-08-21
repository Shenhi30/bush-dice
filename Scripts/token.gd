extends CharacterBody2D

# --- STATS & STATE ---


# The Token's "System-Agnostic Brain"
var data: Dictionary = {
	# --- IDENTITY ---
	"name": "Unknown",
	"owner_id": "1", # Default to GM
	"faction": "neutral", # "neutral", "enemy", or "ally"
	
	# --- VTT STATES ---
	"is_hidden": false,
	"is_dead": false,
	"is_status_active": false,
	"status_color": "c45500b2", 
	"light_radius": 0.0,
	"current_init": 0, # Used universally by the Initiative Tracker
	
	# --- UNIVERSAL RESOURCES ---
	"hp": 20,
	"max_hp": 20
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

@onready var highlight_ring = $HighLightRing
# --- MENU REFERENCES ---
@onready var token_menu = $UI/MenuLayer/TokenMenu
@onready var main_menu = $UI/MenuLayer/TokenMenu/MainMenu
@onready var hp_main_btn = $UI/MenuLayer/TokenMenu/MainMenu/HPMainBtn
@onready var status_btn = $UI/MenuLayer/TokenMenu/MainMenu/StatusBtn
@onready var aura_btn = $UI/MenuLayer/TokenMenu/MainMenu/AuraBtn
@onready var light_btn = $UI/MenuLayer/TokenMenu/MainMenu/LightBtn
@onready var state_btn = $UI/MenuLayer/TokenMenu/MainMenu/StateBtn
@onready var edit_btn = $UI/MenuLayer/TokenMenu/MainMenu/EditBtn
@onready var hide_btn = $UI/MenuLayer/TokenMenu/MainMenu/HideBtn
@onready var delete_btn = $UI/MenuLayer/TokenMenu/MainMenu/DeleteBtn
@onready var inv_btn = $UI/MenuLayer/TokenMenu/MainMenu/InvBtn
@onready var sheet_btn = $UI/MenuLayer/TokenMenu/MainMenu/SheetBtn

@onready var hp_action_menu = $UI/MenuLayer/TokenMenu/HPActionMenu
@onready var amount_spinbox = $UI/MenuLayer/TokenMenu/HPActionMenu/AmountSpinBox
@onready var damage_btn = $UI/MenuLayer/TokenMenu/HPActionMenu/DamageBtn
@onready var heal_btn = $UI/MenuLayer/TokenMenu/HPActionMenu/HealBtn
@onready var level_up_btn = $UI/MenuLayer/TokenMenu/HPActionMenu/LevelUpBtn

@onready var status_menu = $UI/MenuLayer/TokenMenu/StatusMenu
@onready var status_color_picker = $UI/MenuLayer/TokenMenu/StatusMenu/StatusColorPicker
@onready var clear_status_btn = $UI/MenuLayer/TokenMenu/StatusMenu/ClearStatusBtn

@onready var aura_menu = $UI/MenuLayer/TokenMenu/AuraMenu
@onready var aura_radius_spin = $UI/MenuLayer/TokenMenu/AuraMenu/AuraRadiusSpinBox
@onready var aura_color_picker = $UI/MenuLayer/TokenMenu/AuraMenu/AuraColorPicker
@onready var clear_aura_btn = $UI/MenuLayer/TokenMenu/AuraMenu/ClearAuraBtn

@onready var light_menu = $UI/MenuLayer/TokenMenu/LightMenu
@onready var light_radius_spin = $UI/MenuLayer/TokenMenu/LightMenu/LightRadiusSpinBox
@onready var clear_light_btn = $UI/MenuLayer/TokenMenu/LightMenu/ClearLightBtn

@onready var edit_menu = $UI/MenuLayer/TokenMenu/EditMenu
@onready var name_input = $UI/MenuLayer/TokenMenu/EditMenu/NameInput
@onready var base_color_picker = $UI/MenuLayer/TokenMenu/EditMenu/BaseColorPicker
@onready var owner_input = $UI/MenuLayer/TokenMenu/EditMenu/OwnerInput
@onready var assign_owner_btn = $UI/MenuLayer/TokenMenu/EditMenu/AssignOwnerBtn
@onready var close_edit_btn = $UI/MenuLayer/TokenMenu/EditMenu/CloseEditBtn

@onready var resize_handle = $UI/MenuLayer/ResizeHandle

func _ready():
	# Forces this token to create its own unique copy of the data dictionary!
	data = data.duplicate(true)
	
	name_label.text = data["name"]
	hp_bar.max_value = data["max_hp"]
	hp_bar.value = data["hp"]
	name_label.modulate = name_color
	
	
	# 1. Make the LineEdit transparent with white centered text
	var empty_style = StyleBoxEmpty.new()
	owner_input.add_theme_stylebox_override("normal", empty_style)
	owner_input.add_theme_stylebox_override("focus", empty_style)
	owner_input.add_theme_color_override("font_color", Color.WHITE)
	owner_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 2. Force both nodes to be small enough to fit inside the ring slice
	owner_input.custom_minimum_size = Vector2(70, 30)
	owner_input.size = Vector2(70, 30)
	assign_owner_btn.custom_minimum_size = Vector2(60, 30)
	assign_owner_btn.size = Vector2(60, 30)
	
	update_visuals()
	
	load_token_image()
			
	# Apply the custom height offset we passed in from the dashboard
	if height_offset != 0.0:
		label_y_offset = height_offset
	
	normalize_size()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resize_handle.gui_input.connect(_on_resize_handle_input)
	
	
	_setup_menu_signals()
	
	if data.has("light_radius"):
		update_data("light_radius", data["light_radius"], true)

func _process(_delta):
	var my_name = GameState.player_name # <--- THE FIX: Use our String Name!
	var is_gm = GameState.is_gm_mode
	
	# 1. THE HIDE BUTTON LOGIC
	if data.get("is_hidden", false) and not is_gm:
		visible = false # Poof! Vanishes for players.
	else:
		visible = true
		
	# 2. THE STATS & VISION LOGIC
	var token_owner_id = str(data.get("owner_id", "GM"))
	
	# THE MAGIC HYBRID CHECK:
	# If you are the GM, OR your exact name matches the owner string!
	if is_gm or my_name == token_owner_id or token_owner_id == "GM" or token_owner_id == "1":
		name_label.visible = true 
		hp_bar.visible = true
		vision_light.visible = true # <--- Turns on ONLY for the owner
	else:
		name_label.visible = false
		hp_bar.visible = false
		vision_light.visible = false # <--- Completely disabled for everyone else!
		
	# 3. GLUE THE MENU TO THE TOKEN
	if token_menu.visible:
		token_menu.global_position = sprite.global_position
		
	if resize_handle.visible and sprite.texture:
		var extents = (sprite.texture.get_size() * sprite.scale) / 2.0
		resize_handle.global_position = sprite.global_position + extents - (resize_handle.size / 2.0)


# --- DATA MANAGEMENT ---
func update_data(key: String, new_value, is_from_network: bool = false):
	# --- CATCH THE CONTROLLER ASSIGNMENT ---
	# Update or add the value to the dictionary
	data[key] = new_value
	
	# Automatically update visuals/UI based on what changed
	if key == "name":
		# IMPORTANT: Change "NameLabel" to whatever the actual name 
		# of your Label node is inside your Token scene!
		var name_label = get_node_or_null("UI/NameLabel") 
		if name_label:
			name_label.text = str(new_value)
	elif key == "hp" or key == "max_hp":
		var hp_bar = get_node_or_null("UI/HPBar")
		var hp_text = get_node_or_null("UI/HPBar/HPText") 
		
		if hp_bar:
			# 1. Update the green bar itself
			if key == "hp": 
				hp_bar.value = int(new_value)
			elif key == "max_hp": 
				hp_bar.max_value = int(new_value)
				
			# 2. Update the text label (e.g., "15 / 20")
			if hp_text:
				# Grab the current numbers from the data dictionary (or fallback to the bar's default)
				var current_hp = data.get("hp", hp_bar.value)
				var maximum_hp = data.get("max_hp", hp_bar.max_value)
				hp_text.text = str(current_hp) + " / " + str(maximum_hp)

	elif key == "faction" or key == "is_dead" or key == "is_hidden":
		update_visuals()

	elif key == "is_status_active" or key == "status_color":
		update_visuals()

	elif key == "light_radius":
		if new_value <= 0:
			vision_light.energy = 0.0
		else:
			vision_light.energy = 1.0 
			var desired_radius_pixels = (new_value / 5.0) * base_cell_size
			var base_texture_radius = vision_light.texture.get_size().x / 2.0
			vision_light.texture_scale = desired_radius_pixels / base_texture_radius
			
	# Only broadcast if a human clicked the menu. If the network sent this, stay quiet!
	if not is_from_network:
		var main_board = get_node_or_null("../../")
		if main_board and main_board.has_method("broadcast_token_data_update"):
			main_board.broadcast_token_data_update(name, key, new_value)


# --- INPUT LOGIC ---
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		
		# --- THE UNIFIED SECURITY BOUNCER ---
		var my_name = GameState.player_name
		var owner_name = str(data.get("owner_id", "GM"))
		
		if not GameState.is_gm_mode and owner_name != "GM" and owner_name != "1":
			if my_name != owner_name:
				print("Access Denied: This token belongs to ", owner_name)
				return # STOP THE CODE! Do not allow menus to open!
		
		# 1. RIGHT CLICK DOWN: Open Menu (MainBoard now perfectly handles Left Clicks)
		if event.button_index == MOUSE_BUTTON_RIGHT:
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
	# 1. KEYBOARD HOTKEYS (Movement dragging is now safely handled by MainBoard!)
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
	hide_btn.pressed.connect(_on_hide_btn_pressed)
	delete_btn.pressed.connect(_on_delete_btn_pressed)
	inv_btn.pressed.connect(_on_inv_btn_pressed)
	sheet_btn.pressed.connect(_on_sheet_btn_pressed)
	
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
	
	assign_owner_btn.pressed.connect(_on_assign_owner_pressed)
	
	name_input.text_changed.connect(_on_name_changed) # Updates in real-time as you type!
	base_color_picker.color_changed.connect(_on_base_color_changed)
	close_edit_btn.pressed.connect(func(): token_menu.hide())

func place_on_circle(control_node: Control, angle_degrees: float, radius: float):
	var angle_rad = deg_to_rad(angle_degrees)
	control_node.position = Vector2(cos(angle_rad) * radius, sin(angle_rad) * radius) - (control_node.size / 2.0)

func update_radial_menu():
	token_menu.global_position = sprite.global_position
	
	var inner_r = ((grid_size_in_squares * base_cell_size) / 2.0) + 10.0 
	var main_r = inner_r + 65.0 
	var sub_r = main_r + 75.0   
	var outer_r = sub_r + 75.0
	
	token_menu.inner_radius = inner_r
	token_menu.main_radius = main_r
	token_menu.sub_radius = sub_r
	token_menu.outer_radius = outer_r

	# 1. Update the Global Array so the rest of the script knows what buttons exist!
	current_main_btns = [hp_main_btn, status_btn, aura_btn, light_btn, edit_btn, state_btn, delete_btn, inv_btn, sheet_btn]
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

func _open_submenu(menu_to_show: Control, main_btn: Control, sub_items: Array, outer_items: Array = []):
	main_menu.visible = false
	hp_action_menu.visible = false
	status_menu.visible = false
	aura_menu.visible = false
	light_menu.visible = false
	edit_menu.visible = false # Make sure to hide the new edit menu!
	menu_to_show.visible = true
	
	# Bulletproof Math. Find exactly where this button is in the circle!
	var main_index = current_main_btns.find(main_btn)
	var main_step = 360.0 / current_main_btns.size()
	var parent_angle = -90.0 + (main_index * main_step)
	
	token_menu.active_submenu_angle = deg_to_rad(parent_angle)
	token_menu.sub_button_count = sub_items.size()
	token_menu.outer_button_count = outer_items.size()
	
	var sub_step = main_step
	
	# --- RING 2 (SUB ITEMS) ---
	var start_angle = parent_angle - ((sub_items.size() * sub_step) / 2.0) + (sub_step / 2.0)
	var center_of_sub_slice = token_menu.main_radius + ((token_menu.sub_radius - token_menu.main_radius) / 2.0)
	
	for i in range(sub_items.size()):
		place_on_circle(sub_items[i], start_angle + (i * sub_step), center_of_sub_slice)
		
	# --- RING 3 (OUTER ITEMS) ---
	if outer_items.size() > 0:
		var outer_start_angle = parent_angle - ((outer_items.size() * sub_step) / 2.0) + (sub_step / 2.0)
		var center_of_outer_slice = token_menu.sub_radius + ((token_menu.outer_radius - token_menu.sub_radius) / 2.0)
		
		for i in range(outer_items.size()):
			place_on_circle(outer_items[i], outer_start_angle + (i * sub_step), center_of_outer_slice)
		
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
	# Tell the brain to remember the new size!
	update_data("light_radius", value)

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
		
	# Tell the color picker to show the current name color!
	owner_input.text = str(data.get("owner_id", 1))
	base_color_picker.color = name_color
	
	# Ring 2 (Inner): Identity & Control
	var ring_2_items = [name_input, owner_input, assign_owner_btn, close_edit_btn]
	# Ring 3 (Outer): Combat Stats & Color
	var ring_3_items = [base_color_picker]
	
	# Open menu with the new buttons added to the array
	_open_submenu(edit_menu, edit_btn, ring_2_items, ring_3_items)


func _on_assign_owner_pressed():
	var typed_name = owner_input.text.strip_edges()
	
	if typed_name == "" or typed_name.to_upper() == "GM":
		update_data("owner_id", "GM") 
		print("Assigned ownership back to GM")
	else:
		# Just save the exact name they typed!
		update_data("owner_id", typed_name)
		print("Token assigned to ", typed_name)
			
	token_menu.hide()

func _on_hide_btn_pressed():
	# Flip the boolean! If it was false, make it true.
	var new_hidden_state = !data.get("is_hidden", false)
	
	# This automatically triggers the network sync!
	update_data("is_hidden", new_hidden_state) 
	
	token_menu.hide()

func _on_delete_btn_pressed():
	token_menu.hide()
	var main_board = get_node_or_null("../../")
	if main_board and main_board.has_method("delete_token_networked"):
		main_board.delete_token_networked(name)

func _on_inv_btn_pressed():
	token_menu.hide()
	
	# Ask the MainBoard to open the window for THIS token's owner!
	var target_uuid = str(data.get("owner_id", "GM"))
	var token_name = data.get("name", "Unknown")
	
	var main_board = get_node_or_null("../../")
	if main_board and main_board.has_method("open_inventory_window"):
		main_board.open_inventory_window(target_uuid, token_name)

func _on_sheet_btn_pressed():
	token_menu.hide() # Close the radial menu so it's not in the way
	
	var main_board = get_node_or_null("../../")
	if main_board and main_board.has_method("open_character_sheet_for_token"):
		main_board.open_character_sheet_for_token(name)

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
		sprite.modulate = Color(0.5, 1.0, 0.5, 1.0) # Green Ally
	elif data["is_status_active"]:
		# Convert the hex string back to a real Godot Color
		var c = Color(data["status_color"])
		# Apply the color, but keep the sprite's original transparency (alpha)
		sprite.modulate = Color(c.r, c.g, c.b, sprite.modulate.a)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, sprite.modulate.a) # Normal Neutral
	# --- GM GHOST VISION ---
	if data.get("is_hidden", false) and GameState.is_gm_mode:
		sprite.modulate.a = 0.4 # Make it ghostly!
	else:
		sprite.modulate.a = 1.0 # Solid

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

# --- IMAGE LOADING FUNCTION ---
func load_token_image():
	if art_path == "": return
	
	# 1. Try the original path (This works perfectly for the GM)
	var image = Image.load_from_file(art_path)
	
	# 2. If it fails, check the Player's secret 'tokens' download folder!
	if not image:
		var file_name = art_path.get_file() 
		var local_path = "user://tokens/" + file_name
		image = Image.load_from_file(local_path)
		
	# 3. Apply the texture if we found it
	if image:
		var new_texture = ImageTexture.create_from_image(image)
		sprite.texture = new_texture
		normalize_size() # Ensure it scales correctly once loaded
	else:
		print("Waiting for token image to finish downloading...")
