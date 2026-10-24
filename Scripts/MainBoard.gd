extends Node2D

# --- MODES & TOOLS ---
enum Mode { SELECT, DRAW_WALL, ERASE_WALL, MEASURE }
var current_mode: Mode = Mode.SELECT

enum MeasureShape { LINE, CIRCLE, CONE }
var current_measure_shape: MeasureShape = MeasureShape.LINE

@onready var inv_window = $UILayer/InventoryWindow
@onready var char_sheet_window = $UILayer/CharacterSheetWindow
# --- PLAYER ROSTER VARIABLES ---
@onready var player_container = $UILayer/TabContainer/PlayerListPanel/PlayerContainer
var connected_players: Dictionary = {} # Stores ID -> {name, role}


# --- QUEST DATA ---
var quests: Array = []
var current_map_path: String = ""
var is_loading_game: bool = false

@onready var quest_tracker = $UILayer/CodeQuestTracker
@onready var wall_layer = $WallLayer
@onready var map_layer = $MapLayer/MapSprite
@onready var gm_layer = $GMLayer
@onready var token_layer = $TokenLayer
@onready var darkness = $Darkness

# --- CHAT LOG NODES ---
@onready var chat_log = $UILayer/TabContainer/ChatPanel/VBoxContainer/ScrollContainer/ChatLog
@onready var chat_input = $UILayer/TabContainer/ChatPanel/VBoxContainer/HBoxContainer/ChatInput
@onready var chat_send_btn = $UILayer/TabContainer/ChatPanel/VBoxContainer/HBoxContainer/SendBtn

# --- TURN MANAGEMENT ---
var current_turn_index: int = 0

var currently_viewed_backpack_uuid = ""

# --- SELECTION & DRAGGING VARIABLES ---
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO
var is_drawing_box: bool = false
var is_dragging_tokens: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var selected_tokens: Array = []

# --- WALL DRAWING VARIABLES ---
var is_drawing_wall: bool = false
var wall_start_pos: Vector2 = Vector2.ZERO
var wall_end_pos: Vector2 = Vector2.ZERO

# --- RULER VARIABLES ---
var is_measuring: bool = false
var measure_start_pos: Vector2 = Vector2.ZERO
var measure_end_pos: Vector2 = Vector2.ZERO
var network_measurements: Dictionary = {}
var player_toolbar: PanelContainer

# --- AoE DAMAGE ---
var aoe_dialog: ConfirmationDialog
var aoe_input: SpinBox


# --- DICE ROLLER NODES ---
@onready var dice_count_box = $UILayer/DiceRollPanel/HBoxContainer/CountBox
@onready var dice_sides_box = $UILayer/DiceRollPanel/HBoxContainer/SidesBox
@onready var dice_mod_box = $UILayer/DiceRollPanel/HBoxContainer/ModBox
@onready var dice_result_label = $UILayer/DiceRollPanel/HBoxContainer/ResultLabel
@onready var whisper_check = $UILayer/DiceRollPanel/HBoxContainer/WhisperCheck

# DASHBOARD & INITIATIVE
@onready var gm_dashboard = $UILayer/GMDashboard
@onready var token_list = $UILayer/TabContainer/InitiativeTracker/MarginContainer/VBoxContainer/TokenList
@onready var roll_init_btn = $UILayer/TabContainer/InitiativeTracker/MarginContainer/VBoxContainer/RollInitBtn
@onready var reset_init_btn = $UILayer/TabContainer/InitiativeTracker/MarginContainer/VBoxContainer/ResetInitBtn
@onready var next_turn_btn = $UILayer/TabContainer/InitiativeTracker/MarginContainer/VBoxContainer/NextTurn

@onready var back_menu_btn = $UILayer/BackToMenuBtn

const TOKEN_SCENE = preload("res://Scenes/token.tscn")

func _ready():
	# --- CHAT FIXES ---
	chat_log.text = "" # Wipes the placeholder text
	chat_log.scroll_following = true # Forces the chat to always scroll down
	
	# --- SKILL EDIT SYNC ---
	CampaignManager.token_data_edit_requested.connect(broadcast_token_data_update)

	GameState.gm_mode_changed.connect(_on_gm_mode_changed)
	token_layer.draw.connect(_on_token_layer_draw)
	
	CampaignManager.fast_roll_requested.connect(_on_character_sheet_roll)
	gm_dashboard.rename_scene_requested.connect(_on_gm_dashboard_rename_scene_requested)
	gm_dashboard.scene_switched.connect(_on_gm_dashboard_scene_switched)
	gm_dashboard.create_new_scene_requested.connect(_on_gm_dashboard_create_new_scene_requested)
	gm_dashboard.save_requested.connect(_on_gm_dashboard_save_requested)
	gm_dashboard.load_requested.connect(_on_gm_dashboard_load_requested)
	gm_dashboard.fog_bypass_toggled.connect(_on_fog_bypass_toggled)
	gm_dashboard.spawn_party_requested.connect(_on_gm_dashboard_spawn_party_requested)
	gm_dashboard.measure_shape_changed.connect(func(shape_index):
		current_measure_shape = shape_index as MeasureShape
	)
	
	gm_dashboard.map_scale_changed.connect(_on_dashboard_map_scale_changed)
	
	if not multiplayer.is_server():
		rpc_id(1, "request_board_sync")
		
	NetworkManager.image_received.connect(func(path, type):
		if type == "map":
			_on_gm_dashboard_map_loaded(path)
	)
	
	chat_send_btn.pressed.connect(_on_chat_send_pressed)
	chat_input.text_submitted.connect(func(_text): _on_chat_send_pressed())
	
	# AUTO-SAVE TIMER
	var autosave_timer = Timer.new()
	autosave_timer.wait_time = 5.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(func():
		# Do not autosave if we don't have a path, OR if we are currently loading!
		if multiplayer.is_server() and CampaignManager.current_save_path != "" and not is_loading_game:
			_on_gm_dashboard_save_requested(CampaignManager.current_save_path)
			print("Game Auto-Saved!")
	)
	add_child(autosave_timer)
	
	if back_menu_btn:
		back_menu_btn.pressed.connect(_on_back_menu_pressed)
	
	if next_turn_btn:
		next_turn_btn.pressed.connect(advance_turn)
	
	# --- PLAYER ROSTER SETUP ---
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var my_id = multiplayer.get_unique_id()
	var my_role = "GM" if my_id == 1 else "PLAYER"
	
	# Force the GameState to recognize if we are the admin!
	if GameState.has_method("set_gm_mode"):
		GameState.set_gm_mode(my_id == 1)
	else:
		GameState.is_gm_mode = (my_id == 1)
	
	# Grab the name and UUID we saved from the Supabase Auth / Main Menu!
	var my_name = GameState.player_name
	
	# Safe fetch for an Object instead of a Dictionary
	var my_uuid = GameState.get("player_uuid")
	if my_uuid == null:
		my_uuid = ""
	
	# Fallback: Just in case they left the box blank
	if my_name == "":
		my_name = "GM" if my_id == 1 else "Player_" + str(my_id).left(4)
		
	# Save BOTH the name and the UUID locally
	connected_players[my_id] = {"name": my_name, "role": my_role, "uuid": my_uuid}
	_update_player_list_ui()
	
	if not multiplayer.is_server():
		# Send the UUID along with the name to the GM!
		rpc_id(1, "register_player_with_gm", my_name, my_uuid)
		
	_setup_player_toolbar()
	# This forces the darkness, the GM dashboard, and the GM layer 
	# to perfectly match who you are the exact second the map finishes loading.
	_on_gm_mode_changed(GameState.is_gm_mode)
	
	# Hook up the new Inventory Scene
	inv_window.close_requested.connect(func(): inv_window.visible = false)
	inv_window.add_item_requested.connect(_on_inv_add_item)
	inv_window.delete_item_requested.connect(_on_inv_delete_item)
	
	if not CampaignManager.campaign_data.has("backpacks"):
		CampaignManager.campaign_data["backpacks"] = {}
		
	# If the Main Menu passed a save file path, force the board to load it immediately!
	if CampaignManager.current_save_path != "":
		# We must defer the call until the end of the frame so all UI nodes are fully ready
		call_deferred("_on_gm_dashboard_load_requested", CampaignManager.current_save_path)
		
	_setup_aoe_dialog()


func _get_token_under_mouse(mouse_pos: Vector2):
	var tokens = token_layer.get_children()
	for i in range(tokens.size() - 1, -1, -1):
		var token = tokens[i]
		if token.global_position.distance_to(mouse_pos) < 32.0:
			return token
	return null

