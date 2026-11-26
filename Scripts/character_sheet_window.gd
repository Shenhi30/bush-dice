extends PanelContainer # Or Window, depending on your root

const WindowDrag = preload("res://Scripts/window_drag.gd")

@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer
@onready var title_label = $MarginContainer/VBoxContainer/HBoxContainer/TitleLabel
@onready var add_stat_btn = $MarginContainer/VBoxContainer/HBoxContainer/AddStatBtn
@onready var save_btn = $MarginContainer/VBoxContainer/HBoxContainer/SaveBtn
@onready var add_popup = $AddBlueprintPopup
@onready var close_btn = $MarginContainer/VBoxContainer/HBoxContainer/CloseBtn

@onready var gm_settings_row = $MarginContainer/VBoxContainer/GMSettingsRow
@onready var gm_checkbox = $MarginContainer/VBoxContainer/GMSettingsRow/CMCheckBox
@onready var category_dropdown = $MarginContainer/VBoxContainer/GMSettingsRow/CategoryDropdown

var is_building_ui: bool = false

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

func _ready():
	WindowDrag.attach(title_label, self)
	CampaignManager.blueprint_updated.connect(_on_blueprint_updated)
	add_stat_btn.pressed.connect(_on_add_stat_btn_pressed)
	
	if save_btn:
		save_btn.pressed.connect(save_sheet_to_token)
	
	if close_btn:
		close_btn.pressed.connect(func(): hide())
	
	if GameState.is_gm_mode:
		add_stat_btn.show()
	
	if gm_settings_row:
		if GameState.is_gm_mode:
			gm_settings_row.show() 
			
			
			if gm_checkbox:
				gm_checkbox.toggled.connect(func(pressed):
					local_data["is_gm_only"] = pressed
					save_sheet_to_token()
				)
				
			if category_dropdown:
				_populate_category_dropdown()
				category_dropdown.item_selected.connect(func(index):
					local_data["menu_category"] = category_dropdown.get_item_text(index)
					save_sheet_to_token()
				)
		else:
			gm_settings_row.hide()
	
	var auto_math_btn = CheckBox.new()
	auto_math_btn.text = "Auto-Calculate Stats"
	auto_math_btn.name = "AutoMathToggle"
	
	var top_bar = $MarginContainer/VBoxContainer/HBoxContainer
	top_bar.add_child(auto_math_btn)
	top_bar.move_child(auto_math_btn, save_btn.get_index()) # Ставимо перед кнопкою Save
	
	auto_math_btn.toggled.connect(func(pressed):
		local_data["use_auto_math"] = pressed
		if pressed: update_auto_math()
		save_sheet_to_token()
	)
	
	generate_ui(CampaignManager.campaign_data.get("sheet_template", {}), {})

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
		
		if gm_checkbox:
			gm_checkbox.set_pressed_no_signal(local_data.get("is_gm_only", false))
			
			var auto_math_btn = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/AutoMathToggle")
			if auto_math_btn:
				auto_math_btn.set_pressed_no_signal(local_data.get("use_auto_math", true))
		
	if category_dropdown and GameState.is_gm_mode:
		# Ховаємо старий випадаючий список, нам він більше не потрібен!
		category_dropdown.hide() 
		
		var parent_container = category_dropdown.get_parent()
		var cat_input = parent_container.get_node_or_null("CustomCategoryInput")
		
		# Якщо ми ще не створили текстове поле, створюємо його динамічно
		if not cat_input:
			cat_input = LineEdit.new()
			cat_input.name = "CustomCategoryInput"
			cat_input.placeholder_text = "e.g. Bosses, Summons..."
			cat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Вставляємо його на місце старого випадаючого списку
			parent_container.add_child(cat_input)
			parent_container.move_child(cat_input, category_dropdown.get_index())
			
			# Підключаємо сигнал збереження при введенні тексту
			cat_input.text_changed.connect(func(new_text: String):
				local_data["menu_category"] = new_text.strip_edges()
				save_sheet_to_token()
			)
			
		# Встановлюємо поточну категорію (за замовчуванням Party)
		cat_input.text = local_data.get("menu_category", "Party")

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
					# 1. Calculate the difference for floating text
					var old_hp = int(local_data.get(curr_key, val))
					var amount_changed = int(val) - old_hp
					
					# 2. Update local storage
					local_data[curr_key] = val
					
					# 3. Trigger Universal Floating Text if HP actually moved
					if amount_changed != 0 and curr_key in ["hp", "current_hp", "health"]:
						var main_board = get_tree().current_scene
						if main_board and main_board.has_method("broadcast_floating_text"):
							main_board.broadcast_floating_text(current_token_name, amount_changed)
							
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
				
			elif item.get("type") == "spell_book":
				
				var spell_book_container = VBoxContainer.new()
				spell_book_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				spell_book_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
				spell_book_container.custom_minimum_size = Vector2(320, 600) # ПРИМУСОВИЙ РОЗМІР!
				
				var max_level = int(item.get("max_level", 9)) 
				
				# Додаємо контейнер на вкладку "Spells"
				target_container.add_child(spell_book_container)
				
				# Малюємо інтерфейс
				_draw_spell_book(spell_book_container, max_level)
				
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
	
	is_building_ui = false

