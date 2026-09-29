extends CanvasLayer

signal map_loaded(file_path: String)
signal spawn_token_requested(image_path: String, y_offset: float, is_enemy_flag: bool)
signal map_scale_changed(new_scale: float)
signal tool_mode_changed(mode_index: int)
signal measure_shape_changed(shape_index: int)
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

@onready var token_search_bar: LineEdit = $TokenDrawer/VBoxContainer/TopControls/TokenSearchBar

@onready var host_ip_btn = $HBoxContainer/HostIPBtn

#  -- Dropdown --
@onready var scene_select_btn = $HBoxContainer/SceneSelectBtn
@onready var scene_popup = $HBoxContainer/SceneSelectBtn/ScenePopup
@onready var search_bar = $HBoxContainer/SceneSelectBtn/ScenePopup/VBoxContainer/SearchBar
@onready var scene_tree = $HBoxContainer/SceneSelectBtn/ScenePopup/VBoxContainer/SceneTree

# We store the raw data here so the search bar can instantly rebuild the list
var full_scene_list = {}

@onready var add_scene_btn = $HBoxContainer/AddSceneBtn

@onready var spawn_party_btn = $ToolPallete/TabContainer/Party/SpawnPartyBtn
@onready var party_container = $ToolPallete/TabContainer/Party

@onready var system_dropdown = $ToolPallete/TabContainer/Tools/SystemDropdown

@onready var party_list = $ToolPallete/TabContainer/Party/PartyList
@onready var monster_list = $ToolPallete/TabContainer/Monsters/MonsterList
@onready var npc_list = $ToolPallete/TabContainer/NPCs/NPCList


@onready var shape_dropdown = $ToolPallete/TabContainer/Tools/MeasureShapeDropdown
# -- RENAME --
@onready var rename_btn = $HBoxContainer/RenameSceneBtn
@onready var rename_dialog = $RenameDialog
@onready var rename_input = $RenameDialog/NewNameInput

# --- TOOL BUTTONS ---
# Double-check these paths exactly match the names of your buttons in the scene tree!
@onready var floating_text_toggle = $ToolPallete/TabContainer/Tools/FloatingTextToggle
@onready var btn_select = $ToolPallete/TabContainer/Tools/SelectToolBtn
@onready var btn_draw = $ToolPallete/TabContainer/Tools/WallToolBtn
@onready var btn_erase = $ToolPallete/TabContainer/Tools/EraseWallBtn
@onready var btn_measure = $ToolPallete/TabContainer/Tools/MeasureToolBtn

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
	
	if token_search_bar:
		token_search_bar.text_changed.connect(func(_new_text: String):
			refresh_token_library()
		)
	
	map_import.pressed.connect(func(): map_file_dialog.popup_centered_ratio(0.7))
	token_import.pressed.connect(func(): token_file_dialog.popup_centered_ratio(0.7))
	
	# The new Close Buttons!
	map_close.pressed.connect(func(): map_drawer.hide())
	token_close.pressed.connect(func(): token_drawer.hide())
	
	
	$HBoxContainer/SaveCampaignBtn.pressed.connect(func(): save_file_dialog.popup_centered_ratio(0.7))
	$HBoxContainer/LoadCampaignBtn.pressed.connect(func(): load_file_dialog.popup_centered_ratio(0.7))
	
