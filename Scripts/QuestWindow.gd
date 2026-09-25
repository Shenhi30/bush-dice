extends PanelContainer # Або Window

@onready var quest_list = $HBoxContainer/LeftColumn/QuestList
@onready var title_input = $HBoxContainer/RightColumn/QuestName
@onready var desc_input = $HBoxContainer/RightColumn/QuestDesc
@onready var pin_toggle = $HBoxContainer/RightColumn/PinCheckBox

@onready var new_btn = $HBoxContainer/LeftColumn/NewQuestBtn
@onready var save_btn = $HBoxContainer/RightColumn/SaveQuestBtn
@onready var delete_btn = $HBoxContainer/RightColumn/DeleteQuestBtn

var active_quest_id: String = ""
var current_quests: Dictionary = {}

func _ready():
	# Додаємо це вікно до групи, щоб MainBoard міг його оновлювати
	add_to_group("quest_ui")
	
	new_btn.pressed.connect(_on_new_quest)
	save_btn.pressed.connect(_on_save_quest)
	delete_btn.pressed.connect(_on_delete_quest)
	quest_list.item_selected.connect(_on_quest_selected)
	
	refresh_quests() # Завантажуємо при відкритті

func refresh_quests():
# 1. Завантажуємо сирі дані у тимчасову змінну (без жорсткого типу)
	var raw_quests = CampaignManager.campaign_data.get("quests", {})
	
	# 2. Якщо це старе збереження (Array), примусово робимо його Dictionary
	if typeof(raw_quests) == TYPE_ARRAY:
		raw_quests = {}
		CampaignManager.campaign_data["quests"] = {}
		
	# 3. Тепер безпечно передаємо чистий Словник у нашу типізовану змінну
	current_quests = raw_quests
	quest_list.clear()
	for q_id in current_quests.keys():
		var q_data = current_quests[q_id]
		var prefix = "📌 " if q_data.get("pinned", false) else ""
		quest_list.add_item(prefix + q_data.get("title", "Unknown Quest"))
		quest_list.set_item_metadata(quest_list.get_item_count() - 1, q_id)

func _on_new_quest():
	active_quest_id = "" # Порожній ID означає створення нового квесту
	title_input.text = "New Quest"
	desc_input.text = ""
	pin_toggle.button_pressed = false
	quest_list.deselect_all()

func _on_quest_selected(index: int):
	active_quest_id = quest_list.get_item_metadata(index)
	var q_data = current_quests[active_quest_id]
	
	title_input.text = q_data.get("title", "")
	desc_input.text = q_data.get("desc", "")
	pin_toggle.button_pressed = q_data.get("pinned", false)

func _on_save_quest():
	# Генеруємо унікальний ID для нових квестів (беремо поточний час)
	if active_quest_id == "":
		active_quest_id = "quest_" + str(Time.get_unix_time_from_system())
		
	var quest_data = {
		"title": title_input.text,
		"desc": desc_input.text,
		"pinned": pin_toggle.button_pressed
	}
	
	var main_board = get_tree().root.find_child("MainBoard", true, false)
	if main_board:
		main_board.rpc_id(1, "request_update_quest", active_quest_id, quest_data)
		if multiplayer.is_server(): # Якщо GM натиснув зберегти
			main_board.request_update_quest(active_quest_id, quest_data)

func _on_delete_quest():
	if active_quest_id == "": return
	
	var main_board = get_tree().root.find_child("MainBoard", true, false)
	if main_board:
		main_board.rpc_id(1, "request_delete_quest", active_quest_id)
		if multiplayer.is_server():
			main_board.request_delete_quest(active_quest_id)
			
	_on_new_quest() # Очищуємо поля після видалення