func _on_category_selected(index: int):
	if category_dropdown:
		var selected_category = category_dropdown.get_item_text(index)
		
		# 1. Force it into local memory instantly
		local_data["menu_category"] = selected_category
		
		# 2. Trigger your perfect save function!
		save_sheet_to_token()

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

func _on_manual_override(value: float, data_key: String):
	local_data[data_key] = value
	save_sheet_to_token()

func update_auto_math():
	var template = CampaignManager.campaign_data.get("sheet_template", {})
	var layout = template.get("layout", [])
	
	# Перевіряємо, чи ввімкнена математика! (За замовчуванням True)
	var use_auto = local_data.get("use_auto_math", true) 
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
					
					# Якщо авто-математика увімкнена, перезаписуємо пам'ять. Якщо ні - залишаємо ручні зміни!
					if use_auto:
						local_data[stat_id + "_mod"] = floor((score - 10) / 2.0) 
						
					var mod = local_data.get(stat_id + "_mod", 0)
					
					if row.has_node("ModifierLabel"):
						var mod_node = row.get_node("ModifierLabel")
						if mod_node is SpinBox: # Якщо ви зробили його редагованим полем
							mod_node.set_value_no_signal(mod)
							if not mod_node.value_changed.is_connected(_on_manual_override):
								mod_node.value_changed.connect(_on_manual_override.bind(stat_id + "_mod"))
						elif mod_node is Label: # Якщо це просто текст
							var sign_str = "+" if mod >= 0 else ""
							mod_node.text = sign_str + str(mod)
							
					# Auto-Initiative Link
					if stat_id == "dex":
						if use_auto: local_data["init_bonus"] = mod
						if ui_nodes.has("init_bonus") and ui_nodes["init_bonus"].has_node("BaseValue"):
							var init_box = ui_nodes["init_bonus"].get_node("BaseValue")
							init_box.set_value_no_signal(local_data.get("init_bonus", mod))
							
			# --- 2. UNPACKED SKILL LISTS ---
			elif item.get("type") in ["skill_list", "d100_skill_list"] and current_dice_logic == "d20_high":
				for skill_name in item.get("skills", []):
					var skill_id = skill_name.to_lower().replace(" ", "_")
					if not ui_nodes.has(skill_id): continue
					var row = ui_nodes[skill_id]
					
					if use_auto:
						var linked_stat = dnd_skill_map.get(skill_id, "dex") 
						var stat_mod = local_data.get(linked_stat + "_mod", 0)
						var is_prof = local_data.get(skill_id + "_prof", false)
						var is_expert = local_data.get(skill_id + "_exp", false)
						
						var total = stat_mod
						if is_expert: total += (prof_bonus * 2)
						elif is_prof: total += prof_bonus
						local_data[skill_id + "_total"] = total
					
					# Застосовуємо значення до UI і дозволяємо ручне збереження
					if row.has_node("TotalValue"):
						var total_box = row.get_node("TotalValue")
						total_box.set_value_no_signal(local_data.get(skill_id + "_total", 0))
						if not total_box.value_changed.is_connected(_on_manual_override):
							total_box.value_changed.connect(_on_manual_override.bind(skill_id + "_total"))

			# --- 3. SINGLE ELEMENTS ---
			var item_id = item.get("key", item.get("id", "unknown"))
			if not ui_nodes.has(item_id): continue
			var row = ui_nodes[item_id]
			
			if item.get("auto_math") == "dnd_modifier":
				if use_auto:
					var score = local_data.get(item_id, 10)
					local_data[item_id + "_mod"] = floor((score - 10) / 2.0) 
					
				var mod = local_data.get(item_id + "_mod", 0)
				if row.has_node("ModifierLabel"):
					var mod_node = row.get_node("ModifierLabel")
					if mod_node is SpinBox:
						mod_node.set_value_no_signal(mod)
						if not mod_node.value_changed.is_connected(_on_manual_override):
							mod_node.value_changed.connect(_on_manual_override.bind(item_id + "_mod"))
					elif mod_node is Label:
						var sign_str = "+" if mod >= 0 else ""
						mod_node.text = sign_str + str(mod)

			elif item.get("auto_math") == "dnd_skill":
				if use_auto:
					var linked_stat = item.get("linked_stat", "")
					var stat_mod = local_data.get(linked_stat + "_mod", 0)
					var is_prof = local_data.get(item_id + "_prof", false)
					var is_expert = local_data.get(item_id + "_exp", false)
					
					var total = stat_mod
					if is_expert: total += (prof_bonus * 2)
					elif is_prof: total += prof_bonus
					local_data[item_id + "_total"] = total
					
				if row.has_node("TotalValue"):
					var total_box = row.get_node("TotalValue")
					total_box.set_value_no_signal(local_data.get(item_id + "_total", 0))
					if not total_box.value_changed.is_connected(_on_manual_override):
						total_box.value_changed.connect(_on_manual_override.bind(item_id + "_total"))


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

