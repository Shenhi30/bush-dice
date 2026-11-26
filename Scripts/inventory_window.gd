extends Panel

const WindowDrag = preload("res://Scripts/window_drag.gd")

# Custom signals to tell the MainBoard what the user clicked
signal close_requested
signal add_item_requested(item_name: String, item_desc: String)
signal delete_item_requested(item_id: String)

@onready var title_label = $TitleLabel
@onready var item_list = $ScrollContainer/ItemList
@onready var name_input = $HBoxContainer/ItemNameInput
@onready var desc_input = $HBoxContainer/ItemDescInput
@onready var add_btn = $HBoxContainer/AddItemBtn
@onready var close_btn = $CloseBtn

func _ready():
	WindowDrag.attach(title_label, self)
	
	# Wire up our local buttons to fire our custom signals
	close_btn.pressed.connect(func(): close_requested.emit())
	add_btn.pressed.connect(_on_add_pressed)
	
	# Allow hitting "Enter" to add an item
	name_input.text_submitted.connect(func(_text): _on_add_pressed())
	desc_input.text_submitted.connect(func(_text): _on_add_pressed())

func _on_add_pressed():
	var i_name = name_input.text.strip_edges()
	var i_desc = desc_input.text.strip_edges()
	
	if i_name == "": return # Don't add blank items
	
	# Clear the boxes
	name_input.text = ""
	desc_input.text = ""
	
	# Tell the MainBoard to handle the network math!
	add_item_requested.emit(i_name, i_desc)

# The MainBoard will call this function to redraw the list
func populate(character_name: String, items: Array):
	title_label.text = character_name + "'s Backpack"
	
	# 1. Clear the old list
	for child in item_list.get_children():
		child.queue_free()
		
	# 2. Rebuild the list from the data
	for item in items:
		var row = HBoxContainer.new()
		
		var text_lbl = Label.new()
		text_lbl.text = item["name"]
		var qty = int(item.get("qty", 1))
		if qty > 1:
			text_lbl.text += " x" + str(qty)
		if item.has("desc") and item["desc"] != "":
			text_lbl.text += " - " + item["desc"]
			
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.modulate = Color(0.8, 0.2, 0.2)
		
		# Connect the delete button to shout the specific item ID
		del_btn.pressed.connect(func(): delete_item_requested.emit(item["id"]))
		
		row.add_child(text_lbl)
		row.add_child(del_btn)
		item_list.add_child(row)