# 1. Wire the File Dialogs to update the Campaign Manager AND tell the Board to render!
	save_file_dialog.file_selected.connect(func(path): 
		CampaignManager.save_campaign(path)
		save_requested.emit(path) # Restored for the Main Board!
	)
	
	load_file_dialog.file_selected.connect(func(path): 
		CampaignManager.load_campaign(path)
		load_requested.emit(path) # Restored for the Main Board!
	)
	
	# 2. Tell the UI to rebuild the Side Menus whenever a save file finishes loading!
	CampaignManager.campaign_loaded.connect(refresh_toolpallete_lists)
	
	# 3. Also rebuild the Map/Scene dropdown list!
	CampaignManager.campaign_loaded.connect(refresh_scene_dropdown)
	
	# 3. Also rebuild the Map/Scene dropdown list!
	CampaignManager.campaign_loaded.connect(refresh_scene_dropdown)
	
	spawn_party_btn.pressed.connect(func(): spawn_party_requested.emit())
	
	refresh_toolpallete_lists()
	refresh_token_library()
	refresh_map_library()
	
	# --- SCENE SWITCHER LOGIC ---
	# 1. Fill the dropdown with scenes from the CampaignManager
	refresh_scene_dropdown()
	# 2. Wire the buttons
	
	# 1. Pop open the menu perfectly below the button
	scene_select_btn.pressed.connect(func():
		# Get the button's exact coordinates on the screen
		var btn_rect = scene_select_btn.get_global_rect()
		
		# Move the popup to sit exactly at the bottom-left corner of the button
		scene_popup.position = Vector2i(btn_rect.position.x, btn_rect.position.y + btn_rect.size.y)
		scene_popup.size = Vector2i(250, 400)
		
		# Open it!
		scene_popup.popup()
		search_bar.grab_focus() # Automatically puts your text cursor in the search box!
	)
	
	
	# 2. Wire the search bar and the tree clicks
	search_bar.text_changed.connect(_build_tree)
	scene_tree.item_activated.connect(_on_scene_tree_item_activated)
	
	add_scene_btn.pressed.connect(func(): create_new_scene_requested.emit())
	
	if floating_text_toggle:
		# Match the checkbox visual to the actual game state on load
		floating_text_toggle.button_pressed = GameState.show_floating_text
		
		# Flip the master switch whenever the GM clicks the box!
		floating_text_toggle.toggled.connect(func(is_on): GameState.show_floating_text = is_on)
	
	
	# --- RENAME LOGIC ---
	rename_btn.pressed.connect(func():
		# Pre-fill the input box with the current scene's name using the NEW button!
		var current_name = scene_select_btn.text
		if current_name == "Select Map...":
			current_name = "" # Keep it blank if no map is loaded yet
			
		rename_input.text = current_name
		rename_dialog.popup_centered()
	)
	
	rename_dialog.confirmed.connect(func():
		var new_name = rename_input.text.strip_edges()
		if new_name != "":
			rename_scene_requested.emit(new_name)
	)
	

	# --- SYSTEM DROPDOWN SETUP ---
	system_dropdown.clear()
	for system_id in SheetTemplates.TEMPLATES.keys():
		# Capitalize makes "dnd_5e" look like "Dnd_5e" in the UI
		system_dropdown.add_item(system_id.capitalize())
		
	system_dropdown.item_selected.connect(_on_system_changed)
	
	# Set the dropdown to show the currently active system
	var active_system = CampaignManager.campaign_data.get("system_id", "dnd_5e")
	var tab_index = SheetTemplates.TEMPLATES.keys().find(active_system)
	if tab_index != -1:
		system_dropdown.select(tab_index)
		
	shape_dropdown.item_selected.connect(func(index): measure_shape_changed.emit(index))
	# --- UPNP IP DISPLAY ---
	if multiplayer.is_server():
		host_ip_btn.visible = true
		host_ip_btn.disabled = true # Lock it until UPnP finishes
		
		# Listen for the signal from NetworkManager
		NetworkManager.upnp_completed.connect(_on_upnp_completed)
		host_ip_btn.pressed.connect(_on_host_ip_btn_pressed)
	else:
		# Hide it if a regular player somehow sees this dashboard
		host_ip_btn.visible = false

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
	for child in token_grid.get_children():
		child.queue_free()
		
	var base_path = "user://tokens/"
	var dir = DirAccess.open(base_path)
	if not dir: return
	
	# 1. Automatically generate standard folders to keep the GM organized
	var default_groups = ["Monsters", "NPCs", "Players", "Props", "Uncategorized"]
	for group in default_groups:
		if not dir.dir_exists(group):
			dir.make_dir(group)
			
	# Get current search filter
	var filter_text = ""
	if token_search_bar:
		filter_text = token_search_bar.text.to_lower()
			
	var directories = dir.get_directories()
	directories.sort() 
	
	# 2. Build groups for EVERY subfolder it finds
	for d in directories:
		_build_token_group(base_path + d + "/", d, filter_text)
		
	# Add a bumper at the bottom of the list for the scrollbar
	var bottom_padding = Control.new()
	bottom_padding.custom_minimum_size = Vector2(0, 45)
	token_grid.add_child(bottom_padding)


