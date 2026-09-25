extends PanelContainer

# Variables to hold the UI we are about to create
var expandable_section: VBoxContainer
var quest_list: VBoxContainer

func _ready():
	# 1. LINK TO THE NETWORK HUB
	# This tells Godot: "Whenever MainBoard says 'refresh_quests', update this UI!"
	add_to_group("quest_ui")
	
	# 2. SETUP THE MAIN PANEL
	self.custom_minimum_size = Vector2(300, 0)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	margin.add_child(main_vbox)
	
	# 3. CREATE THE HEADER (Toggle + Open Window)
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var toggle_btn = Button.new()
	toggle_btn.text = "📌 Pinned Quests"
	toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Remove the ugly grey background from the title button
	toggle_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	toggle_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	toggle_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	header_hbox.add_child(toggle_btn)
	
	var open_log_btn = Button.new()
	open_log_btn.text = "📖" # Або "Open Log"
	header_hbox.add_child(open_log_btn)
	
	# 4. CREATE THE EXPANDABLE FOLDER
	expandable_section = VBoxContainer.new()
	main_vbox.add_child(expandable_section)
	
	main_vbox.add_child(HSeparator.new()) # A nice visual line
	
	# 5. CREATE THE SCROLL BOX
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expandable_section.add_child(scroll)
	
	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(quest_list)
	
	# (The Add/Edit inputs were removed here, as they belong in the new QuestWindow!)
	
	toggle_btn.pressed.connect(_on_toggle_pressed)
	open_log_btn.pressed.connect(_on_open_log_pressed)
	
	refresh_quests()

# --- LOGIC FUNCTIONS ---

func _on_toggle_pressed():
	expandable_section.visible = not expandable_section.visible
	self.size = Vector2.ZERO # Force the main panel to shrink

func _on_open_log_pressed():
	# Шукаємо наше велике вікно квестів у дереві сцени та відкриваємо його
	var quest_window = get_tree().root.find_child("QuestWindow", true, false)
	if quest_window:
		quest_window.visible = true
		
		# Якщо це Window, викликаємо grab_focus/move_to_front
		if quest_window.has_method("move_to_front"):
			quest_window.move_to_front()
	else:
		print("ERROR: QuestWindow не знайдено! Переконайтеся, що ви додали його в UILayer.")


# This replaces your old _update_ui(). It is called automatically by MainBoard!
func refresh_quests():
	# 1. Clear old list
	for child in quest_list.get_children():
		child.queue_free()
		
	# 2. Grab the global memory
	var all_quests = CampaignManager.campaign_data.get("quests", {})
	
	# --- THE FIX: HANDLE LEGACY ARRAYS ---
	# If an old save file still has quests saved as an Array [],
	# wipe it and turn it into a Dictionary {} to prevent crashes!
	if typeof(all_quests) == TYPE_ARRAY:
		all_quests = {}
		CampaignManager.campaign_data["quests"] = {}
	# -------------------------------------
	
	# 3. Draw the new list
	for q_id in all_quests.keys():
		var q_data = all_quests[q_id]
		
		# ONLY SHOW IT IF IT IS PINNED!
		if q_data.get("pinned", false):
			var quest_ui = VBoxContainer.new()
			
			# Title
			var title = Label.new()
			title.text = "• " + q_data.get("title", "Unknown Quest")
			title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Gold title
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			quest_ui.add_child(title)
			
			# Description (Optional)
			var desc_text = q_data.get("desc", "").strip_edges()
			if desc_text != "":
				var desc = Label.new()
				desc.text = desc_text
				desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				desc.add_theme_font_size_override("font_size", 12) 
				desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)) # Grey text
				quest_ui.add_child(desc)
			
			# Add a faint separator line between pinned quests
			quest_ui.add_child(HSeparator.new())
			
			quest_list.add_child(quest_ui)