func _populate_category_dropdown():
	category_dropdown.clear()
	
	# Only list the exact menus you have built in your GM Dashboard ToolPallete
	var target_menus = ["Party", "Monsters", "NPCs"]
	
	for menu in target_menus:
		category_dropdown.add_item(menu)


# --- POPUP HANDLING ---

func _on_add_stat_btn_pressed():
	if GameState.is_gm_mode:
		if add_popup:
			add_popup.popup_centered()

# --- PERSISTENT SAVE TO TOKEN BRAIN ---
func save_sheet_to_token():
	
	if is_building_ui: 
		return

	update_auto_math() # Ensure math is fresh before checking differences
	
	var main_board = get_tree().current_scene
	
	if main_board and current_token_name != "":
		for key in local_data.keys():
			if not original_data.has(key) or original_data[key] != local_data[key]:
				main_board.broadcast_token_data_update(current_token_name, key, local_data[key])
				
		original_data = local_data.duplicate(true)
		print("Character Sheet modifications saved to network token: ", current_token_name)
		
	if GameState.is_gm_mode:
			if not CampaignManager.campaign_data.has("pc_vault"):
				CampaignManager.campaign_data["pc_vault"] = {}
				
			# 1. Grab whatever text is currently inside the input fields
			var c_name = str(local_data.get("name", "")).strip_edges()
			var p_name = str(local_data.get("player_name", "")).strip_edges() 
			
			# 2. Decide the best key: Character Name -> Player Name -> Image Filename -> Raw Token ID
			var vault_key = ""
			
			if c_name != "" and c_name.to_lower() != "unknown":
				vault_key = c_name
			elif p_name != "":
				vault_key = p_name
			elif local_data.has("art_path") and local_data["art_path"] != "":
				# Fallback to the clean image file name (e.g., "bounty_hunter") instead of "Token_40934"
				vault_key = local_data["art_path"].get_file().get_basename()
			else:
				vault_key = current_token_name
				
			# 3. Clean up the old garbage Token ID from the vault if it was stored under that previously
			if vault_key != current_token_name and CampaignManager.campaign_data["pc_vault"].has(current_token_name):
				CampaignManager.campaign_data["pc_vault"].erase(current_token_name)
				
			# 4. Save into the Vault permanently under the clean name!
			CampaignManager.campaign_data["pc_vault"][vault_key] = local_data.duplicate(true)
			
			# 5. Refresh Dashboard menus
			var dashboard = get_tree().root.find_child("GMDashboard", true, false)
			if dashboard and dashboard.has_method("refresh_toolpallete_lists"):
				dashboard.refresh_toolpallete_lists()

# ==========================================
# SPELL BOOK SYSTEM
# ==========================================