func _unhandled_input(event):
	# --- TOOL SHORTCUTS (1, 2, 3, 4) ---
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_1:
			_change_tool_shortcut(Mode.SELECT)
		elif event.keycode == KEY_2 and GameState.is_gm_mode:
			_change_tool_shortcut(Mode.DRAW_WALL)
		elif event.keycode == KEY_3 and GameState.is_gm_mode:
			_change_tool_shortcut(Mode.ERASE_WALL)
		elif event.keycode == KEY_4:
			_change_tool_shortcut(Mode.MEASURE)
	
	if current_mode == Mode.SELECT:
		# WASD MOVEMENT
		if event is InputEventKey and event.pressed and not event.is_echo():
			if selected_tokens.size() > 0:
				var move_dir = Vector2.ZERO
				if event.keycode == KEY_W or event.keycode == KEY_UP: move_dir.y -= 1
				elif event.keycode == KEY_S or event.keycode == KEY_DOWN: move_dir.y += 1
				elif event.keycode == KEY_A or event.keycode == KEY_LEFT: move_dir.x -= 1
				elif event.keycode == KEY_D or event.keycode == KEY_RIGHT: move_dir.x += 1
				
				if move_dir != Vector2.ZERO:
					var grid_size = 64.0
					for token in selected_tokens:
						if GameState.is_gm_mode:
							token.global_position += move_dir * grid_size # GM Teleports
						else:
							token.move_and_collide(move_dir * grid_size)  # Players hit walls!
							
						sync_token_move(token.name, token.global_position)
		# --- BULK HOTKEYS (H & DELETE & Q) ---
		if event is InputEventKey and event.pressed and not event.is_echo() and GameState.is_gm_mode:
			if event.keycode == KEY_H:
				if selected_tokens.is_empty(): return
				
				# Check the first token to decide whether to hide or reveal the whole group
				var target_hidden = not selected_tokens[0].data.get("is_hidden", false)
				for token in selected_tokens:
					if is_instance_valid(token):
						token.data["is_hidden"] = target_hidden
						broadcast_token_data_update(token.name, "is_hidden", target_hidden)
						token.modulate = Color(1.5, 1.5, 1.5, 0.4) if target_hidden else Color(1.5, 1.5, 1.5, 1.0)
						
			elif event.keycode == KEY_DELETE: 
				# .duplicate() prevents the loop from skipping items as they are deleted!
				for token in selected_tokens.duplicate():
					if is_instance_valid(token):
						delete_token_networked(token.name)
				selected_tokens.clear()
				
			elif event.keycode == KEY_Q:
				if selected_tokens.is_empty(): return
				
				# Pop open the dynamic window and put the mouse cursor inside the number box
				aoe_dialog.popup_centered()
				aoe_input.grab_focus()
		# Press 'N' to force the turn to advance
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_N:
				advance_turn()

		# --- PING THE MAP (Alt + Left Click) ---
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.is_key_pressed(KEY_ALT):
				var pos = get_global_mouse_position()
				var hex = "#ffd700" if GameState.is_gm_mode else GameState.player_color_hex
			
				# Beam the ping to everyone, and draw it locally too!
				rpc("receive_ping", pos, hex)
				receive_ping(pos, hex)
			
				# Stop the click from accidentally selecting a token underneath the mouse
				get_viewport().set_input_as_handled() 
				return

		# MOUSE CLICKS
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked_token = _get_token_under_mouse(get_global_mouse_position())
				if clicked_token:
					# --- STRICT OWNERSHIP CHECK ---
					var my_name = GameState.player_name
					var owner_name = str(clicked_token.data.get("owner_id", "GM"))
					
					if not GameState.is_gm_mode and my_name != owner_name:
						print("You do not have permission to touch this token!")
						return
						
					# --- FIXED: SHIFT-CLICK LOGIC ADDED HERE ---
					var is_holding_shift = Input.is_key_pressed(KEY_SHIFT)
					
					if not is_holding_shift and not clicked_token in selected_tokens:
						_clear_selection()
						
					if not clicked_token in selected_tokens:
						selected_tokens.append(clicked_token)
						if clicked_token.has_method("set_selected"):
							clicked_token.set_selected(true)
							
						clicked_token.modulate = Color(1.5, 1.5, 1.5) # Glow!
						
					is_dragging_tokens = true
					last_mouse_pos = get_global_mouse_position()
				else:
					is_drawing_box = true
					drag_start = get_global_mouse_position()
					drag_end = drag_start
			else:
				if is_drawing_box:
					is_drawing_box = false
					_select_tokens_in_box()
				
				if is_dragging_tokens:
					is_dragging_tokens = false
					for token in selected_tokens:
						if GameState.is_gm_mode:
							token.global_position = get_snapped_center(token.global_position)
						else:
							var target_snap = get_snapped_center(token.global_position)
							var snap_offset = target_snap - token.global_position
							token.move_and_collide(snap_offset)
							
						sync_token_move(token.name, token.global_position)
		
		elif event is InputEventMouseMotion:
			if is_drawing_box:
				drag_end = get_global_mouse_position()
				token_layer.queue_redraw()
			elif is_dragging_tokens:
				var current_mouse = get_global_mouse_position()
				var drag_offset = current_mouse - last_mouse_pos
				
				for token in selected_tokens:
					if GameState.is_gm_mode:
						token.global_position += drag_offset # GM ignores walls
					else:
						token.move_and_collide(drag_offset)  # Players slide against walls
						
					sync_token_move(token.name, token.global_position)
					
				last_mouse_pos = current_mouse

	elif current_mode == Mode.DRAW_WALL:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_drawing_wall = true
					wall_start_pos = get_global_mouse_position()
					wall_end_pos = wall_start_pos
				else:
					if is_drawing_wall:
						broadcast_wall_spawn(wall_start_pos, wall_end_pos)
						is_drawing_wall = false
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				is_drawing_wall = false
			queue_redraw()
		elif event is InputEventMouseMotion and is_drawing_wall:
			wall_end_pos = get_global_mouse_position()
			queue_redraw()

	elif current_mode == Mode.ERASE_WALL:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var wall_to_delete = _get_wall_under_mouse(get_global_mouse_position())
			if wall_to_delete:
					# Grab the coordinates before we destroy it!
				var w_start = wall_to_delete.points[0]
				var w_end = wall_to_delete.points[1]
				wall_to_delete.queue_free()
				broadcast_wall_erase(w_start, w_end)

	elif current_mode == Mode.MEASURE:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_measuring = true
					measure_start_pos = get_snapped_center(get_global_mouse_position())
					measure_end_pos = measure_start_pos
					_sync_local_measurement() # Відправляємо початок вимірювання
				else:
					is_measuring = false
					_clear_local_measurement() # Видаляємо лінійку, коли відпустили мишку
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				is_measuring = false
				_clear_local_measurement()
			token_layer.queue_redraw()
			
		elif event is InputEventMouseMotion and is_measuring:
			measure_end_pos = get_snapped_center(get_global_mouse_position())
			_sync_local_measurement() # Оновлюємо лінійку для всіх під час руху мишки!
			token_layer.queue_redraw()


func _change_tool_shortcut(new_mode: int):
	# Don't try to change the tool manually here. 
	# Just tell the dashboard to press the button, and let the dashboard handle the rest naturally!
	if gm_dashboard and gm_dashboard.has_method("select_tool_by_index"):
		gm_dashboard.select_tool_by_index(new_mode)

func _clear_selection():
	for token in selected_tokens:
		if is_instance_valid(token):
			if token.has_method("set_selected"): token.set_selected(false)
			
			# Restore normal color, but keep it translucent if it was hidden!
			if token.get("data") and token.data.get("is_hidden", false):
				token.modulate = Color(1, 1, 1, 0.4) 
			else:
				token.modulate = Color.WHITE
	selected_tokens.clear()

func _select_tokens_in_box():
	var selection_rect = Rect2(drag_start, drag_end - drag_start).abs()
	var is_holding_shift = Input.is_key_pressed(KEY_SHIFT)
	
	# If the GM isn't holding shift, wipe the old selection before boxing new ones
	if not is_holding_shift:
		_clear_selection()
		
	for token in token_layer.get_children():
		if selection_rect.has_point(token.global_position):
			if not token in selected_tokens:
				selected_tokens.append(token)
				if token.has_method("set_selected"): token.set_selected(true)
				
				# Make the token glow so the GM knows it's grabbed
				token.modulate = Color(1.5, 1.5, 1.5)


func _on_token_layer_draw():
	if is_drawing_box:
		var rect = Rect2(drag_start, drag_end - drag_start).abs()
		token_layer.draw_rect(rect, Color(0.2, 0.5, 1.0, 0.3), true)
		token_layer.draw_rect(rect, Color(0.2, 0.5, 1.0, 0.8), false, 2.0)
		
	if is_drawing_wall:
		token_layer.draw_line(wall_start_pos, wall_end_pos, Color.RED, 4.0)
		
	# --- DRAW NETWORK MEASUREMENTS (Інші гравці) ---
	for peer_id in network_measurements.keys():
		var data = network_measurements[peer_id]
		_draw_ruler_shape(data["start"], data["end"], data["shape"], Color(data["color"]))
		
	# --- DRAW LOCAL MEASUREMENT (Ваша лінійка) ---
	if is_measuring:
		var local_color = Color("#ffd700") if GameState.is_gm_mode else Color(GameState.player_color_hex)
		_draw_ruler_shape(measure_start_pos, measure_end_pos, int(current_measure_shape), local_color)

# --- ДОПОМІЖНА ФУНКЦІЯ МАЛЮВАННЯ ФІГУР ---
func _draw_ruler_shape(start: Vector2, end: Vector2, shape: int, base_color: Color):
	var grid_size = 64.0
	var raw_distance = start.distance_to(end)
	var pixel_distance = round(raw_distance / grid_size) * grid_size
	
	if pixel_distance < grid_size and raw_distance > 10.0:
		pixel_distance = grid_size
		
	var fill_color = base_color
	fill_color.a = 0.3 # Напівпрозора заливка
	var line_color = base_color
	line_color.a = 0.9 # Яскрава лінія
	
	if shape == MeasureShape.LINE:
		token_layer.draw_line(start, end, line_color, 6.0)
		
	elif shape == MeasureShape.CIRCLE:
		token_layer.draw_circle(start, pixel_distance, fill_color)
		token_layer.draw_arc(start, pixel_distance, 0, TAU, 64, line_color, 4.0)
		
	elif shape == MeasureShape.CONE:
		var angle = start.angle_to_point(end)
		var cone_angle = deg_to_rad(53.13) 
		var p1 = start + Vector2(cos(angle - cone_angle/2.0), sin(angle - cone_angle/2.0)) * pixel_distance
		var p2 = start + Vector2(cos(angle + cone_angle/2.0), sin(angle + cone_angle/2.0)) * pixel_distance
		var points = PackedVector2Array([start, p1, p2])
		
		token_layer.draw_polygon(points, PackedColorArray([fill_color, fill_color, fill_color]))
		token_layer.draw_polyline(PackedVector2Array([start, p1, p2, start]), line_color, 4.0)

	# МАЛЮЄМО ТЕКСТ ДИСТАНЦІЇ
	var feet_distance = (pixel_distance / grid_size) * 5.0
	var distance_text = str(round(feet_distance)) + " ft."
	var text_pos = end
	if shape == MeasureShape.LINE:
		text_pos = (start + end) / 2.0
		
	var font = ThemeDB.fallback_font
	token_layer.draw_string(font, text_pos + Vector2(2, 22), distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.BLACK)
	token_layer.draw_string(font, text_pos + Vector2(0, 20), distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)

