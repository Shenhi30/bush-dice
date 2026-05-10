extends CanvasLayer

signal map_loaded(file_path: String)
signal spawn_token_requested(image_path: String, y_offset: float, is_enemy_flag: bool)
signal map_scale_changed(new_scale: float)
signal tool_mode_changed(mode_index: int)
signal save_requested(file_path: String)
signal load_requested(file_path: String)
signal scene_switched(new_scene_id: String)
signal create_new_scene_requested()
signal rename_scene_requested(new_name: String)

# --- DRAWER NODES ---
@onready var map_drawer = $MapDrawer
@onready var token_drawer = $TokenDrawer
@onready var map_grid = $MapDrawer/VBoxContainer/ScrollContainer/MapGrid
@onready var token_grid = $TokenDrawer/VBoxContainer/ScrollContainer/TokenGrid

@onready var map_file_dialog = $MapFileDialog
@onready var map_scale_spin_box = $HBoxContainer/MapScaleSpinBox
@onready var offset_spinbox = $HBoxContainer/OffsetSpinBox
@onready var token_file_dialog = $TokenFileDialog
@onready var enemy_checkbox = $HBoxContainer/EnemyCheckBox

#  -- Dropdown --
@onready var scene_dropdown = $HBoxContainer/SceneDropdown
@onready var add_scene_btn = $HBoxContainer/AddSceneBtn

# -- RENAME --
@onready var rename_btn = $HBoxContainer/RenameSceneBtn
@onready var rename_dialog = $RenameDialog
@onready var rename_input = $RenameDialog/NewNameInput


@onready var save_file_dialog = $SaveFileDialog
@onready var load_file_dialog = $LoadFileDialog

# --- FOLDER PATHS ---
const MAPS_FOLDER = "res://Assets/Maps/"
const TOKENS_FOLDER = "res://Assets/Tokens/"

var is_holding_minus: bool = false
var is_holding_plus: bool = false

func _ready():
	# 1. Wire up the top bar toggles
	$HBoxContainer/ToggleMapsBtn.pressed.connect(func(): 
		map_drawer.visible = !map_drawer.visible
		token_drawer.visible = false 
	)
	
	$HBoxContainer/ToggleTokensBtn.pressed.connect(func(): 
		token_drawer.visible = !token_drawer.visible
		map_drawer.visible = false 
	)
	
	# 2. Wire up the Import Buttons to open the pop-up windows
	var map_import = $MapDrawer/VBoxContainer/TopControls/ImportMapBtn
	var map_close = $MapDrawer/VBoxContainer/TopControls/CloseMapBtn
	var token_import = $TokenDrawer/VBoxContainer/TopControls/ImportTokenBtn
	var token_close = $TokenDrawer/VBoxContainer/TopControls/CloseTokenBtn
	
	map_import.pressed.connect(func(): map_file_dialog.popup_centered_ratio(0.7))
	token_import.pressed.connect(func(): token_file_dialog.popup_centered_ratio(0.7))
	
	# The new Close Buttons!
	map_close.pressed.connect(func(): map_drawer.hide())
	token_close.pressed.connect(func(): token_drawer.hide())
	# 3. When a file is chosen, turn it into a button in the drawer!
	map_file_dialog.file_selected.connect(func(path): _create_image_button(path, map_grid, true))
	token_file_dialog.file_selected.connect(func(path): _create_image_button(path, token_grid, false))
	
	# 4. Auto-generate the default folders on startup
	_generate_thumbnails(MAPS_FOLDER, map_grid, true)
	_generate_thumbnails(TOKENS_FOLDER, token_grid, false)
	
	$HBoxContainer/SaveCampaignBtn.pressed.connect(func(): save_file_dialog.popup_centered_ratio(0.7))
	$HBoxContainer/LoadCampaignBtn.pressed.connect(func(): load_file_dialog.popup_centered_ratio(0.7))
	
	save_file_dialog.file_selected.connect(func(path): save_requested.emit(path))
	load_file_dialog.file_selected.connect(func(path): load_requested.emit(path))
	
	
	# --- SCENE SWITCHER LOGIC ---
	# 1. Fill the dropdown with scenes from the CampaignManager
	scene_dropdown.clear()
	var current_scene = CampaignManager.campaign_data["active_scene_id"]
	var index = 0
	
	for scene_id in CampaignManager.campaign_data["scenes"].keys():
		scene_dropdown.add_item(scene_id)
		# If this is the scene we are currently on, select it in the UI!
		if scene_id == current_scene:
			scene_dropdown.select(index)
		index += 1
		
	# 2. Wire the buttons
	scene_dropdown.item_selected.connect(_on_scene_dropdown_selected)
	add_scene_btn.pressed.connect(func(): create_new_scene_requested.emit())
	
	
	# --- RENAME LOGIC ---
	rename_btn.pressed.connect(func():
		# Pre-fill the input box with the current scene's name
		rename_input.text = scene_dropdown.get_item_text(scene_dropdown.selected)
		rename_dialog.popup_centered()
	)
	
	rename_dialog.confirmed.connect(func():
		var new_name = rename_input.text.strip_edges()
		if new_name != "":
			rename_scene_requested.emit(new_name)
	)




func _process(delta: float):
	# The 'delta' ensures the zoom speed is the same regardless of framerate
	var zoom_speed = 1.0 # Change this to make the zoom faster or slower!
	
	if is_holding_minus:
		map_scale_spin_box.value -= zoom_speed * delta
		
	if is_holding_plus:
		map_scale_spin_box.value += zoom_speed * delta

func _generate_thumbnails(folder_path: String, grid: GridContainer, is_map: bool):
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
					var full_path = folder_path + file_name
					_create_image_button(full_path, grid, is_map)
			file_name = dir.get_next()

func _create_image_button(image_path: String, grid: GridContainer, is_map: bool):
	var btn = Button.new()
	
	var img = Image.load_from_file(image_path)
	if img != null:
		btn.icon = ImageTexture.create_from_image(img)
	else:
		btn.icon = load(image_path) 
		
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(100, 100) 
	btn.tooltip_text = image_path.get_file()
	
	btn.pressed.connect(func():
		if is_map:
			map_loaded.emit(image_path)
			map_drawer.hide() 
		else:
			var current_offset = offset_spinbox.value
			var is_hostile = enemy_checkbox.button_pressed
			spawn_token_requested.emit(image_path, current_offset, is_hostile)
	)
	
	grid.add_child(btn)

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

func _on_scene_dropdown_selected(index: int):
	var selected_scene_id = scene_dropdown.get_item_text(index)
	scene_switched.emit(selected_scene_id)