func _draw_spell_book(container: Control, max_level: int):
	for child in container.get_children():
		child.queue_free()
		
		
	# 1. БЕЗПЕЧНЕ завантаження словника заклинань
	var spells_data = local_data.get("spells", {})
	if typeof(spells_data) != TYPE_DICTIONARY:
		spells_data = {}
		local_data["spells"] = spells_data
		
	for level in range(max_level + 1):
		var level_str = str(level)
		
		# 2. БЕЗПЕЧНЕ завантаження масиву рівня
		var level_list = spells_data.get(level_str, [])
		if typeof(level_list) != TYPE_ARRAY:
			level_list = []
			spells_data[level_str] = level_list
			
		var level_box = VBoxContainer.new()
		
		# --- ЗАГОЛОВОК ТА КНОПКА ДОДАВАННЯ ---
		var header = HBoxContainer.new()
		var title = Label.new()
		title.text = "Cantrips (Level 0)" if level == 0 else "Level " + str(level)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		
		if level > 0:
			var slot_label = Label.new()
			slot_label.text = "Slots: "
			header.add_child(slot_label)
			
			var max_slots = SpinBox.new()
			max_slots.min_value = 0
			max_slots.max_value = 20
			max_slots.custom_minimum_size.x = 55
			max_slots.value = int(local_data.get("spell_slots_max_" + level_str, 0))
			header.add_child(max_slots)
			
			var cb_container = HBoxContainer.new()
			header.add_child(cb_container)
			
			# Малюємо чекбокси
			var used_slots = int(local_data.get("spell_slots_used_" + level_str, 0))
			for j in range(max_slots.value):
				var cb = CheckBox.new()
				cb.focus_mode = Control.FOCUS_NONE # Прибираємо некрасиву рамку фокусу
				cb.button_pressed = (j < used_slots)
				# Підключаємо сигнал для відстеження кліків
				cb.toggled.connect(_on_spell_slot_toggled.bind(cb_container, level_str))
				cb_container.add_child(cb)
				
			# Оновлюємо кількість чекбоксів, якщо змінили Max Slots
			max_slots.value_changed.connect(_on_max_slots_changed.bind(container, max_level, level_str))
		
		var add_btn = Button.new()
		add_btn.text = "+ Add Spell"
		add_btn.pressed.connect(_on_add_spell_pressed.bind(container, max_level, level_str))
		
		header.add_child(title)
		header.add_child(add_btn)
		level_box.add_child(header)
		
		# --- СПИСОК ЗАКЛИНАНЬ (З КУБИКАМИ) ---
		for i in range(level_list.size()):
			var spell = level_list[i]
			if typeof(spell) != TYPE_DICTIONARY: continue
			
			var spell_row = HBoxContainer.new()
			
			# 1. Назва
			var name_input = LineEdit.new()
			name_input.text = spell.get("name", "")
			name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_input.placeholder_text = "Spell Name"
			name_input.text_changed.connect(_on_spell_text_changed.bind("name", level_str, i))
			name_input.focus_exited.connect(save_sheet_to_token)
			spell_row.add_child(name_input)
			
			# 2. Кількість Кубиків
			var count_spin = SpinBox.new()
			count_spin.min_value = 0
			count_spin.max_value = 9999
			count_spin.value = spell.get("dice_count", 0)
			count_spin.custom_minimum_size.x = 55
			count_spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_spin.value_changed.connect(_on_spell_number_changed.bind("dice_count", level_str, i))
			spell_row.add_child(count_spin)
			
			var d_label = Label.new()
			d_label.text = "d"
			d_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			spell_row.add_child(d_label)
			
			# 3. Грані Кубика
			var sides_spin = SpinBox.new()
			sides_spin.min_value = 0
			sides_spin.max_value = 100
			sides_spin.value = spell.get("dice_sides", 0)
			sides_spin.custom_minimum_size.x = 55
			sides_spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
			sides_spin.value_changed.connect(_on_spell_number_changed.bind("dice_sides", level_str, i))
			spell_row.add_child(sides_spin)
			
			#  4. Вибір Характеристики (Attribute Dropdown) ---
			var attr_select = OptionButton.new()
			var attrs = ["None", "STR", "DEX", "CON", "INT", "WIS", "CHA"]
			for a in attrs:
				attr_select.add_item(a)
				
			attr_select.selected = spell.get("attr_index", 0)
			attr_select.item_selected.connect(_on_spell_attr_changed.bind("attr_index", level_str, i))
			spell_row.add_child(attr_select)
			
			# 5. Кнопки: Кидок (🎲), Опис (📝), Видалити (X)
			var roll_btn = Button.new()
			roll_btn.text = "🎲Roll"
			roll_btn.pressed.connect(func(): _on_spell_roll_pressed(name_input.text, count_spin.value, sides_spin.value, attr_select.selected))
			spell_row.add_child(roll_btn)
			
			var desc_btn = Button.new()
			desc_btn.text = "📝Desc"
			desc_btn.pressed.connect(_on_desc_btn_pressed.bind(level_str, i, name_input.text, spell.get("desc", "")))
			spell_row.add_child(desc_btn)
			
			var del_btn = Button.new()
			del_btn.text = "X"
			del_btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			del_btn.pressed.connect(_on_delete_spell_pressed.bind(container, max_level, level_str, i))
			spell_row.add_child(del_btn)
			
			level_box.add_child(spell_row)
			
		level_box.add_child(HSeparator.new())
		container.add_child(level_box)

