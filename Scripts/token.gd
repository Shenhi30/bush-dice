extends CharacterBody2D

# --- STATS ---
@export var character_name: String = "Unknown"
@export var is_enemy: bool = false
@export var max_hp: int = 20
@export var current_hp: int = 20
@export var initiative: int = 0

# --- DISPLAY & SIZE SETTINGS ---
@export var grid_size_in_squares: int = 1 
@export var is_standee: bool = false
@export var label_y_offset: float = 0.0
var base_cell_size: float = 64.0 
@export var grid_offset: Vector2 = Vector2.ZERO

# --- MOVEMENT & STATE ---
@export var move_speed: float = 300.0
var dragging: bool = false
var is_hovered: bool = false
var is_selected: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO

# --- UI REFERENCES ---
@onready var name_label = $UI/NameLabel
@onready var hp_bar = $UI/HPBar
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

# --- MENU REFERENCES ---
@onready var token_menu = $UI/TokenMenu
@onready var amount_spinbox = $UI/TokenMenu/VBoxContainer/AmountSpinBox
@onready var damage_btn = $UI/TokenMenu/VBoxContainer/DamageBtn
@onready var heal_btn = $UI/TokenMenu/VBoxContainer/HealBtn
@onready var level_up_btn = $UI/TokenMenu/VBoxContainer/LevelUpBtn

func _ready():
	# 1. Setup UI Values
	name_label.text = character_name
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	
	# 2. Setup Initial Visuals
	update_enemy_status()
	normalize_size()
	
	# 3. Connect Signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	damage_btn.pressed.connect(_on_damage_pressed)
	heal_btn.pressed.connect(_on_heal_pressed)
	level_up_btn.pressed.connect(_on_level_up_pressed)


# --- MOVEMENT (HYBRID DRAG + WASD) ---
func _physics_process(_delta):
	var is_moving = false

	# 1. MOUSE DRAGGING (Highest Priority)
	if dragging:
		var target = get_global_mouse_position()
		var distance = global_position.distance_to(target)
		
		# Prevent jittering when reaching the mouse
		if distance > 5.0: 
			velocity = global_position.direction_to(target) * distance * 15.0
			move_and_slide()
		is_moving = true

	# 2. WASD KEYBOARD (Only if selected)
	elif is_selected:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			velocity = input_dir * move_speed
			move_and_slide()
			is_moving = true

	# 3. STOPPING & GRID SNAPPING
	if not is_moving and velocity != Vector2.ZERO:
		velocity = Vector2.ZERO
		snap_to_grid()


# By default, it uses its own position, but we can feed it the mouse position!
func snap_to_grid(target_pos: Vector2 = global_position):
	# 1. Apply the GM's custom grid offset
	var current_x = target_pos.x - grid_offset.x
	var current_y = target_pos.y - grid_offset.y
	
	# 2. Find the exact box based on the TARGET position (e.g., your mouse)
	var snapped_x = floor(current_x / base_cell_size) * base_cell_size
	var snapped_y = floor(current_y / base_cell_size) * base_cell_size
	
	# 3. Add the 32px center offset, plus the GM's custom offset
	var center_offset = base_cell_size / 2.0
	global_position = Vector2(snapped_x + center_offset, snapped_y + center_offset) + grid_offset


# --- INPUT EVENT (CLICKING THE TOKEN) ---
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		# Left Click Down: Start Drag
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dragging = true
			drag_start_pos = global_position 
			
		# Right Click Down: Open Menu
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			token_menu.visible = !token_menu.visible
			if token_menu.visible:
				amount_spinbox.value = 0 


