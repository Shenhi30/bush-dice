extends PanelContainer

@onready var timer_bar = $MarginContainer/VBoxContainer/TimerBar
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var target_label = $MarginContainer/VBoxContainer/TargetSequenceLabel
@onready var attempt_label = $MarginContainer/VBoxContainer/AttemptSequenceLabel
@onready var word_grid = $MarginContainer/VBoxContainer/CenterContainer/WordGrid

var time_left: float = 30.0
var minigame_active: bool = true

var target_sequence = []
var current_attempt = []
var max_words: int = 0

# Cyberpunk selection trackers
var is_row_selection: bool = true 
var active_line_index: int = 0    
var clicked_buttons = []          

var stat_mod_cache: int = 2
var time_limit_cache: int = 30
var initialized_from_code: bool = false

var word_pool = [
	"BOOT", "BYTE", "BASE", "BURN", "BAIT", "BASH", "BIND", "BULK",
	"CORE", "CODE", "CHIP", "CLIP", "COLD", "CALL", "CAST", "CELL",
	"DATA", "DUMP", "DOCK", "DECK", "DASH", "DATE", "DEAD", "DROP",
	"ECHO", "EXEC", "EXIT", "EDGE", "EVIL", "EDIT", "EMIT", "EAST",
	"FILE", "FIRE", "FALL", "FILL", "FEAR", "FLAW", "FAST", "FIND",
	"GATE", "GEAR", "GRID", "GLOW", "GOAL", "GOLD", "GRIP", "GROW",
	"HACK", "HASH", "HOST", "HALT", "HIDE", "HOOK", "HEAT", "HARD",
	"LINK", "LOCK", "LIMB", "LEAK", "LOOP", "LOAD", "LAST", "LATE",
	"NODE", "NULL", "NAME", "NEXT", "NEAR", "NONE", "NAVY", "NEST",
	"PING", "PORT", "PUMP", "PULL", "PIPE", "PEAK", "POST", "PATH",
	"ROOT", "RIDE", "RATE", "RISK", "READ", "REAL", "RUSH", "RULE",
	"SYNC", "SCAN", "SALT", "SLIP", "SCAM", "SAFE", "SAVE", "SEND",
	"TECH", "TRAP", "TURN", "TIME", "TASK", "TEXT", "TYPE", "TOOL",
	"WIRE", "WALL", "WORM", "WIPE", "WAIT", "WARD", "WAKE", "WEAK",
	"ZERO", "ZONE", "ZOOM", "ZINC"
]

func _ready():
	if get_parent() == get_tree().root and not initialized_from_code:
		initialize(2, 45) 
	else:
		_setup_puzzle_logic(stat_mod_cache, time_limit_cache)

# --- INITIALIZED FROM MAINBOARD ---
func initialize(stat_modifier: int, time_limit: int = 30):
	stat_mod_cache = stat_modifier
	time_limit_cache = time_limit
	initialized_from_code = true
	
	if is_inside_tree():
		_setup_puzzle_logic(stat_mod_cache, time_limit_cache)

func _setup_puzzle_logic(stat_modifier: int, time_limit: int):
	time_left = float(time_limit)
	if timer_bar:
		timer_bar.max_value = time_left
		timer_bar.value = time_left
	
	var grid_size = clampi(12 - stat_modifier, 4, 12)
	if word_grid:
		word_grid.columns = grid_size
	var total_cells = grid_size * grid_size
	
	max_words = clampi(6 - int(stat_modifier / 2.0), 2, 6)
	
	_generate_puzzle(total_cells)
	_print_figma_dimensions()

func _generate_puzzle(total_cells: int):
	randomize()
	target_sequence.clear()
	current_attempt.clear()
	
	is_row_selection = true
	active_line_index = 0
	clicked_buttons.clear()
	
	for child in word_grid.get_children():
		child.queue_free()
	
	var grid_words = []
	grid_words.resize(total_cells)
	grid_words.fill("") 
	
	for i in range(max_words):
		target_sequence.append(word_pool.pick_random())
		
	target_label.text = "TARGET: " + " - ".join(target_sequence)
	attempt_label.text = "ATTEMPT: "
	
	# ==========================================
	# GUARANTEED PATH GENERATOR
	# ==========================================
	var current_row = 0
	var current_col = 0
	var is_placing_in_row = true
	var used_indices = []
	var grid_size = word_grid.columns
	
	for i in range(max_words):
		var next_index = 0
		var valid_spots = []
		
		if is_placing_in_row:
			for c in range(grid_size):
				var idx = (current_row * grid_size) + c
				if not idx in used_indices:
					valid_spots.append(c)
			
			current_col = valid_spots.pick_random()
			next_index = (current_row * grid_size) + current_col
		else:
			for r in range(grid_size):
				var idx = (r * grid_size) + current_col
				if not idx in used_indices:
					valid_spots.append(r)
			
			current_row = valid_spots.pick_random()
			next_index = (current_row * grid_size) + current_col
		
		grid_words[next_index] = target_sequence[i]
		used_indices.append(next_index)
		is_placing_in_row = not is_placing_in_row

	# ==========================================
	# FILL REMAINDER WITH CAMOUFLAGE DECOYS
	# ==========================================
	for i in range(total_cells):
		if grid_words[i] == "":
			if randf() < 0.30:
				grid_words[i] = target_sequence.pick_random()
			else:
				var mimic_target = target_sequence.pick_random()
				grid_words[i] = _get_camouflage_word(mimic_target)
			
	var btn_width = 55
	var btn_height = 35
	var font_size = 12
	
	if grid_size > 9:
		btn_width = 45
		btn_height = 25
		font_size = 10
		
	for i in range(grid_words.size()):
		var word = grid_words[i]
		var btn = Button.new()
		btn.text = word
		btn.custom_minimum_size = Vector2(btn_width, btn_height)
		btn.add_theme_font_size_override("font_size", font_size) 
		
		var col = i % grid_size
		var row = i / grid_size
		
		btn.pressed.connect(_on_word_clicked.bind(btn, word, col, row))
		word_grid.add_child(btn)
		
	_update_grid_visuals()