func _on_spell_attr_changed(index_value: int, key: String, level_str: String, spell_index: int):
	var spells_dict = local_data.get("spells", {})
	if typeof(spells_dict) != TYPE_DICTIONARY: return
		
	var spell_list = spells_dict.get(level_str, [])
	if typeof(spell_list) != TYPE_ARRAY: return
		
	if spell_index < spell_list.size():
		if typeof(spell_list[spell_index]) == TYPE_DICTIONARY:
			spell_list[spell_index][key] = index_value
			spells_dict[level_str] = spell_list
			local_data["spells"] = spells_dict
			save_sheet_to_token()

func _on_spell_number_changed(value: float, key: String, level_str: String, index: int):
	var spells_dict = local_data.get("spells", {})
	if typeof(spells_dict) != TYPE_DICTIONARY: return
		
	var spell_list = spells_dict.get(level_str, [])
	if typeof(spell_list) != TYPE_ARRAY: return
		
	if index < spell_list.size():
		if typeof(spell_list[index]) == TYPE_DICTIONARY:
			# Save the SpinBox number to memory
			spell_list[index][key] = int(value)
			spells_dict[level_str] = spell_list
			local_data["spells"] = spells_dict
			save_sheet_to_token()

func _on_desc_btn_pressed(level_str: String, index: int, spell_name: String, current_desc: String):
	# Create a floating popup window entirely through code!
	var dialog = AcceptDialog.new()
	var display_name = spell_name if spell_name != "" else "Spell"
	dialog.title = display_name + " Description"
	
	var text_edit = TextEdit.new()
	text_edit.text = current_desc
	text_edit.custom_minimum_size = Vector2(400, 300)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	
	dialog.add_child(text_edit)
	add_child(dialog) # Add to the Character Sheet
	
	# When the user clicks "OK", save the text and destroy the popup
	dialog.confirmed.connect(func():
		_on_spell_text_changed(text_edit.text, "desc", level_str, index)
		save_sheet_to_token()
		dialog.queue_free()
	)
	
	# If they press "X" or "Cancel", just close it without saving
	dialog.canceled.connect(func(): dialog.queue_free())
	
	dialog.popup_centered()

