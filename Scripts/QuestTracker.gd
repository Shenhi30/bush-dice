extends PanelContainer

# Our data memory
var quests: Array = []

# Variables to hold the UI we are about to create
var expandable_section: VBoxContainer
var quest_list: VBoxContainer
var quest_input: LineEdit

func _ready():
	# 1. SETUP THE MAIN PANEL
	self.custom_minimum_size = Vector2(300, 0) # Make it at least 300px wide
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	margin.add_child(main_vbox)
	
	# 2. CREATE THE TOGGLE BUTTON
	var toggle_btn = Button.new()
	toggle_btn.text = "📜 Quest Log"
	# Remove the ugly grey background from the title button
	toggle_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	toggle_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	toggle_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	main_vbox.add_child(toggle_btn)
	
	# 3. CREATE THE EXPANDABLE FOLDER
	expandable_section = VBoxContainer.new()
	main_vbox.add_child(expandable_section)
	
	main_vbox.add_child(HSeparator.new()) # A nice visual line
	
	# 4. CREATE THE SCROLL BOX
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expandable_section.add_child(scroll)
	
	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(quest_list)
	
	# 5. CREATE THE ADD QUEST INPUTS
	var add_box = HBoxContainer.new()
	expandable_section.add_child(add_box)
	
	quest_input = LineEdit.new()
	quest_input.placeholder_text = "New objective..."
	quest_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_box.add_child(quest_input)
	
	var add_btn = Button.new()
	add_btn.text = "Add"
	add_box.add_child(add_btn)
	
	# 6. WIRE EVERYTHING UP (No Scene Tree needed!)
	toggle_btn.pressed.connect(_on_toggle_pressed)
	add_btn.pressed.connect(_on_add_pressed)
	# Bonus feature: Hitting 'Enter' on the keyboard will also add the quest!
	quest_input.text_submitted.connect(func(t): _on_add_pressed()) 
	
	_update_ui()

# --- LOGIC FUNCTIONS ---

func _on_toggle_pressed():
	expandable_section.visible = not expandable_section.visible
	self.size = Vector2.ZERO # Force the main panel to shrink

func _on_add_pressed():
	var text = quest_input.text.strip_edges()
	if text == "": 
		return # Don't add blank quests
		
	quests.append({"title": text})
	quest_input.text = "" # Clear the box
	_update_ui()

func _update_ui():
	# Clear old list
	for child in quest_list.get_children():
		child.queue_free()
		
	# Draw new list
	for quest in quests:
		var btn = Button.new()
		btn.text = "• " + quest["title"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		# Make it look like plain text
		var empty_style = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4)) # Red on hover
		
		# Wire up the delete function
		btn.pressed.connect(func():
			quests.erase(quest)
			_update_ui()
		)
		
		quest_list.add_child(btn)