# --- GLOBAL INPUT (HOTKEYS & RELEASING CLICKS) ---
func _input(event):
	# 1. Releasing the Left Mouse Button anywhere on screen
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and dragging:
			dragging = false
			
			# SMART CLICK DETECTION: Measure the distance BEFORE we snap it!
			var was_quick_click = global_position.distance_to(drag_start_pos) < 10.0
			
			if was_quick_click:
				# You just clicked it! Toggle selection on/off.
				is_selected = !is_selected
				update_enemy_status()
				# Snap it based on where it already is
				snap_to_grid(global_position) 
			else:
				# You dragged it across the board! Keep it selected for WASD.
				is_selected = true
				update_enemy_status()
				# Snap it to the mouse cursor's new location
				snap_to_grid(get_global_mouse_position()) 

	# 2. Hover Hotkeys
	if is_hovered and event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL: 
			grid_size_in_squares += 1
			normalize_size()
		elif event.keycode == KEY_MINUS: 
			if grid_size_in_squares > 1:
				grid_size_in_squares -= 1
				normalize_size()
		elif event.keycode == KEY_X: 
			is_enemy = !is_enemy
			update_enemy_status()


# --- HOVER LOGIC ---
func _on_mouse_entered():
	is_hovered = true


func _on_mouse_exited():
	if not dragging:
		is_hovered = false


# --- VISUALS & SIZING ---
func update_enemy_status():
	# 1. GM is piloting: Yellow tint overrides everything
	if is_selected:
		sprite.modulate = Color(1.5, 1.5, 0.5, 0.753) 
		return 
	
	# 2. Hostile: Red tint
	if is_enemy:
		sprite.modulate = Color(1.0, 0.502, 0.502, 0.788)
		
	# 3. Friendly/Default: Normal colors
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0)


func normalize_size():
	if sprite.texture == null:
		return
		
	var image_size = sprite.texture.get_size()
	var target_pixels = grid_size_in_squares * base_cell_size
	var scale_factor = 1.0
	
	if is_standee:
		# Scale by width, let it be tall, and slide it up
		scale_factor = target_pixels / image_size.x
		sprite.scale = Vector2(scale_factor, scale_factor)
		var actual_height = image_size.y * scale_factor
		sprite.position.y = -(actual_height - target_pixels) / 2.0
	else:
		# Shrink to fit inside the square completely
		var max_dimension = max(image_size.x, image_size.y)
		scale_factor = target_pixels / max_dimension
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.position.y = 0 
	
	# Scale the clickable area to match the grid size
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(target_pixels, target_pixels)
	elif collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = target_pixels / 2.0
		
	update_ui_positions()


func update_ui_positions():
	var target_pixels = grid_size_in_squares * base_cell_size
	var half_size = target_pixels / 2.0
	
	# 1. Name Label
	name_label.size.x = 200 
	name_label.position.x = -name_label.size.x / 2.0 
	if is_standee:
		var actual_height = sprite.texture.get_size().y * sprite.scale.y
		name_label.position.y = -(actual_height / 2.0) + sprite.position.y - name_label.size.y - 5 + label_y_offset
	else:
		name_label.position.y = -half_size - name_label.size.y - 5 + label_y_offset
	
	# 2. HP Bar
	hp_bar.size.x = target_pixels 
	hp_bar.position.x = -hp_bar.size.x / 2.0 
	hp_bar.position.y = half_size + 5
	
	# 3. Context Menu
	token_menu.position.x = half_size + 10
	token_menu.position.y = -token_menu.size.y / 2.0


# --- HP MENU LOGIC ---
func _on_damage_pressed():
	var amount = amount_spinbox.value
	current_hp -= amount
	if current_hp < 0: current_hp = 0
	hp_bar.value = current_hp
	token_menu.hide()


func _on_heal_pressed():
	var amount = amount_spinbox.value
	current_hp += amount
	if current_hp > max_hp: current_hp = max_hp
	hp_bar.value = current_hp
	token_menu.hide()


func _on_level_up_pressed():
	var amount = amount_spinbox.value
	max_hp += amount
	hp_bar.max_value = max_hp
	current_hp += amount
	hp_bar.value = current_hp
	token_menu.hide()