func _spawn_permanent_wall(start: Vector2, end: Vector2):
	if start.distance_to(end) < 5.0: return
	var new_wall = Line2D.new()
	new_wall.add_point(start)
	new_wall.add_point(end)
	new_wall.default_color = Color(0.8, 0.1, 0.1, 0.8)
	new_wall.width = 5.0
	
	var static_body = StaticBody2D.new()
	var collision_shape = CollisionShape2D.new()
	var segment = SegmentShape2D.new()
	segment.a = start
	segment.b = end
	collision_shape.shape = segment
	static_body.add_child(collision_shape)
	new_wall.add_child(static_body)
	
	var occluder = LightOccluder2D.new()
	var poly = OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([start, end])
	poly.closed = false
	occluder.occluder = poly
	new_wall.add_child(occluder)
	wall_layer.add_child(new_wall)

func _on_roll_init_btn_pressed():
	if not multiplayer.is_server(): return
	
	var all_tokens = $TokenLayer.get_children()
	
	for token in all_tokens:
		if "data" in token:
			var faction = str(token.data.get("faction", "neutral")).to_lower()
			var current = int(token.data.get("current_init", 0))
			
			# Кидаємо кубик ТІЛЬКИ якщо це ворог, або якщо ініціатива ще 0
			if faction == "enemy" or current == 0:
				var roll = randi_range(1, 20)
				var total = roll + int(token.data.get("init_bonus", 0))
				
				# Захист від нескінченного циклу: якщо гравець викинув рівно 0, 
				# робимо його -1, щоб система знала, що він ВЖЕ кидав кубик!
				if total == 0: total = -1
				
				token.data["current_init"] = total
				
				if token.has_method("update_data"):
					token.update_data("current_init", total, true)
					
	_refresh_and_sync_initiative()
	

func _sort_highest_init(a, b):
	# Safely fallback to 0 if the data is somehow missing so the game doesn't crash
	return int(a.data.get("current_init", 0)) > int(b.data.get("current_init", 0))

func _on_reset_init_btn_pressed() -> void:
	if not multiplayer.is_server(): return 
	
	for token in $TokenLayer.get_children():
		if "data" in token: 
			# Повертаємо всіх до 0 (що означає "ще не кидали")
			token.data["current_init"] = 0
			if token.has_method("update_data"): 
				token.update_data("current_init", 0, true)
			
	for child in token_list.get_children(): child.queue_free()
	current_turn_index = 0
	
	rpc("receive_initiative_sync", [])

func _populate_initiative_ui(sorted_tokens: Array):
	for child in token_list.get_children(): child.queue_free()
	for token in sorted_tokens:
		var row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = token.data.get("name", "Unknown")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var score_label = Label.new()
		score_label.text = str(token.data.get("current_init", 0))
		
		if token.data.get("faction", "neutral") == "enemy":
			name_label.modulate = Color.RED
			score_label.modulate = Color.RED
			
		row.add_child(name_label)
		row.add_child(score_label)
		token_list.add_child(row)

func _refresh_and_sync_initiative():
	var all_tokens = $TokenLayer.get_children()
	var active_tokens = []
	
	for token in all_tokens:
		if "data" in token:
			# Додаємо у список ходів ТІЛЬКИ тих, чия ініціатива не дорівнює 0
			var current = int(token.data.get("current_init", 0))
			if current != 0:
				active_tokens.append(token)
			
	active_tokens.sort_custom(_sort_highest_init)
	
	_populate_initiative_ui(active_tokens)
	
	var sync_data = []
	for t in active_tokens:
		sync_data.append({
			"name": t.data["name"],
			"init": t.data["current_init"],
			"faction": t.data.get("faction", "neutral")
		})
		
	rpc("receive_initiative_sync", sync_data)
	_highlight_active_initiative_ui()




func _on_back_menu_pressed():
	# 1. Force a final auto-save if you are the Host
	if multiplayer.is_server() and CampaignManager.current_save_path != "":
		_on_gm_dashboard_save_requested(CampaignManager.current_save_path)
		
	# 2. Safely close the network connection so ports don't get stuck
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		
	# 3. Change to your Main Menu scene! 
	# (Update this string to the exact path of your Main Menu scene)
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")

func _on_gm_mode_changed(is_gm: bool):
	# 1. Show the GM their secret tools
	gm_layer.visible = is_gm
	if gm_dashboard:
		gm_dashboard.visible = is_gm
		
	# 2. Hide Initiative controls from players
	if roll_init_btn: roll_init_btn.visible = is_gm
	if reset_init_btn: reset_init_btn.visible = is_gm
	
	if player_toolbar:
		player_toolbar.visible = not is_gm
	
	# 4. THE FIX: Everyone starts in the dark! 
	# The GM can manually turn the lights on using their Fog toggle switch.
	darkness.visible = true

func _on_fog_bypass_toggled(is_bypassed: bool) -> void:
	# Assuming your fog drawing layer is called "FogLayer" or similar. 
	# (Change the name below if your fog node is named differently!)
	if is_bypassed:
		$Darkness.visible = false
	else:
		$Darkness.visible = true

func add_token_to_board(token_node):
	token_layer.add_child(token_node)

func _get_safe_drop_position(start_pos: Vector2) -> Vector2:
	var grid_size = 64.0
	
	# A search pattern: Center, Right, Left, Down, Up, and Corners
	var search_pattern = [
		Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
		Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1),
		Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)
	]
	
	for offset in search_pattern:
		var test_pos = start_pos + (offset * grid_size)
		var is_occupied = false
		
		# Check if any token is already sitting at this exact spot
		for token in token_layer.get_children():
			if token.global_position.distance_to(test_pos) < 10.0:
				is_occupied = true
				break
				
		# If we found an empty square, return it immediately!
		if not is_occupied:
			return test_pos
			
	# Fallback if the board is completely packed
	return start_pos + (Vector2.RIGHT * grid_size)



func _on_gm_dashboard_spawn_token_requested(image_path: String, y_offset: float, is_enemy_flag: bool) -> void:
	if not multiplayer.is_server(): return
	var unique_id = "Token_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)
	
	NetworkManager.send_image_to_all(image_path, "token")
	
	_local_spawn_token(image_path, y_offset, is_enemy_flag, $GMCamera.global_position, unique_id)
	
	# Give the image 0.5 seconds to transfer before telling the clients to spawn it!
	await get_tree().create_timer(0.5).timeout
	rpc("receive_spawn_token", image_path, y_offset, is_enemy_flag, $GMCamera.global_position, unique_id)

func _local_spawn_token(img: String, offset: float, is_enemy: bool, pos: Vector2, token_id: String):
	var new_token = TOKEN_SCENE.instantiate()
	new_token.name = token_id
	new_token.art_path = img
	new_token.height_offset = offset
	new_token.data["faction"] = "enemy" if is_enemy else "neutral"
	token_layer.add_child(new_token)
	new_token.global_position = pos

@rpc("authority", "call_remote", "reliable")
func receive_spawn_token(img: String, offset: float, is_enemy: bool, pos: Vector2, token_id: String):
	_local_spawn_token(img, offset, is_enemy, pos, token_id)

func _on_gm_dashboard_map_scale_changed(new_scale: float):
	if map_layer:
		map_layer.scale = Vector2(new_scale, new_scale)
		if map_layer.texture:
			var original_size = map_layer.texture.get_size()
			var scaled_size = original_size * new_scale
			var grid_node = $MapLayer/GridOverlay
			if grid_node: grid_node.update_grid(scaled_size)

func _on_gm_dashboard_map_loaded(file_path: String):
	if multiplayer.is_server():
		NetworkManager.send_image_to_all(file_path, "map")
		
	current_map_path = file_path
	var image = Image.load_from_file(file_path)
	
	if image:
		var tex = ImageTexture.create_from_image(image)
		
		# 1. Apply the texture to the actual SPRITE node, not the layer!
		var map_sprite = get_node_or_null("MapLayer/MapSprite")
		if map_sprite:
			map_sprite.texture = tex
			
		# 2. Update the Grid Overlay
		var grid_node = get_node_or_null("MapLayer/GridOverlay")
		if grid_node and grid_node.has_method("update_grid"): 
			grid_node.update_grid(tex.get_size())
			
		# 3. APPLY THE SCALE LAST!
		# Doing this after the image loads guarantees the grid and visuals align.
		var current_map_scale = CampaignManager.campaign_data.get("map_scale", 1.0)
		receive_map_scale_sync(current_map_scale)
		
	else:
		push_error("Failed to load map: " + file_path)

func _on_gm_dashboard_tool_mode_changed(mode_index: int) -> void:
	current_mode = mode_index as Mode
	is_drawing_wall = false
	
	_clear_selection()
	is_dragging_tokens = false
	is_drawing_box = false
	
	queue_redraw()
	if token_layer:
		token_layer.queue_redraw()

func _get_wall_under_mouse(mouse_pos: Vector2) -> Node2D:
	var best_wall = null
	var min_dist = 15.0
	for wall in wall_layer.get_children():
		if wall is Line2D and wall.points.size() >= 2:
			var closest_point = Geometry2D.get_closest_point_to_segment(mouse_pos, wall.points[0], wall.points[1])
			var dist = mouse_pos.distance_to(closest_point)
			if dist < min_dist:
				min_dist = dist
				best_wall = wall
	return best_wall

func get_snapped_center(pos: Vector2) -> Vector2:
	var grid_size = 64.0
	var snapped_x = floor(pos.x / grid_size) * grid_size
	var snapped_y = floor(pos.y / grid_size) * grid_size
	var center_offset = grid_size / 2.0
	return Vector2(snapped_x + center_offset, snapped_y + center_offset)

func _on_roll_btn_pressed() -> void:
	var count = int(dice_count_box.value)
	var sides = int(dice_sides_box.value)
	var modifier = int(dice_mod_box.value)
	var is_secret = whisper_check.button_pressed
	
	var total_sum = 0
	var individual_rolls = []
	for i in range(count):
		var roll = randi_range(1, sides)
		individual_rolls.append(roll)
		total_sum += roll
		
	var final_total = total_sum + modifier
	var breakdown_text = str(individual_rolls)
	if modifier > 0: breakdown_text += " + " + str(modifier)
	elif modifier < 0: breakdown_text += " " + str(modifier)
	breakdown_text += " = " + str(final_total)
	
	var my_name = GameState.player_name
	
	if is_secret:
		# Format a sneaky purple message
		var secret_msg = "[color=#b266ff][i][Secret Roll] %s rolled: %s[/i][/color]\n" % [my_name, breakdown_text]
		
		# 1. Print it locally so we can see what we rolled
		chat_log.append_text(secret_msg)
		
		# 2. If a Player rolled a secret check, whisper it to the GM!
		if not multiplayer.is_server():
			rpc_id(1, "receive_whisper", secret_msg)
	else:
		# If it's a public roll, just send it through the normal chat system!
		var public_msg = "rolled dice: " + breakdown_text
		var color = "#ffd700" if GameState.is_gm_mode else "#99ccff"
		rpc("receive_chat_message", my_name, public_msg, color)