func _on_spell_roll_pressed(spell_name: String, count: int, sides: int, attr_index: int):
	if count <= 0 or sides <= 0: return 
	
	# 1. Рахуємо кубики
	var dice_total = 0
	var rolls = []
	for i in range(count):
		var r = randi_range(1, sides)
		rolls.append(r)
		dice_total += r
		
	# 2. Шукаємо модифікатор характеристики
	var modifier = 0
	var attr_string = ""
	
	if attr_index > 0:
		var stat_keys = ["none", "str", "dex", "con", "int", "wis", "cha"]
		var base_stat = stat_keys[attr_index]
		attr_string = " + " + base_stat.to_upper()
		
		# Спочатку шукаємо модифікатор (напр. "int_mod"), якщо його немає — беремо чистий стат ("int")
		if local_data.has(base_stat + "_mod"):
			modifier = int(local_data[base_stat + "_mod"])
		else:
			modifier = int(local_data.get(base_stat, 0))
			
	var final_total = dice_total + modifier
	
	# 3. Форматуємо красиве повідомлення
	var display_name = spell_name if spell_name != "" else "Unknown Spell"
	var mod_display = (" +" + str(modifier)) if modifier > 0 else ((" " + str(modifier)) if modifier < 0 else "")
	
	var actual_character_name = local_data.get("name", current_token_name)
	
	var msg = "\n%s casts [b]%s[/b]!\nEffect: [color=yellow]%sd%s%s %s%s = %s[/color]" % [
		actual_character_name, # <--- Тепер тут справжнє ім'я!
		display_name, 
		count, 
		sides, 
		attr_string,
		str(rolls), 
		mod_display, 
		final_total
	]
	
	# 4. ВІДПРАВЛЯЄМО В МЕРЕЖУ З УРАХУВАННЯМ "GM ONLY"
	var main = get_tree().current_scene
	var my_name = GameState.player_name
	var color = "#ffd700" if GameState.is_gm_mode else "#99ccff"
	
	if main.has_method("receive_chat_message"):
		
		# ПЕРЕВІРЯЄМО ГАЛОЧКУ "GM ONLY" З ПАНЕЛІ КУБИКІВ MAINBOARD
		var is_secret = false
		if main.get("whisper_check") != null:
			is_secret = main.whisper_check.button_pressed
			
		# ЯКЩО СЕКРЕТНО
		if is_secret:
			var secret_msg = "[color=#b266ff][i](Secret Spell)[/i]" + msg + "[/color]\n"
			
			# Друкуємо локально, щоб гравець бачив свій секретний кидок
			main.receive_chat_message(my_name, secret_msg, color)
			
			# Якщо це гравець (не сервер), відправляємо шепіт GM-у
			if not multiplayer.is_server():
				main.rpc_id(1, "receive_whisper", secret_msg)
				
		# ЯКЩО ПУБЛІЧНО
		else:
			if multiplayer.is_server():
				main.receive_chat_message(my_name, msg, color)
				main.rpc("receive_chat_message", my_name, msg, color)
			else:
				main.rpc_id(1, "request_chat_message", my_name, msg, color)

func _on_add_spell_pressed(container: Control, max_level: int, level_str: String):
	var spells_dict = local_data.get("spells", {})
	if typeof(spells_dict) != TYPE_DICTIONARY: spells_dict = {}
		
	var spell_list = spells_dict.get(level_str, [])
	if typeof(spell_list) != TYPE_ARRAY: spell_list = []
		
	# Added dice default stats here!
	spell_list.append({"name": "", "desc": "", "dice_count": 0, "dice_sides": 0})
	
	spells_dict[level_str] = spell_list
	local_data["spells"] = spells_dict
	
	save_sheet_to_token()
	_draw_spell_book(container, max_level)

func _on_delete_spell_pressed(container: Control, max_level: int, level_str: String, index: int):
	var spells_dict = local_data.get("spells", {})
	if typeof(spells_dict) != TYPE_DICTIONARY: return
		
	var spell_list = spells_dict.get(level_str, [])
	if typeof(spell_list) != TYPE_ARRAY: return
		
	if index < spell_list.size():
		spell_list.remove_at(index)
		spells_dict[level_str] = spell_list
		local_data["spells"] = spells_dict
		
		save_sheet_to_token()
		_draw_spell_book(container, max_level)

func _on_spell_text_changed(new_text: String, key: String, level_str: String, index: int):
	var spells_dict = local_data.get("spells", {})
	if typeof(spells_dict) != TYPE_DICTIONARY: return
		
	var spell_list = spells_dict.get(level_str, [])
	if typeof(spell_list) != TYPE_ARRAY: return
		
	if index < spell_list.size():
		if typeof(spell_list[index]) == TYPE_DICTIONARY:
			spell_list[index][key] = new_text
			spells_dict[level_str] = spell_list
			local_data["spells"] = spells_dict

func _on_spell_slot_toggled(is_pressed: bool, cb_container: Control, level_str: String):
	# Рахуємо, скільки чекбоксів зараз натиснуто
	var count = 0
	for child in cb_container.get_children():
		if child is CheckBox and child.button_pressed:
			count += 1
			
	# Зберігаємо це число
	local_data["spell_slots_used_" + level_str] = count
	save_sheet_to_token()

func _on_max_slots_changed(val: float, container: Control, max_level: int, level_str: String):
	local_data["spell_slots_max_" + level_str] = int(val)
	
	# Якщо ми зменшили максимум слотів, переконуємося, що використані слоти не перевищують новий максимум
	var used = int(local_data.get("spell_slots_used_" + level_str, 0))
	if used > int(val):
		local_data["spell_slots_used_" + level_str] = int(val)
		
	save_sheet_to_token()
	
	# Перемальовуємо інтерфейс, щоб додати або видалити чекбокси на екрані
	_draw_spell_book(container, max_level)

#=========================================
#=========================================