func _get_camouflage_word(target: String) -> String:
	var matches = []
	for w in word_pool:
		if w != target and w[0] == target[0]:
			matches.append(w)
	if matches.size() > 0:
		return matches.pick_random()
	return word_pool.pick_random()

func _update_grid_visuals():
	for i in range(word_grid.get_child_count()):
		var btn = word_grid.get_child(i)
		
		if btn in clicked_buttons:
			btn.disabled = true
			continue
			
		var col = i % word_grid.columns
		var row = i / word_grid.columns
		
		var is_active = false
		if is_row_selection and row == active_line_index:
			is_active = true
		elif not is_row_selection and col == active_line_index:
			is_active = true
			
		btn.disabled = not is_active
		
		if is_active:
			btn.modulate = Color(0.3, 1.0, 0.4) 
		else:
			btn.modulate = Color(0.4, 0.4, 0.4) 

func _process(delta):
	if not minigame_active: return
	
	time_left -= delta
	if timer_bar:
		timer_bar.value = time_left
	
	if time_left <= 0:
		_fail_minigame("TIME OUT! LOCKOUT TRIGGERED!")

func _on_word_clicked(btn: Button, word: String, col: int, row: int):
	if not minigame_active: return
	
	current_attempt.append(word)
	clicked_buttons.append(btn)
	btn.modulate = Color(1.0, 0.6, 0.0) 
	
	attempt_label.text = "ATTEMPT: " + " - ".join(current_attempt)
	
	if current_attempt.size() == max_words:
		_check_win_condition()
	else:
		is_row_selection = not is_row_selection
		active_line_index = col if not is_row_selection else row 
		_update_grid_visuals()

func _check_win_condition():
	var is_correct = true
	
	for i in range(max_words):
		if current_attempt[i] != target_sequence[i]:
			is_correct = false
			break
			
	if is_correct:
		_win_minigame()
	else:
		time_left -= 5.0 
		attempt_label.text = "ERROR! -5 SECONDS!"
		attempt_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
		_trigger_screen_shake()
		
		set_process(false) 
		await get_tree().create_timer(1.0).timeout
		set_process(true)
		
		if time_left > 0:
			attempt_label.add_theme_color_override("font_color", Color(1, 1, 1))
			attempt_label.text = "ATTEMPT: "
			current_attempt.clear()
			
			clicked_buttons.clear()
			is_row_selection = true
			active_line_index = 0
			_update_grid_visuals()

func _win_minigame():
	minigame_active = false
	title_label.text = "FIREWALL BREACHED"
	title_label.add_theme_color_override("font_color", Color(0, 1, 0))
	attempt_label.text = "ACCESS GRANTED"
	attempt_label.add_theme_color_override("font_color", Color(0, 1, 0))
	
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _fail_minigame(msg: String):
	minigame_active = false
	title_label.text = msg
	title_label.add_theme_color_override("font_color", Color(1, 0, 0))
	if timer_bar:
		timer_bar.modulate = Color(0.2, 0.2, 0.2)
	
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _trigger_screen_shake():
	var tween = create_tween()
	var margin_node = $MarginContainer
	if not margin_node: return
	var original_pos = margin_node.position
	
	for i in range(6):
		var offset = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		tween.tween_property(margin_node, "position", original_pos + offset, 0.04)
		
	tween.tween_property(margin_node, "position", original_pos, 0.04)

func _print_figma_dimensions():
	await get_tree().process_frame
	var panel_size = size
	var button_size = Vector2.ZERO
	
	if word_grid.get_child_count() > 0:
		button_size = word_grid.get_child(0).size
		
	print("========== FIGMA EXPORT DIMENSIONS ==========")
	print("1. Create a Frame for the Main Panel: ", panel_size.x, "W x ", panel_size.y, "H")
	print("2. Create a Frame for the Buttons: ", button_size.x, "W x ", button_size.y, "H")
	print("=============================================")