func _on_gm_dashboard_save_requested(path: String):
	_save_pcs_to_vault() # <--- Backup players before saving!
	
	var current_scene_id = CampaignManager.campaign_data["active_scene_id"]
	var scene_data = {
		"map_image_path": current_map_path, "map_scale": gm_dashboard.map_scale_spin_box.value,
		"tokens": [], "walls": []
	}
	for token in token_layer.get_children():
		if "data" in token:
			scene_data["tokens"].append({
				"name": token.name,
				"x": token.global_position.x, "y": token.global_position.y,
				"art_path": token.art_path, "height_offset": token.height_offset, "data": token.data
			})
	for wall in wall_layer.get_children():
		if wall is Line2D and wall.points.size() >= 2:
			scene_data["walls"].append({"start_x": wall.points[0].x, "start_y": wall.points[0].y, "end_x": wall.points[1].x, "end_y": wall.points[1].y})

	CampaignManager.campaign_data["scenes"][current_scene_id] = scene_data
	
	
	var json_string = JSON.stringify(CampaignManager.campaign_data, "\t")
	if json_string == "":
		print("Save Aborted: JSON was empty.")
		return
		
	# 1. Save to a temporary file first!
	var temp_path = path + ".tmp"
	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	
	if temp_file:
		temp_file.store_string(json_string)
		temp_file.close()
		
		# 2. If the temporary file succeeded, safely replace the real file!
		DirAccess.remove_absolute(path) # Delete the old save
		DirAccess.rename_absolute(temp_path, path) # Rename .tmp to .json
		
		CampaignManager.current_save_path = path

func _on_gm_dashboard_load_requested(path: String):
	is_loading_game = true
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	# 1. Grab the text from the file
	var text_data = file.get_as_text()
	
	# 2. IMMEDIATELY close the file lock so autosaves can use it!
	file.close() 
	
	# 3. Parse the text we safely grabbed
	var loaded_data = JSON.parse_string(text_data)
	if typeof(loaded_data) != TYPE_DICTIONARY or not loaded_data.has("active_scene_id"): return
	CampaignManager.campaign_data = loaded_data
	CampaignManager.current_save_path = path
	
	if not CampaignManager.campaign_data.has("backpacks"):
		CampaignManager.campaign_data["backpacks"] = {}
	if not CampaignManager.campaign_data.has("pc_vault"):
		CampaignManager.campaign_data["pc_vault"] = {}
		
	gm_dashboard.refresh_scene_dropdown()
		
	for token in token_layer.get_children(): token.queue_free()
	for wall in wall_layer.get_children(): wall.queue_free()
	selected_tokens.clear()
	
	var active_scene = CampaignManager.campaign_data["active_scene_id"]
	var scene_data = CampaignManager.campaign_data["scenes"][active_scene]
	if scene_data.get("map_image_path", "") != "":
		_on_gm_dashboard_map_loaded(scene_data["map_image_path"])
		var loaded_scale = scene_data.get("map_scale", 1.0)
		gm_dashboard.map_scale_spin_box.value = loaded_scale
		_on_gm_dashboard_map_scale_changed(loaded_scale)
	else:
		map_layer.texture = null
		current_map_path = ""
		
	for t_data in scene_data.get("tokens", []):
		var new_token = TOKEN_SCENE.instantiate()
		if t_data.has("name"): new_token.name = t_data["name"]
		new_token.art_path = t_data["art_path"]
		new_token.height_offset = t_data["height_offset"]
		new_token.data = t_data["data"].duplicate()
		token_layer.add_child(new_token)
		new_token.global_position = Vector2(t_data["x"], t_data["y"])
		
	for w_data in scene_data.get("walls", []):
		_spawn_permanent_wall(Vector2(w_data["start_x"], w_data["start_y"]), Vector2(w_data["end_x"], w_data["end_y"]))
		
	if CampaignManager.campaign_data.has("quests"):
		get_tree().call_group("quest_ui", "refresh_quests")
		
	# Sync the loaded fog state to the players
	if CampaignManager.campaign_data.has("fog"):
		rpc("receive_fog_update", CampaignManager.campaign_data["fog"])
		
	# If we are the GM, tell all currently connected players to reload their boards!
	if multiplayer.is_server():
		var global_quests = CampaignManager.campaign_data.get("quests", [])
		
		# Force every player to wipe their board and load this newly unpacked data!
		rpc("receive_board_sync", active_scene, scene_data, global_quests)
		
	# Update the Party UI tab on the dashboard!
	if gm_dashboard.has_method("refresh_party_ui"):
		gm_dashboard.refresh_party_ui()
		
	print("Campaign fully loaded and broadcasted to players from: ", path)

# --- MULTI-SCENE LOGIC ---
func _on_gm_dashboard_scene_switched(new_scene_id: String):
	var old_scene_id = CampaignManager.campaign_data["active_scene_id"]
	if old_scene_id == new_scene_id: return
	
	_save_pcs_to_vault()
	
	var scene_data = {
		"map_image_path": current_map_path, "map_scale": gm_dashboard.map_scale_spin_box.value,
		"tokens": [], "walls": []
	}
	for token in token_layer.get_children():
		if "data" in token:
			scene_data["tokens"].append({
				"name": token.name,
				"x": token.global_position.x, "y": token.global_position.y,
				"art_path": token.art_path, "height_offset": token.height_offset, "data": token.data
			})
	for wall in wall_layer.get_children():
		if wall is Line2D and wall.points.size() >= 2:
			scene_data["walls"].append({"start_x": wall.points[0].x, "start_y": wall.points[0].y, "end_x": wall.points[1].x, "end_y": wall.points[1].y})
			
	CampaignManager.campaign_data["scenes"][old_scene_id] = scene_data
	
	for token in token_layer.get_children(): token.queue_free()
	for wall in wall_layer.get_children(): wall.queue_free()
	selected_tokens.clear()
	
	CampaignManager.campaign_data["active_scene_id"] = new_scene_id
	var new_scene_data = CampaignManager.campaign_data["scenes"][new_scene_id]
	
	if new_scene_data.get("map_image_path", "") != "":
		_on_gm_dashboard_map_loaded(new_scene_data["map_image_path"])
		var loaded_scale = new_scene_data.get("map_scale", 1.0)
		gm_dashboard.map_scale_spin_box.value = loaded_scale
		_on_gm_dashboard_map_scale_changed(loaded_scale)
	else:
		map_layer.texture = null
		current_map_path = ""
		
	for t_data in new_scene_data.get("tokens", []):
		var new_token = TOKEN_SCENE.instantiate()
		if t_data.has("name"): new_token.name = t_data["name"]
		new_token.art_path = t_data["art_path"]
		new_token.height_offset = t_data["height_offset"]
		new_token.data = t_data["data"].duplicate()
		token_layer.add_child(new_token)
		new_token.global_position = Vector2(t_data["x"], t_data["y"])
		
	for w_data in new_scene_data.get("walls", []):
		_spawn_permanent_wall(Vector2(w_data["start_x"], w_data["start_y"]), Vector2(w_data["end_x"], w_data["end_y"]))

	# SEAMLESS SCENE SWITCH BROADCAST
	if multiplayer.is_server():
		var global_quests = CampaignManager.campaign_data.get("quests", [])
		rpc("receive_board_sync", new_scene_id, new_scene_data, global_quests)

func _on_gm_dashboard_create_new_scene_requested():
	var scene_count = CampaignManager.campaign_data["scenes"].size() + 1
	var new_id = "map_" + str(scene_count)
	CampaignManager.campaign_data["scenes"][new_id] = {"map_image_path": "", "map_scale": 1.0, "tokens": [], "walls": []}
	
	_on_gm_dashboard_scene_switched(new_id) # Switch the engine first
	gm_dashboard.refresh_scene_dropdown() # Then rebuild the UI

func _on_gm_dashboard_rename_scene_requested(new_name: String):
	var old_name = CampaignManager.campaign_data["active_scene_id"]
	if old_name == new_name or CampaignManager.campaign_data["scenes"].has(new_name): return
	var scene_data = CampaignManager.campaign_data["scenes"][old_name]
	CampaignManager.campaign_data["scenes"].erase(old_name)
	CampaignManager.campaign_data["scenes"][new_name] = scene_data
	CampaignManager.campaign_data["active_scene_id"] = new_name
	
	gm_dashboard.refresh_scene_dropdown()

func _on_gm_dashboard_spawn_party_requested():
	# Drop the party exactly where the GM is currently looking!
	spawn_entire_party($GMCamera.global_position)


func _setup_player_toolbar():
	player_toolbar = PanelContainer.new()
	
	# Додаємо трохи простору навколо кнопок
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	player_toolbar.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var tools = [
		{"name": "👆 Select", "mode": Mode.SELECT, "shape": MeasureShape.LINE},
		{"name": "📏 Line", "mode": Mode.MEASURE, "shape": MeasureShape.LINE},
		{"name": "⭕ Circle", "mode": Mode.MEASURE, "shape": MeasureShape.CIRCLE},
		{"name": "📐 Cone", "mode": Mode.MEASURE, "shape": MeasureShape.CONE}
	]
	
	for t in tools:
		var btn = Button.new()
		btn.text = t["name"]
		btn.pressed.connect(func():
			current_mode = t["mode"]
			current_measure_shape = t["shape"]
		)
		hbox.add_child(btn)
		
	$UILayer.add_child(player_toolbar)
	
	# РОЗМІЩУЄМО У ВЕРХНЬОМУ ЛІВОМУ КУТІ (Подалі від квестів)
	player_toolbar.position = Vector2(20, 20)
	player_toolbar.z_index = 50 # Гарантуємо, що вона поверх усього
	
	player_toolbar.visible = not GameState.is_gm_mode