func _build_token_group(folder_path: String, group_name: String, filter_text: String):
	var dir = DirAccess.open(folder_path)
	if not dir: return
	
	var valid_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var ext = file_name.to_lower()
		if not dir.current_is_dir() and (ext.ends_with(".png") or ext.ends_with(".jpg") or ext.ends_with(".webp")):
			if filter_text == "" or filter_text in file_name.to_lower():
				valid_files.append(file_name)
		file_name = dir.get_next()
	
	if valid_files.is_empty():
		return
		
	if token_grid.get_child_count() > 0:
		var gap = Control.new()
		gap.custom_minimum_size = Vector2(0, 15)
		token_grid.add_child(gap)
	
	var header = Label.new()
	header.text = "-- " + group_name.to_upper() + " --"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	token_grid.add_child(header)
	
	# THE FIX: Create a dedicated grid just for this specific folder
	var category_grid = GridContainer.new()
	category_grid.columns = 4 # Set how many tokens wide you want the drawer to be
	category_grid.add_theme_constant_override("h_separation", 10)
	category_grid.add_theme_constant_override("v_separation", 15)
	token_grid.add_child(category_grid)
	
	for f in valid_files:
		spawn_library_icon(folder_path + "/" + f, category_grid) # Pass the new grid!

func spawn_library_icon(file_path: String, target_grid: GridContainer):
	var icon_scene = preload("res://UI/TokenLibraryItem.tscn")
	var new_item = icon_scene.instantiate()
	
	var img = Image.load_from_file(file_path)
	if img:
		var tex = ImageTexture.create_from_image(img)
		var icon_node = new_item.get_node("Icon")
		icon_node.texture = tex
		icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Lock the token image size so tall images don't break the grid!
		icon_node.custom_minimum_size = Vector2(80, 80) 
		icon_node.size = Vector2(80, 80)
	
	var file_name = file_path.get_file().get_basename() 
	var label_node = new_item.get_node("NameLabel")
	label_node.text = file_name
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Clip long names so they don't overlap neighboring tokens
	label_node.clip_text = true
	label_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	
	new_item.token_image_path = file_path
	new_item.token_image_path = file_path
	
	target_grid.add_child(new_item)

func refresh_map_library():
	for child in map_grid.get_children():
		child.queue_free()
		
	var base_path = "user://maps/"
	var dir = DirAccess.open(base_path)
	if not dir: return
	
	# 1. Automatically generate standard folders if they are missing
	var default_groups = ["Cities", "Dungeons", "Encounters", "World", "Uncategorized"]
	for group in default_groups:
		if not dir.dir_exists(group):
			dir.make_dir(group)
			
	# 2. Build groups for EVERY subfolder it finds
	var directories = dir.get_directories()
	directories.sort() 
	
	for d in directories:
		_build_map_group(base_path + d + "/", d, map_grid)
		
	# THE FIX 2: Add a 45px empty bumper at the bottom of the list so the scrollbar clears the text
	var bottom_padding = Control.new()
	bottom_padding.custom_minimum_size = Vector2(0, 45)
	map_grid.add_child(bottom_padding)

