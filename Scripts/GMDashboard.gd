extends CanvasLayer

signal map_loaded(file_path: String)
# NEW SIGNAL: Tells the board what image to use, and what offset to apply
signal spawn_token_requested(image_path: String, y_offset: float, is_enemy_flag: bool)


# Map Nodes
@onready var load_map_button = $HBoxContainer/LoadMapButton
@onready var map_dropdown = $HBoxContainer/MapDropdown
@onready var map_file_dialog = $MapFileDialog

# Token Nodes
@onready var load_token_btn = $HBoxContainer/LoadTokenArtButton
@onready var token_dropdown = $HBoxContainer/TokenDropdown
@onready var offset_spinbox = $HBoxContainer/OffsetSpinBox
@onready var spawn_token_btn = $HBoxContainer/SpawnTokenButton
@onready var token_file_dialog = $TokenFileDialog
@onready var enemy_checkbox = $HBoxContainer/EnemyCheckBox

var map_library = {}
var token_library = {} # NEW: Stores token art paths

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

# --- MAP LOGIC ---
func _on_load_map_pressed(): map_file_dialog.popup()
func _on_map_file_selected(path: String):
	var file_name = path.get_file()
	map_library[file_name] = path
	map_dropdown.add_item(file_name)
	map_dropdown.select(map_dropdown.get_item_count() - 1)
	_on_map_dropdown_selected(map_dropdown.get_selected_id())
func _on_map_dropdown_selected(index: int):
	if index == 0: return
	map_loaded.emit(map_library[map_dropdown.get_item_text(index)])

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