# ==========================================
# NETWORKED RULERS SYSTEM
# ==========================================
func _sync_local_measurement():
	var hex_color = "#ffd700" if GameState.is_gm_mode else GameState.player_color_hex
	# Використовуємо UNRELIABLE, щоб це не викликало лагів при швидкому русі мишки
	rpc("receive_measurement_sync", measure_start_pos, measure_end_pos, int(current_measure_shape), hex_color)

func _clear_local_measurement():
	rpc("receive_measurement_clear")

@rpc("any_peer", "call_remote", "unreliable")
func receive_measurement_sync(start_pos: Vector2, end_pos: Vector2, shape_idx: int, color_hex: String):
	var sender_id = multiplayer.get_remote_sender_id()
	network_measurements[sender_id] = {
		"start": start_pos,
		"end": end_pos,
		"shape": shape_idx,
		"color": color_hex
	}
	if token_layer: token_layer.queue_redraw()

@rpc("any_peer", "call_remote", "reliable")
func receive_measurement_clear():
	var sender_id = multiplayer.get_remote_sender_id()
	if network_measurements.has(sender_id):
		network_measurements.erase(sender_id)
		if token_layer: token_layer.queue_redraw()

# ==========================================
# PC VAULT (PERSISTENT CHARACTERS)
# ==========================================
func _save_pcs_to_vault():
	# Make sure the vault exists in the save file
	if not CampaignManager.campaign_data.has("pc_vault"):
		CampaignManager.campaign_data["pc_vault"] = {}
		
	# Scan the board for any token
	if not token_layer: return
	for token in token_layer.get_children():
		if "data" in token:
			# If the owner is NOT the GM, it is a Player Character! Save their brain!
			if str(token.data.get("owner_id", "GM")) != "GM":
				CampaignManager.campaign_data["pc_vault"][token.data["name"]] = {
					"art_path": token.art_path,
					"height_offset": token.height_offset,
					"data": token.data.duplicate() # Exact copy of HP, Vision, etc.
				}

func spawn_entire_party(drop_pos: Vector2):
	if not multiplayer.is_server(): return
	if not CampaignManager.campaign_data.has("pc_vault"): return
	
	var offset_x = 0
	for pc_name in CampaignManager.campaign_data["pc_vault"].keys():
		var v_data = CampaignManager.campaign_data["pc_vault"][pc_name]
		var unique_id = "Token_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
		
		# Remind players to download the art just in case they are new!
		NetworkManager.send_image_to_all(v_data["art_path"], "token")
		
		# Spawn locally, then tell the network
		_local_spawn_vault_token(v_data, drop_pos + Vector2(offset_x, 0), unique_id)
		
		# Give image time to load
		await get_tree().create_timer(0.5).timeout
		rpc("receive_spawn_vault_token", v_data, drop_pos + Vector2(offset_x, 0), unique_id)
		offset_x += 80 # Space them out so they don't stack on top of each other

func _local_spawn_vault_token(v_data: Dictionary, pos: Vector2, token_id: String):
	var new_token = TOKEN_SCENE.instantiate()
	new_token.name = token_id
	new_token.art_path = v_data.get("art_path", "")
	new_token.height_offset = v_data.get("height_offset", 0.0)
	if v_data.has("data"):
		new_token.data = v_data.get("data").duplicate()
	else:
		# Fallback just in case v_data itself IS the brain dictionary
		new_token.data = v_data.duplicate(true)
		
	token_layer.add_child(new_token)
	new_token.global_position = pos

@rpc("authority", "call_remote", "reliable")
func receive_spawn_vault_token(v_data: Dictionary, pos: Vector2, token_id: String):
	_local_spawn_vault_token(v_data, pos, token_id)

# 1. Spawning a Generic Monster
func spawn_dropped_token(image_path: String, is_enemy: bool, drop_pos: Vector2):
	if not multiplayer.is_server(): return
		
	var unique_id = "Token_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var snapped_pos = _get_safe_drop_position(get_snapped_center(drop_pos))
	
	NetworkManager.send_image_to_all(image_path, "token")
	_local_spawn_token(image_path, 0.0, is_enemy, snapped_pos, unique_id)
	
	# Give the image 0.5 seconds to transfer!
	await get_tree().create_timer(0.5).timeout
	rpc("receive_spawn_token", image_path, 0.0, is_enemy, snapped_pos, unique_id)

# 2. Spawning a Specific Vault Player
func spawn_single_vault_token(pc_name: String, drop_pos: Vector2):
	if not multiplayer.is_server(): return
	if not CampaignManager.campaign_data.has("pc_vault"): return
	
	# Make sure the player actually exists in the vault
	if CampaignManager.campaign_data["pc_vault"].has(pc_name):
		var v_data = CampaignManager.campaign_data["pc_vault"][pc_name]
		var unique_id = "Token_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
		
		var snapped_pos = _get_safe_drop_position(get_snapped_center(drop_pos))
		
		# Beam the art to players, then spawn locally and remotely
		NetworkManager.send_image_to_all(v_data["art_path"], "token")
		
		# Notice we use the _local_spawn_vault_token function here so it injects their saved brain!
		_local_spawn_vault_token(v_data, snapped_pos, unique_id)
		
		# Give the image 0.5 seconds to transfer!
		await get_tree().create_timer(0.5).timeout
		rpc("receive_spawn_vault_token", v_data, snapped_pos, unique_id)
		

# ==========================================
# MULTIPLAYER SYNCING
# ==========================================

# ==========================================
# MAP SCALE NETWORK SYNC
# ==========================================
func _on_dashboard_map_scale_changed(new_scale: float) -> void:
	# Only the GM is allowed to dictate the global map scale!
	if GameState.is_gm_mode:
		rpc("receive_map_scale_sync", new_scale)
		receive_map_scale_sync(new_scale)

@rpc("authority", "call_remote", "reliable")
func receive_map_scale_sync(new_scale: float) -> void:
	# 1. Save it to the universal brain so it saves to the campaign file
	CampaignManager.campaign_data["map_scale"] = new_scale
	
	# 2. Update the Dashboard SpinBox visually for the GM so it stays in sync
	if gm_dashboard and gm_dashboard.map_scale_spin_box:
		gm_dashboard.map_scale_spin_box.set_value_no_signal(new_scale)
	
	# 3. APPLY THE VISUALS (Fixed Path!)
	var map_sprite = get_node_or_null("MapLayer/MapSprite") 
	if map_sprite:
		map_sprite.scale = Vector2(new_scale, new_scale)
		
	# Bonus: If your GridOverlay draws based on the map's scale, 
	# you might need to tell it to redraw here!
	var grid_overlay = get_node_or_null("MapLayer/GridOverlay")
	if grid_overlay and grid_overlay.has_method("queue_redraw"):
		grid_overlay.queue_redraw()


# ==========================================
# FOG SYNCING
# ==========================================
@rpc("authority", "call_remote", "reliable")
func receive_fog_update(new_fog_data: Variant) -> void:
	# Save it to the central brain so it persists on save/load
	CampaignManager.campaign_data["fog"] = new_fog_data
	
	# Force the local fog layer to redraw itself using the new data!
	# (Replace 'fog_layer' and 'update_fog' with your actual node name and drawing function)
	if has_node("FogLayer"):
		$FogLayer.update_fog(new_fog_data)

# ==========================================
# PLAYER ROSTER SYNCING
# ==========================================

func get_uuid_from_name(target_name: String) -> String:
	# Searches the connected players for a matching name and returns their Supabase UUID
	for peer_id in connected_players.keys():
		var p_data = connected_players[peer_id]
		if p_data.get("name", "").to_lower() == target_name.to_lower():
			return p_data.get("uuid", "")
	return ""

# 1. A joining player whispers their name to the GM
@rpc("any_peer", "call_remote", "reliable")
func register_player_with_gm(player_name: String, player_uuid: String = ""):
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Save it to the GM's roster
	connected_players[peer_id] = {"name": player_name, "role": "PLAYER", "uuid": player_uuid}
	_update_player_list_ui()
	
	# Tell everyone else that someone joined (if you have this function)
	rpc("update_roster_for_all", connected_players)

# 2. The GM tells all players exactly who is currently at the table
@rpc("authority", "call_remote", "reliable")
func sync_roster_to_players(master_list: Dictionary):
	# Players overwrite their local list with the GM's perfect master list
	connected_players = master_list
	_update_player_list_ui()
	
	var my_id = multiplayer.get_unique_id()
	if connected_players.has(my_id):
		var my_role = connected_players[my_id]["role"]
		var am_i_a_gm = (my_role == "GM")
		
		# If you are ID 1, you are the Host. The Host is ALWAYS a GM.
		if my_id == 1:
			am_i_a_gm = true
		
		# If our new network role doesn't match our local reality, fix it!
		if GameState.is_gm_mode != am_i_a_gm:
			GameState.set_gm_mode(am_i_a_gm)
			print("My role was updated to: ", my_role)

# 3. If someone closes the game or disconnects, the GM removes them
func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		if connected_players.has(id):
			print(connected_players[id]["name"] + " has left the table.")
			connected_players.erase(id)
			_update_player_list_ui()
			# Broadcast the updated list with the missing player removed
			rpc("sync_roster_to_players", connected_players)

# 4. Redraws the UI Panel whenever the dictionary changes
func _update_player_list_ui():
	if not player_container: return
	
	# Clear the old names out
	for child in player_container.get_children():
		child.queue_free()
		
	# Loop through the dictionary and create a new BUTTON for everyone
	for id in connected_players:
		var data = connected_players[id]
		var btn = Button.new() # <--- Upgraded to Button!
		
		btn.text = data["name"]
		if data["role"] == "GM":
			btn.text += " (GM)"
			btn.modulate = Color(1.0, 0.84, 0.0) # Gold color
		else:
			btn.modulate = Color(0.6, 0.8, 1.0) # Light blue
			
		# Connect the click event so the GM can toggle roles!
		btn.pressed.connect(func(): _on_roster_button_pressed(id))
		
		player_container.add_child(btn)

# 5. Handle clicking a name in the roster
func _on_roster_button_pressed(target_id: int):
	var my_id = multiplayer.get_unique_id()
	
	# Security Check 1: Are WE currently a GM? (Players can't promote people)
	if not connected_players.has(my_id) or connected_players[my_id]["role"] != "GM":
		return
		
	# Security Check 2: Don't let the Host accidentally demote themselves!
	if target_id == 1:
		print("You cannot demote the Host!")
		return
		
	# Tell the Server to officially flip the role!
	if multiplayer.is_server():
		_toggle_player_role(target_id)
	else:
		# If a Co-GM clicked it, they must ask the Host to do it
		rpc_id(1, "request_role_toggle", target_id)

