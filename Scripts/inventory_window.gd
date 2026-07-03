extends Panel

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

# --- DRAGGING VARIABLES ---
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready():
	title_label.gui_input.connect(_on_title_gui_input)
	
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


# --- DRAGGING LOGIC ---
func _on_title_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging! Calculate the exact pixel you grabbed on the window
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			# Stop dragging when you let go
			is_dragging = false
			
	elif event is InputEventMouseMotion and is_dragging:
		# Teleport the window to the mouse, offset by where you grabbed it
		global_position = get_global_mouse_position() - drag_offset
