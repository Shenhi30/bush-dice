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
signal fog_bypass_toggled(is_bypassed: bool)
signal spawn_party_requested

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

@onready var spawn_party_btn = $ToolPallete/TabContainer/Party/SpawnPartyBtn
@onready var party_container = $ToolPallete/TabContainer/Party

@onready var party_list = $ToolPallete/TabContainer/Party/PartyList
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
	spawn_party_btn.pressed.connect(func(): spawn_party_requested.emit())
	
	refresh_party_ui()
	refresh_token_library()
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

func refresh_token_library():
	# 1. Clear the old icons
	for child in token_grid.get_children():
		child.queue_free()
	
	# 2. Open the user folder
	var path = "user://tokens/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		if file_name == "":
			print("The scanner found NOTHING in " + path)
		while file_name != "":
			print("Scanner found file: " + file_name) # This tells you it's working!
			# 3. Only pick image files
			if file_name.to_lower().ends_with(".png") or file_name.to_lower().ends_with(".jpg"):
				spawn_library_icon(path + file_name)
			
			file_name = dir.get_next()
	else:
		print("Error: Could not find user://tokens folder!")

func spawn_library_icon(file_path: String):
	
	# 4. Use your new UI template
	var icon_scene = preload("res://UI/TokenLibraryItem.tscn")
	var new_item = icon_scene.instantiate()
	
	# 1. Load the raw data from the hard drive
	var img = Image.load_from_file(file_path)
	
	# 2. Convert it into a texture the UI can use
	var tex = ImageTexture.create_from_image(img)
	
	# 1. Set the image on the Icon node
	var icon_node = new_item.get_node("Icon")
	icon_node.texture = tex
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_node.custom_minimum_size = Vector2(80, 80)
	
	# 2. Set the Name Label! 
	# get_basename() removes the ".png" so "Guard.png" becomes "Guard"
	var file_name = file_path.get_file().get_basename() 
	var label_node = new_item.get_node("NameLabel")
	label_node.text = file_name
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	new_item.token_image_path = file_path
	token_grid.add_child(new_item)

func refresh_map_library():
	for child in map_grid.get_children():
		child.queue_free()
		
	var path = "user://maps/"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg")):
				spawn_map_icon(path + file_name)
			file_name = dir.get_next()

# 4. Create the drawer icon
func spawn_map_icon(file_path: String):
	var icon_scene = preload("res://UI/MapLibraryItem.tscn")
	var new_icon = icon_scene.instantiate()
	
	var img = Image.load_from_file(file_path)
	new_icon.texture = ImageTexture.create_from_image(img)
	
	# Maps usually look better as wide rectangles
	new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	new_icon.custom_minimum_size = Vector2(150, 100) 
	
	new_icon.map_image_path = file_path
	map_grid.add_child(new_icon)

func refresh_party_ui():
	# 1. Clear the old list
	if not party_list: return
	for child in party_list.get_children():
		child.queue_free()
		
	var vault = CampaignManager.campaign_data.get("pc_vault", {})
	
	# 2. Build a row for every player character
	for pc_name in vault.keys():
		var pc_data = vault[pc_name]
		var row = HBoxContainer.new()
		
		# A. The Portrait
		var portrait = TextureRect.new()
		var img = Image.load_from_file(pc_data["art_path"])
		if img:
			portrait.texture = ImageTexture.create_from_image(img)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.custom_minimum_size = Vector2(40, 40) # Small UI size
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(portrait)
		
		# B. The Name Label
		var name_lbl = Label.new()
		name_lbl.text = pc_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Pushes the spawn button to the right
		row.add_child(name_lbl)
		
		# C. The Individual Spawn Button
		var spawn_btn = Button.new()
		spawn_btn.text = "Spawn"
		spawn_btn.pressed.connect(func():
			var main_board = get_tree().get_first_node_in_group("board")
			if main_board:
				main_board.spawn_single_vault_token(pc_name, main_board.get_node("GMCamera").global_position)
		)
		row.add_child(spawn_btn)
		
		# 3. Add the complete row to the drawer
		party_list.add_child(row)



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
	fog_bypass_toggled.emit(toggled_on)

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

func _on_open_folders_btn_pressed() -> void:
	# 1. Translate the safe 'user://' path into a real Windows/Mac/Linux path
	var absolute_path = ProjectSettings.globalize_path("user://")
	
	# 2. Command the operating system to open it in their native File Explorer!
	OS.shell_open(absolute_path)

func _on_import_token_btn_pressed() -> void:
	$TokenFileDialog.popup_centered()

func _on_token_file_dialog_file_selected(path: String) -> void:
	# 1. Get the filename (e.g., "bounty_hunter.png")
	var file_name = path.get_file()
	var destination = "user://tokens/" + file_name
	
	# 2. Copy the file into your internal library
	# We use copy_absolute because the original file is outside the project
	var err = DirAccess.copy_absolute(path, destination)
	
	if err == OK:
		print("Import Successful: ", file_name)
		# 3. Trigger your scanner to update the UI
		refresh_token_library()
	else:
		print("Import Failed! Error code: ", err)

func _on_map_file_dialog_file_selected(path: String) -> void:
		# 1. Get the filename (e.g., "bounty_hunter.png")
	var file_name = path.get_file()
	var destination = "user://maps/" + file_name
	
	# 2. Copy the file into your internal library
	# We use copy_absolute because the original file is outside the project
	var err = DirAccess.copy_absolute(path, destination)
	
	if err == OK:
		print("Import Successful: ", file_name)
		# 3. Trigger your scanner to update the UI
		refresh_map_library()
	else:
		print("Import Failed! Error code: ", err)

func _on_import_map_btn_pressed() -> void:
	$MapFileDialog.popup_centered()