# 6. The actual flip logic (Runs only on the Host)
@rpc("any_peer", "call_remote", "reliable")
func request_role_toggle(target_id: int):
	var sender = multiplayer.get_remote_sender_id()
	# Double check the person asking is actually a Co-GM!
	if connected_players.has(sender) and connected_players[sender]["role"] == "GM":
		_toggle_player_role(target_id)

func _toggle_player_role(target_id: int):
	if connected_players.has(target_id):
		var current_role = connected_players[target_id]["role"]
		
		# Flip it!
		connected_players[target_id]["role"] = "PLAYER" if current_role == "GM" else "GM"
		
		# Update our own GM screen, then shout the new list to the world
		_update_player_list_ui()
		rpc("sync_roster_to_players", connected_players)


func sync_token_move(token_name: String, new_pos: Vector2):
	if multiplayer.is_server():
		rpc("receive_token_move", token_name, new_pos)
	else:
		rpc_id(1, "request_token_move", token_name, new_pos)

@rpc("any_peer", "call_remote", "unreliable")
func request_token_move(token_name: String, new_pos: Vector2):
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		receive_token_move(token_name, new_pos) # Move it for the GM
		
		# Bounce to everyone else EXCEPT the person who just moved it!
		for peer_id in connected_players.keys():
			if peer_id != 1 and peer_id != sender_id:
				rpc_id(peer_id, "receive_token_move", token_name, new_pos)

@rpc("authority", "call_remote", "unreliable")
func receive_token_move(token_name: String, new_pos: Vector2):
	var target_token = token_layer.get_node_or_null(token_name)
	if target_token:
		target_token.global_position = new_pos


@rpc("any_peer", "call_remote", "reliable")
func request_board_sync():
	var requester_id = multiplayer.get_remote_sender_id()
	
	var current_scene_id = CampaignManager.campaign_data["active_scene_id"]
	var live_scene_data = {
		"map_image_path": current_map_path, "map_scale": gm_dashboard.map_scale_spin_box.value,
		"tokens": [], "walls": []
	}
	
	for token in token_layer.get_children():
		if "data" in token:
			live_scene_data["tokens"].append({
				"name": token.name,
				"x": token.global_position.x, "y": token.global_position.y,
				"art_path": token.art_path, "height_offset": token.height_offset, "data": token.data
			})
			
	for wall in wall_layer.get_children():
		if wall is Line2D and wall.points.size() >= 2:
			live_scene_data["walls"].append({"start_x": wall.points[0].x, "start_y": wall.points[0].y, "end_x": wall.points[1].x, "end_y": wall.points[1].y})
		
	CampaignManager.campaign_data["scenes"][current_scene_id] = live_scene_data
	
		
	var global_quests = CampaignManager.campaign_data.get("quests", {})
	rpc_id(requester_id, "receive_board_sync", current_scene_id, live_scene_data, global_quests)

@rpc("authority", "call_remote", "reliable")
func receive_board_sync(scene_id: String, scene_data: Dictionary, quests_data: Dictionary):
	# WIPE GHOST TOWN
	for token in token_layer.get_children(): token.queue_free()
	for wall in wall_layer.get_children(): wall.queue_free()
	selected_tokens.clear()
	
	# MATCH SCENE DROPDOWN
	# Safely update the new custom scene button text instead of the old dropdown
	if gm_dashboard and gm_dashboard.get("scene_select_btn"):
		var display_name = scene_id
		if ":" in scene_id:
			var parts = scene_id.split(":", true, 1)
			display_name = parts[1].strip_edges()
		gm_dashboard.scene_select_btn.text = display_name
	# -----------------------------
	CampaignManager.campaign_data["quests"] = quests_data
	get_tree().call_group("quest_ui", "refresh_quests")
	
	if scene_data.get("map_image_path", "") != "":
		_on_gm_dashboard_map_loaded(scene_data["map_image_path"])
		if scene_data.has("map_scale"):
			var loaded_scale = scene_data["map_scale"]
			if map_layer: map_layer.scale = Vector2(loaded_scale, loaded_scale)
			var grid_node = $MapLayer/GridOverlay
			if grid_node and map_layer.texture: grid_node.update_grid(map_layer.texture.get_size() * loaded_scale)

	for t_data in scene_data.get("tokens", []):
		var new_token = TOKEN_SCENE.instantiate()
		if t_data.has("name"): new_token.name = t_data["name"] # Restore Barcode
		new_token.art_path = t_data["art_path"]
		new_token.height_offset = t_data["height_offset"]
		new_token.data = t_data["data"].duplicate()
		token_layer.add_child(new_token)
		new_token.global_position = Vector2(t_data["x"], t_data["y"])
		
	for w_data in scene_data.get("walls", []):
		_spawn_permanent_wall(Vector2(w_data["start_x"], w_data["start_y"]), Vector2(w_data["end_x"], w_data["end_y"]))

# --- WALL SYNCING ---
func broadcast_wall_spawn(start: Vector2, end: Vector2):
	_spawn_permanent_wall(start, end) # Do it locally first
	if multiplayer.is_server():
		rpc("receive_wall_spawn", start, end)

@rpc("authority", "call_remote", "reliable")
func receive_wall_spawn(start: Vector2, end: Vector2):
	_spawn_permanent_wall(start, end)

func broadcast_wall_erase(start: Vector2, end: Vector2):
	if multiplayer.is_server():
		rpc("receive_wall_erase", start, end)

@rpc("authority", "call_remote", "reliable")
func receive_wall_erase(start: Vector2, end: Vector2):
	# Find the exact wall that matches the coordinates and delete it
	for wall in wall_layer.get_children():
		if wall is Line2D and wall.points.size() >= 2:
			if wall.points[0].is_equal_approx(start) and wall.points[1].is_equal_approx(end):
				wall.queue_free()
				break

# ==========================================
# QUEST SYSTEM HUB
# ==========================================
@rpc("any_peer", "call_remote", "reliable")
func request_update_quest(quest_id: String, quest_data: Dictionary):
	if multiplayer.is_server():
		if not CampaignManager.campaign_data.has("quests"):
			CampaignManager.campaign_data["quests"] = {}
			
		CampaignManager.campaign_data["quests"][quest_id] = quest_data
		
		# Send updated dictionary to all players
		rpc("receive_quests_sync", CampaignManager.campaign_data["quests"])
		receive_quests_sync(CampaignManager.campaign_data["quests"]) # Run locally for GM

@rpc("any_peer", "call_remote", "reliable")
func request_delete_quest(quest_id: String):
	if multiplayer.is_server():
		if CampaignManager.campaign_data.has("quests") and CampaignManager.campaign_data["quests"].has(quest_id):
			CampaignManager.campaign_data["quests"].erase(quest_id)
			
			rpc("receive_quests_sync", CampaignManager.campaign_data["quests"])
			receive_quests_sync(CampaignManager.campaign_data["quests"])

@rpc("authority", "call_remote", "reliable")
func receive_quests_sync(all_quests: Dictionary):
	CampaignManager.campaign_data["quests"] = all_quests
	
	# Instantly updates both the QuestWindow and the Pinned HUD!
	get_tree().call_group("quest_ui", "refresh_quests")

# --- TOKEN DATA SYNCING ---
func broadcast_token_data_update(token_name: String, key: String, new_value: Variant):
	# --- FIX: ALWAYS APPLY LOCALLY FIRST ---
	# This forces the token to run its update_data() immediately 
	# so the local player/GM sees the change (Name/HP/etc) instantly.
	var target_token = token_layer.get_node_or_null(token_name)
	if target_token and target_token.has_method("update_data"):
		target_token.update_data(key, new_value, true)

	# --- GM Auto-Sort Hook ---
	if key in ["current_init", "init_bonus", "initiative"] and multiplayer.is_server():
		_refresh_and_sync_initiative()
		
	# --- NETWORK DISTRIBUTION ---
	if multiplayer.is_server():
		# The GM beams it directly to everyone else
		rpc("receive_token_data_update", token_name, key, new_value)
	else:
		# Players ask the GM's computer to distribute the data
		rpc_id(1, "request_token_data_update", token_name, key, new_value)

# The GM receives the player's request, verifies it, and beams it out
@rpc("any_peer", "call_remote", "reliable")
func request_token_data_update(token_name: String, key: String, new_value: Variant):
	if multiplayer.is_server():
		receive_token_data_update(token_name, key, new_value) # Apply to GM's board
		rpc("receive_token_data_update", token_name, key, new_value) # Beam to other players

@rpc("authority", "call_remote", "reliable")
func receive_token_data_update(token_name: String, key: String, new_value: Variant):
	# Find the token by its unique barcode and update its brain!
	var target_token = token_layer.get_node_or_null(token_name)
	
	# 1. Update the visual token on the board
	if target_token and target_token.has_method("update_data"):
		# We pass "true" so the token knows this came from the internet, preventing infinite loops!
		target_token.update_data(key, new_value, true)
		
		if key in ["current_init", "init_bonus", "initiative"] and multiplayer.is_server():
			_refresh_and_sync_initiative()
			
	# 2. Live-sync the Character Sheet UI if it's currently open
	if char_sheet_window.visible and char_sheet_window.current_token_name == token_name:
		char_sheet_window.local_data[key] = new_value
		char_sheet_window._on_blueprint_updated() 
		
	# --- 3. THE PERSISTENT SAVE ENGINE (SERVER ONLY) ---
	if multiplayer.is_server():
		# A. Save it to the Active Scene so the map remembers it
		var current_scene_id = CampaignManager.campaign_data.get("active_scene_id", "")
		if current_scene_id != "" and CampaignManager.campaign_data["scenes"].has(current_scene_id):
			var scene_tokens = CampaignManager.campaign_data["scenes"][current_scene_id].get("tokens", [])
			for i in range(scene_tokens.size()):
				if scene_tokens[i].get("name") == token_name:
					if not scene_tokens[i].has("data"): scene_tokens[i]["data"] = {}
					scene_tokens[i]["data"][key] = new_value
					break
				
		# B. If this token belongs to a Player, save it to the Global PC Vault!
		if target_token:
			var pc_name = target_token.name
			if target_token.get("data") and target_token.data.has("name"):
				pc_name = target_token.data["name"]
				
			if CampaignManager.campaign_data.has("pc_vault"):
				for vault_pc_key in CampaignManager.campaign_data["pc_vault"].keys():
					if vault_pc_key == pc_name or vault_pc_key in token_name:
						CampaignManager.campaign_data["pc_vault"][vault_pc_key]["data"][key] = new_value
						print("Saved " + key + " to Global PC Vault for: " + vault_pc_key)



