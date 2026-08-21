extends PanelContainer # Or Window, depending on your root

@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer
@onready var title_label = $MarginContainer/VBoxContainer/HBoxContainer/TitleLabel
@onready var add_stat_btn = $MarginContainer/VBoxContainer/HBoxContainer/AddStatBtn
@onready var save_btn = $MarginContainer/VBoxContainer/HBoxContainer/SaveBtn
@onready var add_popup = $AddBlueprintPopup
@onready var close_btn = $MarginContainer/VBoxContainer/HBoxContainer/CloseBtn

# --- D&D STAT LINKING MAP ---
var dnd_skill_map = {
	"str_save": "str", "dex_save": "dex", "con_save": "con", "int_save": "int", "wis_save": "wis", "cha_save": "cha",
	"acrobatics": "dex", "animal_handling": "wis", "arcana": "int", "athletics": "str", "deception": "cha", 
	"history": "int", "insight": "wis", "intimidation": "cha", "investigation": "int", "medicine": "wis", 
	"nature": "int", "perception": "wis", "performance": "cha", "persuasion": "cha", "religion": "int", 
	"sleight_of_hand": "dex", "stealth": "dex", "survival": "wis"
}

# Preload our React-style components
var stat_row_scene = preload("res://UI/stat_row_component.tscn")
var skill_row_scene = preload("res://UI/skill_row_component.tscn")
var death_saves_scene = preload("res://UI/death_saves_component.tscn")
var text_row_scene = preload("res://UI/text_row_component.tscn")
var long_text_scene = preload("res://UI/long_text_component.tscn")
var image_scene = preload("res://UI/image_component.tscn")

# Dictionary to keep track of our generated tabs
var category_tabs = {}
var ui_nodes = {} 
var local_data = {} 

# Token Tracking Context
var original_data = {} 
var current_token_name: String = ""

# --- SYSTEM TRACKING ---
var current_dice_logic: String = "d20_high" # Default fallback

# Dragging variables
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready():
	title_label.gui_input.connect(_on_title_gui_input)
	CampaignManager.blueprint_updated.connect(_on_blueprint_updated)
	add_stat_btn.pressed.connect(_on_add_stat_btn_pressed)
	
	if save_btn:
		save_btn.pressed.connect(save_sheet_to_token)
	
	if close_btn:
		close_btn.pressed.connect(func(): hide())
	
	if GameState.is_gm_mode:
		add_stat_btn.show()
	
	generate_ui(CampaignManager.campaign_data.get("sheet_template", {}), {})

# --- DRAGGING LOGIC ---

func _on_title_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			dragging = false
			
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

# --- UI GENERATION ---

