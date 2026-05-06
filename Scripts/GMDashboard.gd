extends CanvasLayer

signal map_loaded(file_path: String)
# NEW SIGNAL: Tells the board what image to use, and what offset to apply
signal spawn_token_requested(image_path: String, y_offset: float, is_enemy_flag: bool)
signal map_scale_changed(new_scale: float)

signal tool_mode_changed(mode_index: int)

# Map Nodes
@onready var load_map_button = $HBoxContainer/LoadMapButton
@onready var map_dropdown = $HBoxContainer/MapDropdown
@onready var map_file_dialog = $MapFileDialog
@onready var map_scale_spin_box = $HBoxContainer/MapScaleSpinBox


# Token Nodes
@onready var load_token_btn = $HBoxContainer/LoadTokenArtButton
@onready var token_dropdown = $HBoxContainer/TokenDropdown
@onready var offset_spinbox = $HBoxContainer/OffsetSpinBox
@onready var spawn_token_btn = $HBoxContainer/SpawnTokenButton
@onready var token_file_dialog = $TokenFileDialog
@onready var enemy_checkbox = $HBoxContainer/EnemyCheckBox

var map_library = {}
var token_library = {} # NEW: Stores token art paths


var is_holding_minus: bool = false
var is_holding_plus: bool = false

func _ready():
	# Map Connections
	load_map_button.pressed.connect(_on_load_map_pressed)
	map_file_dialog.file_selected.connect(_on_map_file_selected)
	map_dropdown.item_selected.connect(_on_map_dropdown_selected)
	map_dropdown.add_item("Select a Map...")
	map_dropdown.set_item_disabled(0, true)
	
	# Token Connections
	load_token_btn.pressed.connect(_on_load_token_pressed)
	token_file_dialog.file_selected.connect(_on_token_file_selected)
	spawn_token_btn.pressed.connect(_on_spawn_token_pressed)
	token_dropdown.add_item("Select Token Art...")
	token_dropdown.set_item_disabled(0, true)

func _process(delta: float):
	# The 'delta' ensures the zoom speed is the same regardless of framerate
	var zoom_speed = 1.0 # Change this to make the zoom faster or slower!
	
	if is_holding_minus:
		map_scale_spin_box.value -= zoom_speed * delta
		
	if is_holding_plus:
		map_scale_spin_box.value += zoom_speed * delta

# --- MAP LOGIC ---
func _on_load_map_pressed(): map_file_dialog.popup()

func _on_map_file_selected(path: String):
	# 1. Get just the file name (e.g., "dungeon_floor1.png") to show in the UI
	var file_name = path.get_file()
	
	# 2. Store it in your library dictionary
	map_library[file_name] = path
	
	# 3. Add it as an option to your dropdown and select it
	map_dropdown.add_item(file_name)
	var new_index = map_dropdown.get_item_count() - 1
	map_dropdown.select(new_index)
	
	# 4. Tell the board to change the map right now!
	map_loaded.emit(path)

func _on_map_dropdown_selected(index: int):
	if index == 0: return # Skip placeholder if you have one
	
	var map_name = map_dropdown.get_item_text(index)
	if map_library.has(map_name):
		var path = map_library[map_name]
		map_loaded.emit(path)

# Connect the "pressed" signal from your Minus button to this
func _on_scale_minus_btn_pressed() -> void:
	# Nudge the scale down by 0.05 (adjust this step to your liking!)
	map_scale_spin_box.value -= 0.05


# Connect the "pressed" signal from your Plus button to this
func _on_scale_plus_btn_pressed() -> void:
	# Nudge the scale up by 0.05
	map_scale_spin_box.value += 0.05

func _on_map_scale_spin_box_value_changed(value: float) -> void:
	map_scale_changed.emit(value)

# --- TOKEN LOGIC ---
func _on_load_token_pressed():
	token_file_dialog.popup()

func _on_token_file_selected(path: String):
	# 1. Add the new character art to the dropdown
	var file_name = path.get_file()
	token_library[file_name] = path
	token_dropdown.add_item(file_name)
	token_dropdown.select(token_dropdown.get_item_count() - 1)

func _on_spawn_token_pressed():
	var selected_index = token_dropdown.get_selected_id()
	if selected_index == 0:
		push_warning("Please select token art from the dropdown first!")
		return

	var file_name = token_dropdown.get_item_text(selected_index)
	var image_path = token_library[file_name]
	var custom_offset = offset_spinbox.value
	
	#Check if box is ticked
	var is_hostile = enemy_checkbox.button_pressed
	
	# SHOUT out to the GameBoard to actually build the token!
	spawn_token_requested.emit(image_path, custom_offset, is_hostile)

func _on_bypass_fog_toggled(toggled_on: bool) -> void:
	GameState.is_gm_mode = toggled_on
	GameState.gm_mode_changed.emit(toggled_on)


func _on_scale_minus_btn_button_down():
	is_holding_minus = true

func _on_scale_minus_btn_button_up():
	is_holding_minus = false

func _on_scale_plus_btn_button_down():
	is_holding_plus = true

func _on_scale_plus_btn_button_up():
	is_holding_plus = false

# We pass 0 for SELECT mode
func _on_select_tool_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tool_mode_changed.emit(0)

# 1 = DRAW_WALL mode
func _on_wall_tool_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tool_mode_changed.emit(1)

# 2 = ERASE mode
func _on_erase_wall_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tool_mode_changed.emit(2) 

# 3 = MEASURE mode
func _on_measure_tool_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tool_mode_changed.emit(3)