# ==========================================
# TOKEN OWNERSHIP & HIDING
# ==========================================

# ==========================================
# BULK AOE DAMAGE SYSTEM
# ==========================================
func _setup_aoe_dialog():
	aoe_dialog = ConfirmationDialog.new()
	aoe_dialog.title = "Bulk AoE Damage"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Enter amount (- for Damage, + for Healing):"
	vbox.add_child(label)
	
	aoe_input = SpinBox.new()
	aoe_input.min_value = -9999
	aoe_input.max_value = 9999
	aoe_input.value = -10 
	aoe_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(aoe_input)
	
	aoe_dialog.add_child(vbox)
	add_child(aoe_dialog)
	
	aoe_dialog.confirmed.connect(_apply_bulk_damage)

func _apply_bulk_damage():
	var amount = int(aoe_input.value)
	if amount == 0: return
	
	var hp_key = "hp" # Match to your template
	
	for token in selected_tokens:
		if is_instance_valid(token) and "data" in token:
			var current_hp = int(token.data.get(hp_key, 0))
			var new_hp = max(0, current_hp + amount)
			
			token.data[hp_key] = new_hp
			broadcast_token_data_update(token.name, hp_key, new_hp)
			
			# USE THE NEW UNIVERSAL HUB!
			broadcast_floating_text(token.name, amount)

# ==========================================
# UNIVERSAL FLOATING TEXT HUB
# ==========================================
func broadcast_floating_text(token_name: String, amount: int):
	# 1. OBEY THE MASTER SWITCH
	if not GameState.show_floating_text: return
	
	# 2. ROUTE THE ANIMATION OVER THE NETWORK
	if multiplayer.is_server():
		receive_floating_text(token_name, amount) # Show on GM screen
		rpc("receive_floating_text", token_name, amount) # Beam to players
	else:
		rpc_id(1, "request_floating_text", token_name, amount) # Ask GM to beam it

@rpc("any_peer", "call_remote", "unreliable")
func request_floating_text(token_name: String, amount: int):
	if multiplayer.is_server():
		receive_floating_text(token_name, amount)
		rpc("receive_floating_text", token_name, amount)

@rpc("any_peer", "call_remote", "unreliable")
func receive_floating_text(token_name: String, amount: int):
	var token = token_layer.get_node_or_null(token_name)
	if not token: return
	
	var float_lbl = Label.new()
	float_lbl.text = str(amount) if amount < 0 else "+" + str(amount)
	
	# Green for healing (+), Red for damage (-)
	var text_color = Color(0.2, 0.8, 0.2) if amount > 0 else Color(0.9, 0.2, 0.2)
	float_lbl.add_theme_color_override("font_color", text_color)
	
	# Thick black outline so it's readable over any map background
	float_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	float_lbl.add_theme_constant_override("outline_size", 8)
	float_lbl.add_theme_font_size_override("font_size", 42)
	
	# Start it just above the token's head
	float_lbl.global_position = token.global_position + Vector2(-20, -50)
	
	# Ensure it draws on top of the tokens
	float_lbl.z_index = 10 
	token_layer.add_child(float_lbl)
	
