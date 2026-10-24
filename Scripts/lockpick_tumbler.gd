extends PanelContainer

@onready var pin_container = $MarginContainer/VBoxContainer/PinContainer
@onready var action_btn = $MarginContainer/VBoxContainer/ActionBtn
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var timer_bar = $MarginContainer/VBoxContainer/TimerBar

var time_left: float = 30.0
var minigame_active: bool = true

var current_pin_index: int = 0
var time_passed: float = 0.0

# Налаштування складності
var pin_speed: float = 8.0 
var sweet_spot_min: float = 0.0
var sweet_spot_max: float = 0.0

func _ready():
	# Підключаємо кнопку та пробіл
	action_btn.pressed.connect(_on_action_pressed)
	
	# Тимчасовий запуск для тестування самої сцени (якщо запустити її через F6).
	# Під час реальної гри MainBoard викличе initialize() з реальними статами.
	if get_parent() == get_tree().root:
		initialize(0) # Тестуємо з DEX модом +2

# --- ІНІЦІАЛІЗАЦІЯ ВІД MAINBOARD ---
func initialize(dex_modifier: int, time_limit: int = 30): # Add time_limit here!
	time_left = float(time_limit)
	timer_bar.max_value = time_left
	timer_bar.value = time_left
	
	var base_speed = 12.0
	pin_speed = clampf(base_speed - (dex_modifier * 1.5), 4.0, 20.0)
	
	# 1. Розрахунок кількості пінів (Чим вищий DEX, тим менше пінів. Мінімум 3)
	var total_pins = clampi(10 - dex_modifier, 3, 10)
	
	# 2. Розрахунок "Зеленої зони" (Чим вищий DEX, тим ширша зона)
	var sweet_spot_width = 15.0 + (dex_modifier * 5.0) 
	sweet_spot_min = 50.0 - (sweet_spot_width / 2.0)
	sweet_spot_max = 50.0 + (sweet_spot_width / 2.0)
	
	title_label.text = "Lockpicking... (%s Pins)" % total_pins
	
	# 3. Динамічна генерація пінів
	for i in range(total_pins):
		var pin = ProgressBar.new()
		pin.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		pin.custom_minimum_size = Vector2(40, 150)
		pin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pin.show_percentage = false
		pin_container.add_child(pin)
	
	pin_container.draw.connect(_draw_sweet_spot)
	
	if get_parent() == get_tree().root:
		pin_container.queue_redraw()
	

func _process(delta):
	if not minigame_active: return
	
	# --- TIMER LOGIC ---
	time_left -= delta
	timer_bar.value = time_left
	if time_left <= 0:
		_fail_minigame()
		return
	# Додаємо час для синусоїди
	time_passed += delta * pin_speed
	
	# Рухаємо тільки поточний активний пін
	if current_pin_index < pin_container.get_child_count():
		var active_pin = pin_container.get_child(current_pin_index)
		
		# sin() повертає значення від -1 до 1. 
		# Перетворюємо це на відсотки від 0 до 100
		var wave = (sin(time_passed) + 1.0) / 2.0 
		active_pin.value = wave * 100.0

# --- ОБРОБКА ВВОДУ ---
func _unhandled_input(event):
	# Дозволяємо гравцю використовувати Пробіл замість кліку мишкою
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_on_action_pressed()
		get_viewport().set_input_as_handled()

func _on_action_pressed():
	if current_pin_index >= pin_container.get_child_count(): return
	
	var active_pin = pin_container.get_child(current_pin_index)
	
	# Перевіряємо, чи потрапив пін у зелену зону
	if active_pin.value >= sweet_spot_min and active_pin.value <= sweet_spot_max:
		# УСПІХ!
		active_pin.modulate = Color(0.2, 1.0, 0.2) # Яскраво-зелений
		current_pin_index += 1
		
		# Перевіряємо, чи всі піни зламано
		if current_pin_index >= pin_container.get_child_count():
			_win_minigame()
	else:
		# ПРОВАЛ!
		title_label.text = "CLICK! Pin dropped..."
		title_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
		# Робимо невеличку затримку для візуального покарання (скидаємо прогрес)
		set_process(false) # Зупиняємо рух
		active_pin.modulate = Color(1.0, 0.2, 0.2) # Червоний
		
		await get_tree().create_timer(0.5).timeout
		
		# Скидання
		current_pin_index = 0
		time_passed = 0.0
		title_label.add_theme_color_override("font_color", Color(1, 1, 1))
		title_label.text = "Lockpicking..."
		for pin in pin_container.get_children():
			pin.modulate = Color(1, 1, 1) # Повертаємо стандартний колір
		set_process(true)

func _fail_minigame():
	minigame_active = false
	title_label.text = "TIME OUT! LOCKOUT TRIGGERED!"
	title_label.add_theme_color_override("font_color", Color(1, 0, 0))
	timer_bar.modulate = Color(0.2, 0.2, 0.2) # Darken the bar
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _win_minigame():
	minigame_active = false # Stop the timer
	set_process(false)
	title_label.text = "ACCESS GRANTED"
	title_label.add_theme_color_override("font_color", Color(0, 1, 0))
	action_btn.text = "CLOSE"
	
	# Відключаємо стару логіку кнопки і підключаємо нову (просто закрити вікно)
	action_btn.pressed.disconnect(_on_action_pressed)
	action_btn.pressed.connect(func(): queue_free())
	
	# Відправляємо повідомлення в чат (Опціонально)
	var main = get_tree().current_scene
	if main and main.has_method("receive_chat_message"):
		var msg = "\n[color=green]Successfully picked the lock![/color]"
		if multiplayer.is_server():
			main.receive_chat_message(GameState.player_name, msg, GameState.player_color_hex)
			main.rpc("receive_chat_message", GameState.player_name, msg, GameState.player_color_hex)
		else:
			main.rpc_id(1, "request_chat_message", GameState.player_name, msg, GameState.player_color_hex)

func _draw_sweet_spot():
	# Оскільки ProgressBar заповнюється знизу вгору, 0% - це низ (size.y), а 100% - це верх (0).
	var y_bottom = pin_container.size.y * (1.0 - (sweet_spot_min / 100.0))
	var y_top = pin_container.size.y * (1.0 - (sweet_spot_max / 100.0))
	var zone_height = y_bottom - y_top
	
	# Малюємо напівпрозорий зелений прямокутник на всю ширину контейнера
	pin_container.draw_rect(Rect2(0, y_top, pin_container.size.x, zone_height), Color(0.0, 1.0, 0.0, 0.3))