# --- NEW HELPER FUNCTION ---
func _build_map_group(folder_path: String, group_name: String, parent_node: Node):
	var dir = DirAccess.open(folder_path)
	if not dir: return
	
	# Scan for images in this specific folder (case-insensitive)
	var valid_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var ext = file_name.to_lower()
		if not dir.current_is_dir() and (ext.ends_with(".png") or ext.ends_with(".jpg") or ext.ends_with(".jpeg") or ext.ends_with(".webp")):
			valid_files.append(file_name)
		file_name = dir.get_next()
	
	# Skip completely if the folder is empty (stops floating headers)
	if valid_files.is_empty():
		return
		
	# THE FIX 1: Add a 25px gap before the category header so it doesn't touch the maps above it
	if parent_node.get_child_count() > 0:
		var gap = Control.new()
		gap.custom_minimum_size = Vector2(0, 25)
		parent_node.add_child(gap)
	
	# Create a visual Header for the category
	var header = Label.new()
	header.text = "=== " + group_name.to_upper() + " ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent_node.add_child(header)
	
	# Create a Grid specifically for this category's maps
	var grid = GridContainer.new()
	grid.columns = 2
	
	# Space between the rows and columns
	grid.add_theme_constant_override("v_separation", 25)
	grid.add_theme_constant_override("h_separation", 10)
	
	parent_node.add_child(grid)
	
	# Spawn the map icons directly into this grid
	for f in valid_files:
		var full_path = folder_path + f if folder_path.ends_with("/") else folder_path + "/" + f
		spawn_map_icon(full_path, grid)

# --- UPDATED SPAWN FUNCTION (Now takes a target_grid parameter) ---
func spawn_map_icon(file_path: String, target_grid: GridContainer):
	var icon_scene = preload("res://UI/MapLibraryItem.tscn")
	var new_icon = icon_scene.instantiate()
	
	var img = Image.load_from_file(file_path)
	if img:
		new_icon.texture = ImageTexture.create_from_image(img)
	
	new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	new_icon.custom_minimum_size = Vector2(150, 100) 
	
	new_icon.map_image_path = file_path
	
	# --- THE NEW LABEL LOGIC ---
	var name_label = Label.new()
	name_label.text = file_path.get_file().get_basename() 
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# THE FIX: Stop long names from breaking the grid layout!
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	
	# Pin the label perfectly to the bottom edge
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	
	# Background for readability
	var dark_bg = StyleBoxFlat.new()
	dark_bg.bg_color = Color(0, 0, 0, 0.7) 
	name_label.add_theme_stylebox_override("normal", dark_bg)
	
	new_icon.add_child(name_label)
	# ---------------------------
	
	target_grid.add_child(new_icon)

func _on_system_changed(index: int):
	var system_ids = SheetTemplates.TEMPLATES.keys()
	var selected_id = system_ids[index]
	
	# This triggers the CampaignManager to update the template and emit the signal
	CampaignManager.set_campaign_system(selected_id)

func refresh_scene_dropdown():
	full_scene_list.clear()
	var scenes = CampaignManager.campaign_data["scenes"].keys()
	
	# Group the scenes identically to how we did it before
	for scene_id in scenes:
		var group_name = "Uncategorized"
		var display_name = scene_id
		
		if ":" in scene_id:
			var parts = scene_id.split(":", true, 1)
			group_name = parts[0].strip_edges()
			display_name = parts[1].strip_edges()
			
		if not full_scene_list.has(group_name):
			full_scene_list[group_name] = []
			
		full_scene_list[group_name].append({"id": scene_id, "display": display_name})
		
	# Build the visual tree for the first time with no search filter
	_build_tree("")


func _build_tree(filter_text: String):
	scene_tree.clear()
	var root = scene_tree.create_item()
	
	var sorted_groups = full_scene_list.keys()
	sorted_groups.sort()
	var filter_lower = filter_text.to_lower()
	
	for group in sorted_groups:
		# 1. Filter out maps that don't match the search
		var valid_children = []
		for scene_data in full_scene_list[group]:
			if filter_text == "" or filter_lower in scene_data["display"].to_lower():
				valid_children.append(scene_data)
				
		# 2. If a folder is empty because of the search, hide it entirely
		if valid_children.is_empty():
			continue 
			
		# 3. Create the Category Folder (City, Battlemap, etc.)
		var category_item = scene_tree.create_item(root)
		category_item.set_text(0, group)
		category_item.set_selectable(0, false) # Prevents the GM from "loading" a folder
		
		# Auto-expand folders if the GM is searching, otherwise keep them tidy
		category_item.collapsed = (filter_text == "") 
		
		# 4. Populate the actual maps inside the folder
		for scene_data in valid_children:
			var item = scene_tree.create_item(category_item)
			item.set_text(0, scene_data["display"])
			item.set_metadata(0, scene_data["id"]) # Hide the real ID here