func generate_ui(template: Dictionary, character_data: Dictionary, token_name: String = ""):
	for child in tab_container.get_children():
		tab_container.remove_child(child)
		child.queue_free()
	category_tabs.clear()
	ui_nodes.clear()
	
	if token_name != "":
		current_token_name = token_name
		local_data = character_data.duplicate() 
		original_data = character_data.duplicate() 

	# Grab the dice logic for the active system
	current_dice_logic = template.get("dice_logic", "d20_high")
	var layout = template.get("layout", [])

	# Iterate through the Layout structure
	for tab_data in layout:
		var tab_name = tab_data.get("tab", "General")
		
		var scroll = ScrollContainer.new()
		scroll.name = tab_name
		scroll.custom_minimum_size = Vector2(350, 450)
		var vbox = VBoxContainer.new()
		scroll.add_child(vbox)
		tab_container.add_child(scroll)
		category_tabs[tab_name] = vbox
		
		var target_container = category_tabs[tab_name]
		
		for item in tab_data.get("elements", []):
			var new_row = null
			
			var item_id = item.get("key", item.get("id", "unknown_id"))
			
			if item.has("current_key"):
				item_id = item["current_key"]
			
			var item_name = item.get("label", item.get("name", "Unknown"))
			
		# 1. Normal single numbers (Armor Class, Speed, etc.)
			if item["type"] in ["number", "stat_box"]:
				new_row = stat_row_scene.instantiate()
				new_row.get_node("StatName").text = item_name
				var spinbox = new_row.get_node("BaseValue")
				
				var id = item.get("key", item.get("id", "unknown_id"))
				
				if local_data.has(id):
					spinbox.value = local_data[id]
				else:
					local_data[id] = spinbox.value
					
				spinbox.value_changed.connect(_on_stat_changed.bind(id))
				target_container.add_child(new_row)
				ui_nodes[id] = new_row

			# 2. THE FIX: Dual-boxes for Resource Bars (HP, Temp HP, etc.)
			elif item["type"] == "resource_bar":
				# We can build this row instantly via code!
				var h_box = HBoxContainer.new()
				
				var label = Label.new()
				label.text = item_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h_box.add_child(label)
				
				# Grab the specific keys from your template
				var curr_key = item.get("current_key", "hp")
				var max_key = item.get("max_key", "max_hp")
				
				# Current HP Box
				var curr_box = SpinBox.new()
				curr_box.max_value = 9999
				curr_box.value = local_data.get(curr_key, 10)
				h_box.add_child(curr_box)
				
				# A slash to make it look nice ( Current / Max )
				var slash = Label.new()
				slash.text = " / "
				h_box.add_child(slash)
				
				# Max HP Box
				var max_box = SpinBox.new()
				max_box.max_value = 9999
				max_box.value = local_data.get(max_key, 10)
				h_box.add_child(max_box)
				
				# Auto-Save triggers for both boxes independently!
				curr_box.value_changed.connect(func(val): 
					local_data[curr_key] = val
					save_sheet_to_token()
				)
				
				max_box.value_changed.connect(func(val): 
					local_data[max_key] = val
					save_sheet_to_token()
				)
				
				target_container.add_child(h_box)
				ui_nodes[curr_key] = h_box # Store it in the dictionary just in case
		
			elif item["type"] == "stat_row":
				for stat_name in item.get("stats", []):
					var stat_id = stat_name.to_lower() 
					
					var stat_row = stat_row_scene.instantiate()
					stat_row.get_node("StatName").text = stat_name
					var spinbox = stat_row.get_node("BaseValue")
					
					if local_data.has(stat_id):
						spinbox.value = local_data[stat_id]
					else:
						local_data[stat_id] = spinbox.value
						
					# Auto-Save when Core Stat changes
					spinbox.value_changed.connect(_on_stat_changed.bind(stat_id))
					
					if stat_row.has_node("RollButton"):
						var roll_btn = stat_row.get_node("RollButton")
						roll_btn.pressed.connect(_on_roll_pressed.bind(stat_id, stat_name + " Check"))
						
					target_container.add_child(stat_row)
					ui_nodes[stat_id] = stat_row
					
				continue
				
				
			elif item["type"] == "text":
				new_row = text_row_scene.instantiate()
				new_row.get_node("StatName").text = item_name
				var text_input = new_row.get_node("TextInput")
				
				if local_data.has(item_id):
					text_input.text = str(local_data[item_id])
					
				# --- UPDATED SYNC LOGIC ---
				text_input.text_changed.connect(func(new_text): local_data[item_id] = new_text)
				text_input.text_submitted.connect(func(_new_text): save_sheet_to_token())
				text_input.focus_exited.connect(func(): save_sheet_to_token())
				
			elif item["type"] == "long_text":
				new_row = long_text_scene.instantiate()
				new_row.get_node("StatName").text = item_name
				var text_edit = new_row.get_node("TextEdit")
				
				if local_data.has(item_id):
					text_edit.text = str(local_data[item_id])
					
				text_edit.text_changed.connect(func(): local_data[item_id] = text_edit.text)
				text_edit.focus_exited.connect(func(): save_sheet_to_token())

			elif item["type"] == "image":
				new_row = image_scene.instantiate()
				new_row.get_node("StatName").text = item_name
				var tex_rect = new_row.get_node("CenterContainer/TextureRect")
				
				var path = local_data.get("art_path", "") 
				if path != "":
					var img = Image.load_from_file(path)
					if not img:
						img = Image.load_from_file("user://tokens/" + path.get_file())
					if img:
						tex_rect.texture = ImageTexture.create_from_image(img)
			
			elif item["type"] == "skill":
				new_row = skill_row_scene.instantiate()
				new_row.get_node("SkillName").text = item_name
				var checkbox = new_row.get_node("ProficiencyCheck")
				var exp_checkbox = new_row.get_node("ExpertiseCheck")
				if local_data.has(item_id + "_prof"): checkbox.button_pressed = local_data[item_id + "_prof"]
				if local_data.has(item_id + "_exp"): exp_checkbox.button_pressed = local_data[item_id + "_exp"]
				checkbox.toggled.connect(_on_proficiency_toggled.bind(item_id))
				exp_checkbox.toggled.connect(_on_expertise_toggled.bind(item_id))
				
			elif item["type"] in ["skill_list", "d100_skill_list"]:
				var header = Label.new()
				header.text = "-- " + item_name + " --"
				header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				target_container.add_child(header)
				
				for skill_name in item.get("skills", []):
					var skill_id = skill_name.to_lower().replace(" ", "_")
					
					# --- THE SAFETY CHECK ---
					# If this skill is in the token's blacklist, skip it completely!
					if local_data.get("deleted_skills", []).has(skill_id):
						continue

					if item["type"] == "d100_skill_list":
						var skill_row = HBoxContainer.new()
						
						var name_label = Label.new()
						name_label.text = skill_name
						name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						skill_row.add_child(name_label)
						
						var value_edit = LineEdit.new()
						value_edit.text = str(local_data.get(skill_id, 0))
						value_edit.custom_minimum_size.x = 45
						value_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
						
						value_edit.text_submitted.connect(func(new_text): _on_skill_value_edited(skill_id, new_text))
						value_edit.focus_exited.connect(func(): _on_skill_value_edited(skill_id, value_edit.text))
						skill_row.add_child(value_edit)
						
						var roll_btn = Button.new()
						roll_btn.text = "🎲"
						roll_btn.pressed.connect(func(): _on_roll_pressed(skill_id, skill_name))
						skill_row.add_child(roll_btn)
						
						var del_btn = Button.new()
						del_btn.text = "X"
						del_btn.modulate = Color(0.9, 0.2, 0.2) # A nice danger red
						del_btn.pressed.connect(func(): _delete_skill(skill_id, skill_row))
						skill_row.add_child(del_btn)
						
						target_container.add_child(skill_row)
						ui_nodes[skill_id] = skill_row
						
					else:
						var skill_row = skill_row_scene.instantiate()
						skill_row.get_node("SkillName").text = skill_name
						
						var checkbox = skill_row.get_node("ProficiencyCheck")
						var exp_checkbox = skill_row.get_node("ExpertiseCheck")
						
						if local_data.has(skill_id + "_prof"):
							checkbox.button_pressed = local_data[skill_id + "_prof"]
						if local_data.has(skill_id + "_exp"):
							exp_checkbox.button_pressed = local_data[skill_id + "_exp"]
						
						checkbox.toggled.connect(_on_proficiency_toggled.bind(skill_id))
						exp_checkbox.toggled.connect(_on_expertise_toggled.bind(skill_id))
						
						if skill_row.has_node("RollButton"):
							var roll_btn = skill_row.get_node("RollButton")
							roll_btn.pressed.connect(_on_roll_pressed.bind(skill_id, skill_name))
							
						target_container.add_child(skill_row)
						ui_nodes[skill_id] = skill_row
						
				continue
			elif item["type"] == "death_saves":
				new_row = death_saves_scene.instantiate()
				
			# Attach Roll Buttons
			if new_row and item.has("roll_type"):
				var roll_btn = new_row.get_node("RollButton")
				roll_btn.pressed.connect(_on_roll_pressed.bind(item_id, item_name))
			elif new_row and new_row.has_node("RollButton"):
				new_row.get_node("RollButton").hide()
				
			# GM Delete Button
			if new_row:
				var del_btn = new_row.get_node_or_null("DeleteBtn")
				if del_btn:
					if GameState.is_gm_mode:
						del_btn.show()
						del_btn.pressed.connect(func(): _on_gm_delete_pressed(item_id))
					else:
						del_btn.hide()
						
				target_container.add_child(new_row)
				ui_nodes[item_id] = new_row
		
	update_auto_math()