# --- THE ANIMATION TWEEN ---
	var tween = get_tree().create_tween()
	
	# Float upward 60 pixels (Using EASE_OUT makes it slow down smoothly as it reaches the top)
	tween.tween_property(float_lbl, "global_position", float_lbl.global_position + Vector2(0, -60), 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade to transparent at the same time (Using EASE_IN makes it fade faster at the very end)
	tween.parallel().tween_property(float_lbl, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Destroy the node once the animation finishes
	tween.tween_callback(float_lbl.queue_free)


# --- TOKEN DELETION ---
func delete_token_networked(token_name: String):
	if multiplayer.is_server():
		# The GM deletes it locally, then tells everyone else to do the same
		receive_token_delete(token_name)
		rpc("receive_token_delete", token_name)
	else:
		# Players ask the GM to delete it
		rpc_id(1, "request_token_delete", token_name)

@rpc("any_peer", "call_remote", "reliable")
func request_token_delete(token_name: String):
	if not multiplayer.is_server(): return
	
	# The GM receives the request, deletes it, and broadcasts the wipe
	receive_token_delete(token_name)
	rpc("receive_token_delete", token_name)

@rpc("authority", "call_remote", "reliable")
func receive_token_delete(token_name: String):
	var token = token_layer.get_node_or_null(token_name)
	if token:
		# If the token is currently selected (highlighted), remove it from the array to prevent crashes!
		if token in selected_tokens:
			selected_tokens.erase(token)
			
		token.queue_free()

@rpc("authority", "call_remote", "reliable")
func broadcast_token_owner(token_name: String, new_owner_name: String): # Changed to String
	if multiplayer.is_server():
		rpc("receive_token_owner", token_name, new_owner_name)

@rpc("authority", "call_remote", "reliable")
func receive_token_owner(token_name: String, new_owner_name: String): # Changed to String
	var token = token_layer.get_node_or_null(token_name)
	if token and token.has_method("update_data"):
		token.update_data("owner_id", new_owner_name)

# ==========================================
# MODULAR INVENTORY SYSTEM
# ==========================================

# 1. Triggered by the Token Menu
func open_inventory_window(target_uuid: String, character_name: String):
	currently_viewed_backpack_uuid = target_uuid
	
	if not CampaignManager.campaign_data["backpacks"].has(target_uuid):
		CampaignManager.campaign_data["backpacks"][target_uuid] = []
		
	var items = CampaignManager.campaign_data["backpacks"][target_uuid]
	
	inv_window.populate(character_name, items)
	inv_window.visible = true

# 2. Triggered by the Inventory Window
func _on_inv_add_item(item_name: String, item_desc: String):
	if currently_viewed_backpack_uuid == "": return
	
	var item_id = "item_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var new_item = { "id": item_id, "name": item_name, "desc": item_desc }
	
	if multiplayer.is_server():
		receive_inventory_action("add", currently_viewed_backpack_uuid, new_item)
	else:
		rpc_id(1, "request_inventory_action", "add", currently_viewed_backpack_uuid, new_item)

func _on_inv_delete_item(item_id: String):
	if currently_viewed_backpack_uuid == "": return
	
	if multiplayer.is_server():
		receive_inventory_action("delete", currently_viewed_backpack_uuid, {"id": item_id})
	else:
		rpc_id(1, "request_inventory_action", "delete", currently_viewed_backpack_uuid, {"id": item_id})

# 3. The Network Math
@rpc("any_peer", "call_remote", "reliable")
func request_inventory_action(action: String, target_uuid: String, payload: Dictionary):
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var sender_uuid = connected_players[sender_id]["uuid"] if connected_players[sender_id].has("uuid") else ""
	var sender_is_gm = connected_players[sender_id]["role"] == "GM"
	
	# SECURITY: Players can only edit their own backpack! GM can edit anyone's.
	if not sender_is_gm and target_uuid != sender_uuid:
		print("Security Block: Player tried to edit someone else's inventory!")
		return
		
	receive_inventory_action(action, target_uuid, payload)

func receive_inventory_action(action: String, target_uuid: String, payload: Dictionary):
	if not CampaignManager.campaign_data["backpacks"].has(target_uuid):
		CampaignManager.campaign_data["backpacks"][target_uuid] = []
		
	var backpack = CampaignManager.campaign_data["backpacks"][target_uuid]
	
	if action == "add":
		backpack.append(payload)
	elif action == "delete":
		for i in range(backpack.size() -1, -1, -1):
			if backpack[i]["id"] == payload["id"]:
				backpack.remove_at(i)
				break
				
	rpc("sync_single_backpack", target_uuid, backpack)
	sync_single_backpack(target_uuid, backpack) # Run locally for the GM

@rpc("authority", "call_remote", "reliable")
func sync_single_backpack(target_uuid: String, updated_items: Array):
	CampaignManager.campaign_data["backpacks"][target_uuid] = updated_items
	
	# If I am currently looking at this exact backpack, refresh my screen!
	if inv_window.visible and currently_viewed_backpack_uuid == target_uuid:
		var char_name = inv_window.title_label.text.replace("'s Backpack", "")
		inv_window.populate(char_name, updated_items)

# --- CHARACTER SHEET TRIGGER ---
func open_character_sheet_for_token(token_name: String):
	var token = token_layer.get_node_or_null(token_name)
	if not token: return
	
	# --- ВИПРАВЛЕННЯ: ЗАВЖДИ БРАТИ НАЙСВІЖІШИЙ ШАБЛОН ---
	# Замість того, щоб покладатися на старе збереження, ми примусово 
	# оновлюємо шаблон кампанії найсвіжішою версією з нашого коду.
	# (Якщо у вас є вибір систем, тут можна додати перевірку, яку саме систему завантажувати)
	CampaignManager.campaign_data["sheet_template"] = SheetTemplates.TEMPLATES["dnd_5e"]
	
	# Дублюємо пам'ять токена і вручну додаємо шлях до арту
	var combined_data = token.data.duplicate()
	combined_data["art_path"] = token.art_path
	
	# Передаємо об'єднані дані у генератор аркуша
	char_sheet_window.generate_ui(CampaignManager.campaign_data["sheet_template"], combined_data, token.name)
	
	# Показуємо вікно і виводимо на передній план
	char_sheet_window.visible = true
	
	if char_sheet_window.has_method("move_to_front"):
		char_sheet_window.move_to_front()

# ==========================================
# CHAT AND DICE LOG
# ==========================================

func _on_character_sheet_roll(char_name: String, roll_name: String, modifier: int, dice_logic: String = "d20_high", is_whisper: bool = false) -> void:
	var result_text = ""
	
	# --- 1. D&D 5e MATH (1d20 + Modifier) ---
	if dice_logic == "d20_high":
		var d20 = randi_range(1, 20)
		var total = d20 + modifier
		var sign_str = "+" if modifier >= 0 else ""
		
		result_text = char_name + " rolled " + roll_name + ":\n"
		result_text += "[color=yellow]d20 (" + str(d20) + ") " + sign_str + str(modifier) + " = " + str(total) + "[/color]"

	# --- 2. DELTA GREEN MATH (1d100 Roll Under Target) ---
	elif dice_logic == "d100_under":
		# In DG, the "modifier" passed from the sheet is actually the Target % 
		var d100 = randi_range(1, 100)
		var is_success = d100 <= modifier
		
		var outcome = "[color=green]SUCCESS[/color]" if is_success else "[color=red]FAILURE[/color]"
		
		# Delta Green Criticals (01, or matching dice like 11, 22, 99) and Fumbles (100)
		if d100 == 1 or (d100 <= modifier and d100 % 11 == 0):
			outcome = "[color=gold]CRITICAL SUCCESS![/color]"
		elif d100 == 100 or (d100 > modifier and d100 % 11 == 0):
			outcome = "[color=darkred]FUMBLE![/color]"
			
		result_text = char_name + " rolled " + roll_name + " (Target " + str(modifier) + "%):\n"
		result_text += "Rolled: [color=yellow]" + str(d100) + "[/color] -> " + outcome

	# --- 3. SHINOBIGAMI MATH (2d6 + Modifier) ---
	elif dice_logic == "2d6_high":
		var d1 = randi_range(1, 6)
		var d2 = randi_range(1, 6)
		var total = d1 + d2 + modifier
		var sign_str = ""
		
		if modifier != 0:
			sign_str = ("+" if modifier > 0 else "") + str(modifier)
			
		result_text = char_name + " rolled " + roll_name + ":\n"
		result_text += "[color=yellow]2d6 (" + str(d1) + " + " + str(d2) + ")" + sign_str + " = " + str(total) + "[/color]"
	
	# --- BROADCAST & WHISPER LOGIC ---
	var my_name = GameState.player_name
	if my_name == "": my_name = "GM" if GameState.is_gm_mode else "Player"
	var color = "#ffd700" if GameState.is_gm_mode else "#99ccff" 
	
	# Combine the Character Sheet's whisper flag with the MainBoard's physical UI checkbox
	var actual_is_whisper = is_whisper
	if whisper_check and whisper_check.button_pressed:
		actual_is_whisper = true
	
	if actual_is_whisper:
		# Format a sneaky purple message for secrets!
		var secret_msg = "[color=#b266ff][i](Whisper)[/i]\n" + result_text + "[/color]"
		
		# 1. Print locally so the roller sees their own secret roll
		receive_chat_message(my_name, secret_msg, color)
		
		# 2. If the roller is NOT the GM, safely beam it to the GM's whisper receiver
		if not multiplayer.is_server():
			rpc_id(1, "receive_whisper", secret_msg)
			
	else:
		# --- THE FIX: ROUTE PUBLIC ROLLS THROUGH THE REQUEST PIPELINE ---
		var final_text = "\n" + result_text
		if multiplayer.is_server():
			receive_chat_message(my_name, final_text, color)
			rpc("receive_chat_message", my_name, final_text, color)
		else:
			# Ask the GM to broadcast our roll for us!
			rpc_id(1, "request_chat_message", my_name, final_text, color)
	

func _on_chat_send_pressed():
	var text = chat_input.text.strip_edges()
	if text == "": return
	
	var my_name = GameState.player_name
	var color = "#ffd700" if GameState.is_gm_mode else "#99ccff"
	
	if multiplayer.is_server():
		receive_chat_message(my_name, text, color)
		rpc("receive_chat_message", my_name, text, color)
	else:
		# Ask the GM to broadcast it for us!
		rpc_id(1, "request_chat_message", my_name, text, color)
		
	chat_input.text = ""

@rpc("any_peer", "call_remote", "reliable")
func request_chat_message(sender_name: String, text: String, color_hex: String):
	if multiplayer.is_server():
		receive_chat_message(sender_name, text, color_hex) # Print on GM screen
		rpc("receive_chat_message", sender_name, text, color_hex) # Bounce to players

@rpc("authority", "call_remote", "reliable")
func receive_chat_message(sender_name: String, text: String, color_hex: String):
	var formatted_msg = "[color=%s][b]%s:[/b][/color] %s\n\n" % [color_hex, sender_name, text]
	chat_log.append_text(formatted_msg)
	await get_tree().process_frame 
	chat_log.scroll_to_line(chat_log.get_line_count() - 1)


# For secret rolls, we only send the text directly to the Host (ID 1)
@rpc("any_peer", "call_remote", "reliable")
func receive_whisper(formatted_msg: String):
	chat_log.append_text(formatted_msg)

# ==========================================
# INITIATIVE RECEIVER & TURN TRACKER
# ==========================================

@rpc("authority", "call_remote", "reliable")
func receive_initiative_sync(sync_data: Array):
	# 1. Wipe the old list clean
	for child in token_list.get_children():
		child.queue_free()
		
	# 2. If it's a reset (empty array), stop here and reset the turn counter
	if sync_data.size() == 0:
		current_turn_index = 0
		return
		
	# 3. Rebuild the list perfectly matching the GM's screen
	for item in sync_data:
		var row = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = item["name"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var score_label = Label.new()
		score_label.text = str(item["init"])
		
		# Keep the red styling for enemies!
		if item["faction"] == "enemy":
			name_label.modulate = Color.RED
			score_label.modulate = Color.RED
			
		row.add_child(name_label)
		row.add_child(score_label)
		token_list.add_child(row)
		
	# 4. Highlight whose turn it is on the newly built list!
	_highlight_active_initiative_ui()


# --- TURN MANAGEMENT LOGIC ---

func _highlight_active_initiative_ui():
	var rows = token_list.get_children()
	for i in range(rows.size()):
		var row = rows[i]
		# Give the active row a gold highlight background
		if i == current_turn_index:
			row.modulate = Color(1.5, 1.5, 0.5) # Bright gold highlight!
		else:
			row.modulate = Color.WHITE

func advance_turn():
	if not multiplayer.is_server(): return
	
	var rows = token_list.get_children()
	if rows.size() == 0: return # Nobody has rolled yet
	
	# Move to the next index, looping back to 0 at the end of the list
	current_turn_index = (current_turn_index + 1) % rows.size()
	
	# Broadcast the new turn index to all clients
	rpc("receive_turn_sync", current_turn_index)
	receive_turn_sync(current_turn_index) # Run locally for the GM

@rpc("authority", "call_remote", "reliable")
func receive_turn_sync(new_index: int):
	current_turn_index = new_index
	
	# Highlight the UI
	_highlight_active_initiative_ui()
	
	# Tell all tokens on the board to recalculate their glowing visuals!
	for token in $TokenLayer.get_children():
		if token.has_method("update_visuals"):
			token.update_visuals()

# ==========================================
# PING SYSTEM
# ==========================================
@rpc("any_peer", "call_remote", "unreliable")
func receive_ping(pos: Vector2, color_hex: String):
	# 1. Створюємо UI-панель
	var ping = Panel.new()
	ping.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ping.size = Vector2(100, 100)
	ping.pivot_offset = Vector2(50, 50) # Центруємо для ідеального масштабування
	ping.position = pos - ping.pivot_offset
	ping.z_index = 20 # Малюємо пінг поверх усіх токенів
	
	# 2. Малюємо порожнє кільце за допомогою StyleBoxFlat
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0) # Центр прозорий
	style.border_color = Color(color_hex)
	style.set_border_width_all(8) # Товщина кільця
	# Робимо його ідеально круглим
	style.corner_radius_top_left = 100
	style.corner_radius_top_right = 100
	style.corner_radius_bottom_left = 100
	style.corner_radius_bottom_right = 100
	ping.add_theme_stylebox_override("panel", style)
	
	add_child(ping)
	
	# 3. Анімуємо розширення та зникання!
	var tween = get_tree().create_tween()
	ping.scale = Vector2(0.1, 0.1) # Починаємо з крихітної крапки
	
	# Збільшуємо до 150% розміру та робимо прозорим за 1 секунду
	tween.tween_property(ping, "scale", Vector2(1.5, 1.5), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ping, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Видаляємо об'єкт після завершення, щоб не забивати пам'ять
	tween.tween_callback(ping.queue_free)



# ==========================================
# MINIGAME NETWORK SYSTEM
# ==========================================
func send_minigame_to_player(target_player_name: String, game_index: int, mod1: int, mod2: int):
	# Відправляємо команду всім клієнтам (включно з сервером)
	rpc("receive_minigame_trigger", target_player_name, game_index, mod1, mod2)

@rpc("any_peer", "call_local")
func receive_minigame_trigger(target_name: String, game_index: int, mod1: int, mod2: int):
	# Відкриваємо міні-гру ТІЛЬКИ якщо ви — цільовий гравець, АБО якщо ви — GM
	if GameState.player_name == target_name or GameState.is_gm_mode:
		_spawn_minigame_ui(game_index, mod1, mod2)

func _spawn_minigame_ui(game_index: int, mod1: int, mod2: int):
	var minigame_scene = null
	
	match game_index:
		0: # The Tumbler
			minigame_scene = preload("res://UI/Minigames/TumblerMinigame.tscn").instantiate()
			minigame_scene.initialize(mod1, mod2) # Added mod2!
		1: # Frequency Decoder
			minigame_scene = preload("res://UI/Minigames/FrequencyMinigame.tscn").instantiate()
			minigame_scene.initialize(mod1, mod2) # Added mod2!
		2: # Hex Decoder (WIP)
			minigame_scene = preload("res://UI/Minigames/HexDecoderMinigame.tscn").instantiate()
			minigame_scene.initialize(mod1, mod2)
			
	if minigame_scene == null: return
		
	# Add to the screen
	if has_node("UILayer"):
		$UILayer.add_child(minigame_scene)
	else:
		add_child(minigame_scene)
	
	minigame_scene.set_anchors_preset(Control.PRESET_CENTER)
	
	# GM Preview formatting
	if GameState.is_gm_mode:
		minigame_scene.scale = Vector2(0.6, 0.6) 
		minigame_scene.position = Vector2(20, 50)