func _on_scene_tree_item_activated():
	# item_activated triggers when the GM double-clicks or hits Enter on a map
	var selected = scene_tree.get_selected()
	if selected:
		var scene_id = selected.get_metadata(0)
		if scene_id != null: # Make sure they didn't somehow click a folder
			scene_switched.emit(scene_id)
			scene_popup.hide()
			# Update the button text to show the currently loaded map
			scene_select_btn.text = selected.get_text(0)
			refresh_toolpallete_lists()


# ==========================================
# TOOL COLOR MANAGER
# ==========================================
func update_tool_colors(active_mode: int):
	var normal_color = Color(1.0, 1.0, 1.0, 1.0)
	var active_color = Color(1.0, 0.84, 0.0, 1.0) # Bright Gold Highlight
	
	# 1. Reset all buttons to standard white
	if btn_select: btn_select.modulate = normal_color
	if btn_draw: btn_draw.modulate = normal_color
	if btn_erase: btn_erase.modulate = normal_color
	if btn_measure: btn_measure.modulate = normal_color
	
	# 2. Apply the gold highlight to the active tool
	match active_mode:
		0: # SELECT
			if btn_select: 
				btn_select.modulate = active_color
				btn_select.set_pressed_no_signal(true) # Visually presses the toggle down!
		1: # DRAW WALL
			if btn_draw: 
				btn_draw.modulate = active_color
				btn_draw.set_pressed_no_signal(true)
		2: # ERASE WALL
			if btn_erase: 
				btn_erase.modulate = active_color
				btn_erase.set_pressed_no_signal(true)
		3: # MEASURE
			if btn_measure: 
				btn_measure.modulate = active_color
				btn_measure.set_pressed_no_signal(true)

# --- KEYBOARD SHORTCUT RECEIVER ---
func select_tool_by_index(mode_index: int):
	# Setting button_pressed = true automatically triggers the _on_toggled signals!
	match mode_index:
		0: 
			if btn_select: btn_select.button_pressed = true
		1: 
			if btn_draw: btn_draw.button_pressed = true
		2: 
			if btn_erase: btn_erase.button_pressed = true
		3: 
			if btn_measure: btn_measure.button_pressed = true

