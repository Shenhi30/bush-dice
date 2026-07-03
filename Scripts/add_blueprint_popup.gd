extends Window

@onready var tab_selector = $MarginContainer/VBoxContainer/TabSelector # Make sure this path matches your scene!
@onready var type_dropdown = $MarginContainer/VBoxContainer/TypeRow/TypeDropdown
@onready var name_input = $MarginContainer/VBoxContainer/NameRow/NameInput
@onready var link_row = $MarginContainer/VBoxContainer/LinkRow
@onready var link_dropdown = $MarginContainer/VBoxContainer/LinkRow/LinkDropdown
@onready var add_button = $MarginContainer/VBoxContainer/AddButton

# We use this array to remember the internal "key" of the stat, not just the display name
var dropdown_ids: Array = []

func _ready():
	hide()
	
	close_requested.connect(hide)
	type_dropdown.item_selected.connect(_on_type_changed)
	add_button.pressed.connect(_on_add_pressed)
	
	# The 'about_to_popup' signal fires right BEFORE the window becomes visible!
	about_to_popup.connect(refresh_dynamic_dropdown)
	
	_on_type_changed(type_dropdown.selected)

# --- DYNAMIC DROPDOWN LOGIC ---
func refresh_dynamic_dropdown():
	link_dropdown.clear()
	dropdown_ids.clear()
	
	if tab_selector:
		tab_selector.clear()
	
	var template = CampaignManager.campaign_data["sheet_template"]
	var layout = template.get("layout", [])
	
	# 1. Populate the Tab Selector with available tabs
	for tab_data in layout:
		if tab_selector:
			tab_selector.add_item(tab_data.get("tab", "General"))
			
	# 2. Look through all nested tabs for any available numbers/attributes to link
	for tab_data in layout:
		for item in tab_data.get("elements", []):
			if item.get("type") in ["number", "stat_box", "resource_bar"]:
				# Add the readable name to the UI dropdown
				link_dropdown.add_item(item.get("label", item.get("name", "Unknown")))
				# Save the internal Key (e.g., "str", "sanity") in our hidden array
				dropdown_ids.append(item.get("key", item.get("id", "none")))
			
	# Fallback just in case there are zero attributes found
	if dropdown_ids.size() == 0:
		link_dropdown.add_item("None")
		dropdown_ids.append("none")

func _on_type_changed(index: int):
	if index == 0: # Attribute/Number
		link_row.hide()
	else:          # Skill
		link_row.show()

# --- ADD TO BLUEPRINT LOGIC ---
func _on_add_pressed():
	var item_name = name_input.text.strip_edges()
	if item_name == "":
		return
		
	var safe_key = item_name.to_lower().replace(" ", "_")
	var is_skill = (type_dropdown.selected == 1)
	
	var new_element = {
		"key": safe_key,
		"label": item_name
	}
	
	# Fetch the current system's dice logic to apply appropriate automation
	var template = CampaignManager.campaign_data["sheet_template"].duplicate(true)
	var current_dice_logic = template.get("dice_logic", "d20_high")
	
	if is_skill:
		var linked_stat_id = dropdown_ids[link_dropdown.selected]
		new_element["type"] = "skill"
		new_element["linked_stat"] = linked_stat_id
		
		# Auto-inject D&D logic if we are playing a d20 system
		if current_dice_logic == "d20_high":
			new_element["auto_math"] = "dnd_skill"
			new_element["roll_type"] = "d20_plus_mod"
	else:
		new_element["type"] = "number"
		if current_dice_logic == "d20_high":
			new_element["auto_math"] = "dnd_modifier" 
			new_element["roll_type"] = "d20_plus_mod"
		
	# Find the chosen tab index from our OptionButton
	var layout = template.get("layout", [])
	var target_tab_index = 0
	if tab_selector:
		target_tab_index = tab_selector.selected
		
	# Inject the new element into that specific tab's "elements" array
	if target_tab_index >= 0 and target_tab_index < layout.size():
		if not layout[target_tab_index].has("elements"):
			layout[target_tab_index]["elements"] = []
			
		layout[target_tab_index]["elements"].append(new_element)
		
	# Broadcast the change via our secure GM function
	CampaignManager.gm_update_blueprint(template)
	
	name_input.text = ""
	hide()