# --- AUTO-MATH ENGINE ---

func _on_stat_changed(value: float, stat_id: String):
	local_data[stat_id] = value
	save_sheet_to_token() # Auto-Save!

func _on_proficiency_toggled(is_pressed: bool, skill_id: String):
	local_data[skill_id + "_prof"] = is_pressed
	save_sheet_to_token() # Auto-Save!

func _on_expertise_toggled(is_pressed: bool, skill_id: String):
	local_data[skill_id + "_exp"] = is_pressed
	save_sheet_to_token() # Auto-Save!

func _on_blueprint_updated():
	generate_ui(CampaignManager.campaign_data["sheet_template"], local_data)

func _on_skill_value_edited(skill_key: String, new_text: String) -> void:
	var new_value = int(new_text)
	
	if local_data.get(skill_key, -1) != new_value:
		local_data[skill_key] = new_value
		save_sheet_to_token() # Auto-Save!

func update_auto_math():
	var template = CampaignManager.campaign_data.get("sheet_template", {})
	var layout = template.get("layout", [])
	
	var prof_bonus = local_data.get("prof_bonus", 2) 
	
	for tab_data in layout:
		for item in tab_data.get("elements", []):
			
			# --- 1. UNPACKED CORE STATS ---
			if item.get("type") == "stat_row" and current_dice_logic == "d20_high":
				for stat_name in item.get("stats", []):
					var stat_id = stat_name.to_lower()
					if not ui_nodes.has(stat_id): continue
					
					var row = ui_nodes[stat_id]
					var score = local_data.get(stat_id, 10)
					
					var mod = floor((score - 10) / 2.0) 
					local_data[stat_id + "_mod"] = mod 
					
					var sign_str = "+" if mod >= 0 else ""
					if row.has_node("ModifierLabel"):
						row.get_node("ModifierLabel").text = sign_str + str(mod)
						
					# Auto-Initiative Link
					if stat_id == "dex":
						local_data["init_bonus"] = mod
						if ui_nodes.has("init_bonus"):
							var init_row = ui_nodes["init_bonus"]
							if init_row.has_node("BaseValue"):
								init_row.get_node("BaseValue").set_value_no_signal(mod)
								
				continue 
				
			# --- 2. UNPACKED SKILL LISTS ---
			elif item.get("type") in ["skill_list", "d100_skill_list"] and current_dice_logic == "d20_high":
				for skill_name in item.get("skills", []):
					var skill_id = skill_name.to_lower().replace(" ", "_")
					if not ui_nodes.has(skill_id): continue
					var row = ui_nodes[skill_id]
					
					var linked_stat = dnd_skill_map.get(skill_id, "dex") 
					var stat_mod = local_data.get(linked_stat + "_mod", 0)
					var is_prof = local_data.get(skill_id + "_prof", false)
					var is_expert = local_data.get(skill_id + "_exp", false)
					
					var total = stat_mod
					
					if is_expert: total += (prof_bonus * 2)
					elif is_prof: total += prof_bonus
					
					local_data[skill_id + "_total"] = total
					if row.has_node("TotalValue"):
						row.get_node("TotalValue").set_value_no_signal(total)
						
				continue 

			# --- 3. SINGLE ELEMENTS ---
			var item_id = item.get("key", item.get("id", "unknown"))
			
			if not ui_nodes.has(item_id): continue
			var row = ui_nodes[item_id]
			
			if item.get("auto_math") == "dnd_modifier":
				var score = local_data.get(item_id, 10)
				var mod = floor((score - 10) / 2.0) 
				local_data[item_id + "_mod"] = mod 
				var sign_str = "+" if mod >= 0 else ""
				if row.has_node("ModifierLabel"):
					row.get_node("ModifierLabel").text = sign_str + str(mod)

			elif item.get("auto_math") == "dnd_skill":
				var linked_stat = item.get("linked_stat", "")
				var stat_mod = local_data.get(linked_stat + "_mod", 0)
				var is_prof = local_data.get(item_id + "_prof", false)
				var is_expert = local_data.get(item_id + "_exp", false)
				
				var total = stat_mod
				if is_expert: total += (prof_bonus * 2)
				elif is_prof: total += prof_bonus
				
				local_data[item_id + "_total"] = total
				if row.has_node("TotalValue"):
					row.get_node("TotalValue").set_value_no_signal(total)

			elif item.get("auto_math") == "dnd_initiative":
				var linked_stat = item.get("linked_stat", "dex")
				var dex_mod = local_data.get(linked_stat + "_mod", 0)
				local_data[item_id] = dex_mod
				if row.has_node("BaseValue"):
					row.get_node("BaseValue").set_value_no_signal(dex_mod)