func refresh_toolpallete_lists():
	# 1. Очищаємо стандартні списки
	if party_list: for child in party_list.get_children(): child.queue_free()
	if monster_list: for child in monster_list.get_children(): child.queue_free()
	if npc_list: for child in npc_list.get_children(): child.queue_free()
		
	var tab_container = $ToolPallete/TabContainer
	var permanent_tabs = ["Tools", "Party", "Monsters", "NPCs"]
	
	# 2. Видаляємо всі попередньо згенеровані кастомні вкладки (щоб не було дублікатів)
	for child in tab_container.get_children():
		if not child.name in permanent_tabs:
			tab_container.remove_child(child)
			child.queue_free()
			
	var vault = CampaignManager.campaign_data.get("pc_vault", {})
	
	# 3. Розподіляємо персонажів
	for pc_name in vault.keys():
		var pc_data = vault[pc_name]
		var category = pc_data.get("menu_category", "Party")
		if category == "": category = "Party" # Захист від порожніх рядків
		
		var target_list = null
		
		# Якщо це стандартна вкладка — використовуємо існуючий список
		if category == "Party" and party_list:
			target_list = party_list
		elif category == "Monsters" and monster_list:
			target_list = monster_list
		elif category == "NPCs" and npc_list:
			target_list = npc_list
		else:
			# --- ЦЕ КАСТОМНА КАТЕГОРІЯ! ---
			# Перевіряємо, чи ми вже створили для неї вкладку під час цього циклу
			var custom_tab = tab_container.get_node_or_null(category)
			
			if not custom_tab:
				# Генеруємо нову вкладку (ScrollContainer)
				custom_tab = ScrollContainer.new()
				custom_tab.name = category 
				custom_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
				
				# Додаємо VBoxContainer для списку всередину
				var vbox = VBoxContainer.new()
				vbox.name = "List"
				vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				custom_tab.add_child(vbox)
				
				# Додаємо вкладку в інтерфейс!
				tab_container.add_child(custom_tab)
				
			target_list = custom_tab.get_node("List")
			
		# 4. Будуємо рядок токена (UI Row) у знайденому списку
		if target_list:
			var row = HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_PASS
			row.gui_input.connect(_on_party_item_right_clicked.bind(pc_name))
			
			var portrait = TextureRect.new()
			var img = Image.load_from_file(pc_data.get("art_path", ""))
			if img: portrait.texture = ImageTexture.create_from_image(img)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.custom_minimum_size = Vector2(40, 40)
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(portrait)
			
			var name_lbl = Label.new()
			name_lbl.text = pc_name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)
			
			var spawn_btn = Button.new()
			spawn_btn.text = "Spawn"
			spawn_btn.pressed.connect(func():
				var main_board = get_tree().get_first_node_in_group("board")
				if main_board:
					main_board.spawn_single_vault_token(pc_name, main_board.get_node("GMCamera").global_position)
			)
			row.add_child(spawn_btn)
			
			target_list.add_child(row)

# ==========================================
# UPNP AND IP COPY LOGIC
# ==========================================
func _on_upnp_completed(server_ip: String):
	if server_ip != "":
		host_ip_btn.text = "IP: %s (Click to Copy)" % server_ip
		host_ip_btn.disabled = false
	else:
		host_ip_btn.text = "UPnP Failed (Forward Manually)"
		host_ip_btn.disabled = true

func _on_host_ip_btn_pressed():
	if NetworkManager.public_ip != "":
		# Tell Godot to copy the text to your OS clipboard
		DisplayServer.clipboard_set(NetworkManager.public_ip)
		
		# Give visual feedback so the GM knows it worked
		var original_text = host_ip_btn.text
		host_ip_btn.text = "Copied to Clipboard!"
		
		# Reset the text back to normal after 1.5 seconds
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(host_ip_btn):
				host_ip_btn.text = original_text
		)

# --- PARTY MENU DELETION ---
func _on_party_item_right_clicked(event: InputEvent, pc_name: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup = PopupMenu.new()
		popup.add_item("Remove " + pc_name, 0)
		
		add_child(popup)
		popup.position = DisplayServer.mouse_get_position()
		popup.popup()
		
		popup.id_pressed.connect(func(id: int):
			if id == 0:
				# 1. Delete the character data strictly from the pc_vault
				if CampaignManager.campaign_data.has("pc_vault"):
					CampaignManager.campaign_data["pc_vault"].erase(pc_name)
				
				# 2. Force the Party UI to instantly rebuild itself
				refresh_toolpallete_lists()
				
			popup.queue_free()
		)


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
		update_tool_colors(0) # <--- Force the color update!

# 1 = DRAW_WALL mode
func _on_wall_tool_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tool_mode_changed.emit(1)
		update_tool_colors(1)

# 2 = ERASE mode
func _on_erase_wall_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tool_mode_changed.emit(2) 
		update_tool_colors(2)

# 3 = MEASURE mode
func _on_measure_tool_btn_toggled(toggled_on: bool) -> void:
	shape_dropdown.visible = toggled_on
	if toggled_on:
		tool_mode_changed.emit(3)
		update_tool_colors(3)

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
	var destination = "user://maps/Uncategorized/" + file_name
	
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
