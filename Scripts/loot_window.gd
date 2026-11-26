extends Panel

const WindowDrag = preload("res://Scripts/window_drag.gd")

# --- LOOT WINDOW ---
# Displays the contents of a loot container (a chest, corpse, etc.). Players
# can take items into their backpack; the GM can add or remove items.

signal close_requested
signal take_requested(item_id: String)
signal add_item_requested(item_name: String, item_desc: String, quantity: int)
signal unmark_requested

@onready var title_label = $TitleLabel
@onready var item_list = $ScrollContainer/ItemList
@onready var add_row = $AddRow
@onready var name_input = $AddRow/ItemNameInput
@onready var desc_input = $AddRow/ItemDescInput
@onready var qty_spin = $AddRow/QtySpin
@onready var add_btn = $AddRow/AddItemBtn
@onready var close_btn = $CloseBtn
@onready var unmark_btn = $UnmarkBtn

var container_id: String = ""
var is_gm_view: bool = false

func _ready() -> void:
	WindowDrag.attach(title_label, self)

	close_btn.pressed.connect(func(): close_requested.emit())
	add_btn.pressed.connect(_on_add_pressed)
	unmark_btn.pressed.connect(func(): unmark_requested.emit())

	name_input.text_submitted.connect(func(_text): _on_add_pressed())
	desc_input.text_submitted.connect(func(_text): _on_add_pressed())

func populate(new_container_id: String, container_data: Dictionary, gm_mode: bool) -> void:
	container_id = new_container_id
	is_gm_view = gm_mode

	var display_name = str(container_data.get("name", "Container"))
	title_label.text = "Loot: " + display_name
	add_row.visible = gm_mode
	unmark_btn.visible = gm_mode

	for child in item_list.get_children():
		child.queue_free()

	var items: Array = container_data.get("items", [])
	if items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Empty. Nothing but dust..."
		empty_lbl.modulate = Color(0.8, 0.8, 0.8, 0.7)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_list.add_child(empty_lbl)
		return

	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var text_lbl = Label.new()
		text_lbl.text = str(item.get("name", "Unknown Item"))
		var qty = int(item.get("qty", 1))
		if qty > 1:
			text_lbl.text += " x" + str(qty)

		var desc = str(item.get("desc", ""))
		if desc != "":
			text_lbl.text += " - " + desc

		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

		var take_btn = Button.new()
		take_btn.text = "Remove" if gm_mode else "Take"
		take_btn.modulate = Color(0.85, 0.7, 0.35) if gm_mode else Color(0.55, 0.9, 0.55)

		var item_id = str(item.get("id", ""))
		take_btn.pressed.connect(func(): take_requested.emit(item_id))

		row.add_child(text_lbl)
		row.add_child(take_btn)
		item_list.add_child(row)

func _on_add_pressed() -> void:
	if not is_gm_view:
		return

	var item_name = name_input.text.strip_edges()
	var item_desc = desc_input.text.strip_edges()
	var quantity = max(1, int(qty_spin.value))

	if item_name == "":
		return

	name_input.text = ""
	desc_input.text = ""
	qty_spin.value = 1

	add_item_requested.emit(item_name, item_desc, quantity)