func _on_gm_delete_pressed(stat_id: String):
	if not GameState.is_gm_mode: return
	pass

# --- ROLLING ---

func _execute_fast_roll(roll_name: String, modifier: int) -> void:
	var char_name = local_data.get("name", "Unknown Character")
	if char_name.strip_edges() == "": char_name = "Unknown Character"
	
	var is_whisper = false
	CampaignManager.fast_roll_requested.emit(char_name, roll_name, modifier, current_dice_logic, is_whisper)

func _on_roll_pressed(item_id: String, roll_name: String):
	var value_to_send = 0
	
	if current_dice_logic == "d100_under":
		value_to_send = local_data.get(item_id, 0)
	else:
		if local_data.has(item_id + "_total"):
			value_to_send = local_data[item_id + "_total"]
		elif local_data.has(item_id + "_mod"):
			value_to_send = local_data[item_id + "_mod"]
		else:
			value_to_send = local_data.get(item_id, 0)
			
	var display_name = local_data.get("name", current_token_name)
	var is_whisper = false
	CampaignManager.fast_roll_requested.emit(display_name, roll_name, value_to_send, current_dice_logic, is_whisper)


func _delete_skill(skill_id: String, row_node: Node):
	# 1. Create the tracking array if it doesn't exist
	if not local_data.has("deleted_skills"):
		local_data["deleted_skills"] = []
		
	# 2. Add the skill to the blacklist so it never respawns
	if not local_data["deleted_skills"].has(skill_id):
		local_data["deleted_skills"].append(skill_id)
		
	# 3. Destroy the visual row
	row_node.queue_free()
	
	# 4. Clean up the node tracker
	if ui_nodes.has(skill_id):
		ui_nodes.erase(skill_id)
		
	# 5. Tell the server we updated our sheet!
	save_sheet_to_token()


# --- POPUP HANDLING ---

func _on_add_stat_btn_pressed():
	if GameState.is_gm_mode:
		if add_popup:
			add_popup.popup_centered()

# --- PERSISTENT SAVE TO TOKEN BRAIN ---
func save_sheet_to_token():
	update_auto_math() # Ensure math is fresh before checking differences
	
	var main_board = get_tree().current_scene
	
	if main_board and current_token_name != "":
		for key in local_data.keys():
			if not original_data.has(key) or original_data[key] != local_data[key]:
				main_board.broadcast_token_data_update(current_token_name, key, local_data[key])
				
		original_data = local_data.duplicate(true)
		print("Character Sheet modifications saved to network token: ", current_token_name)
