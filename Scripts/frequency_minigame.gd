extends PanelContainer

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var display = $MarginContainer/VBoxContainer/DisplayControl
@onready var timer_bar = $MarginContainer/VBoxContainer/TimerBar

var time_left: float = 30.0

var ring_rotations = [0.0, 0.0, 0.0]
var ring_radiuses = [100.0, 70.0, 40.0] 
var selected_ring: int = 0

var tolerance: float = 5.0
var is_hacked: bool = false
var target_angle: float = 0.0 # The randomized finish point!

var active_ring_designs = []


func _ready():
	display.draw.connect(_on_display_draw)
	
	if get_parent() == get_tree().root:
		initialize(0)

func _process(delta):
	if is_hacked: return
	
	time_left -= delta
	timer_bar.value = time_left
	
	if time_left <= 0:
		_fail_minigame()

# --- INITIALIZED FROM MAINBOARD ---
func initialize(int_modifier: int, time_limit: int = 20): # Add time_limit here!
	time_left = float(time_limit)
	timer_bar.max_value = time_left
	timer_bar.value = time_left
	
	# Increased the maximum tolerance from 15.0 to 35.0 so god-tier stats actually feel powerful!
	# At 35.0 tolerance, they barely have to spin the rings to win.
	tolerance = clampf(3.0 + (int_modifier * 2.0), 3.0, 35.0)
	
	randomize()
	target_angle = randf_range(0.0, 360.0)
	
	for i in range(3):
		ring_rotations[i] = randf_range(0.0, 360.0)
		
	# --- UNCAPPED VISUAL FRAGMENTATION ---
	if int_modifier >= 20:
		# GOD-TIER (INT +10 or higher): Pure, unbroken rings of light. Supreme stability.
		active_ring_designs = [
			[[20, 340]], # Outer
			[[20, 340]], # Middle
			[[20, 340]]  # Inner
		]
	elif int_modifier >= 10:
		# HIGH INT: Very clean, barely fragmented.
		active_ring_designs = [
			[[20, 170], [180, 340]],               
			[[20, 200], [210, 340]],               
			[[20, 340]]                            
		]
	elif int_modifier >= 4:
		# AVERAGE INT: Standard fragmentation.
		active_ring_designs = [
			[[20, 80], [90, 150], [170, 250], [270, 340]],            
			[[20, 60], [80, 130], [150, 220], [240, 340]],            
			[[20, 50], [70, 100], [120, 160], [180, 220], [240, 340]] 
		]
	else:
		# LOW INT (Negative): Heavily corrupted.
		active_ring_designs = [
			[[20, 50], [70, 110], [140, 170], [200, 230], [260, 290], [310, 340]], 
			[[20, 40], [60, 90], [110, 140], [160, 180], [210, 240], [270, 290], [320, 340]], 
			[[20, 35], [55, 75], [95, 115], [135, 155], [175, 195], [215, 235], [255, 275], [295, 315], [330, 340]] 
		]
		
	display.queue_redraw()	

# --- INPUT HANDLING ---
func _unhandled_input(event):
	if is_hacked: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: _select_ring(0)
		elif event.keycode == KEY_2: _select_ring(1)
		elif event.keycode == KEY_3: _select_ring(2)
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			ring_rotations[selected_ring] -= 5.0
			_check_alignment()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			ring_rotations[selected_ring] += 5.0
			_check_alignment()
			get_viewport().set_input_as_handled()

func _select_ring(index: int):
	selected_ring = index
	display.queue_redraw()

func _check_alignment():
	display.queue_redraw()
	var all_aligned = true
	
	for rot in ring_rotations:
		# Calculate the shortest distance between the ring's rotation and the target_angle
		var diff = fmod(abs(rot - target_angle), 360.0)
		if diff > 180.0:
			diff = 360.0 - diff
			
		# If even one ring is outside the tolerance, we aren't aligned yet
		if diff > tolerance:
			all_aligned = false
			break
			
	if all_aligned:
		_win_minigame()

func _fail_minigame():
	is_hacked = true # Reusing this flag to lock inputs
	title_label.text = "SIGNAL LOST! CONNECTION SEVERED!"
	title_label.add_theme_color_override("font_color", Color(1, 0, 0))
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _win_minigame():
	is_hacked = true
	title_label.text = "ACCESS GRANTED"
	title_label.add_theme_color_override("font_color", Color(0, 1, 0))
	
	# Snap all rings perfectly to the target angle for a clean finish!
	ring_rotations = [target_angle, target_angle, target_angle]
	display.queue_redraw()
	
	await get_tree().create_timer(1.5).timeout
	queue_free()

# --- DYNAMIC DRAWING MAGIC ---
func _on_display_draw():
	var center = display.size / 2.0
	
	# ==========================================
	# 1. DRAW THE TARGET MARKER
	# ==========================================
	var target_rad = deg_to_rad(target_angle - 90.0)
	var marker_radius = ring_radiuses[0] + 20.0 
	
	var p1 = center + Vector2(cos(target_rad), sin(target_rad)) * marker_radius
	var p2 = center + Vector2(cos(target_rad), sin(target_rad)) * (marker_radius - 12.0)
	
	display.draw_line(p1, p2, Color(1.0, 0.2, 0.2), 4.0, true)
	display.draw_circle(p1, 4.0, Color(1.0, 0.2, 0.2))

	# ==========================================
	# 2. DRAW COMPLEX SCI-FI RINGS
	# ==========================================
	# Highly fractured segments for maximum visual complexity
	var ring_designs = [
		[[20, 80], [90, 150], [170, 250], [270, 340]],            # Outer Ring: 4 segments
		[[20, 60], [80, 130], [150, 220], [240, 340]],            # Middle Ring: 4 segments
		[[20, 50], [70, 100], [120, 160], [180, 220], [240, 340]] # Inner Ring: 5 segments
	]
	
	for i in range(3):
		var base_rot = ring_rotations[i] - 90.0
		
		# --- NEW: DULL / DORMANT TRACK ---
		var dull_start = deg_to_rad(base_rot + 20)
		var dull_end = deg_to_rad(base_rot + 340)
		
		# Alpha dropped to 0.03 (barely visible)
		var dull_color = Color(1.0, 1.0, 1.0, 0.03) 
		
		# Thickness dropped to 1.0 (the thinnest possible line)
		display.draw_arc(center, ring_radiuses[i], dull_start, dull_end, 64, dull_color, 1.0, true)
		
		# --- GLOWING ACTIVE SEGMENTS ---
		var active_color = Color(0.2, 0.8, 1.0) # Cyberpunk Blue
		if is_hacked:
			active_color = Color(0.0, 1.0, 0.0) # Hacker Green
		elif i == selected_ring:
			active_color = Color(1.0, 0.8, 0.0) # Selected Gold
			
		# WE NOW USE THE ARRAY GENERATED IN INITIALIZE()!
		for segment in active_ring_designs[i]:
			var start_angle = deg_to_rad(base_rot + segment[0])
			var end_angle = deg_to_rad(base_rot + segment[1])
			
			display.draw_arc(center, ring_radiuses[i], start_angle, end_angle, 32, active_color, 12.0, true)
