extends Control

@onready var email_input = $VBoxContainer/EmailInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var username_input = $VBoxContainer/UsernameInput
@onready var feedback_label = $VBoxContainer/FeedbackLabel

var pending_username: String = ""

func _ready():
	#Supabase.config.supabase_url = "https://jjhmxtuwvjddcuwouebf.supabase.co"
	#Supabase.config.supabase_anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqaG14dHV3dmpkZGN1d291ZWJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0NzgwNzMsImV4cCI6MjA5NDA1NDA3M30.vR0q7fuDYJrqwR02orpuYv7uan9SthfdbqPxdmWhNXE" # Put your full key here
	
	# Ensure these are cleared on start
	feedback_label.text = ""
	
	# Connect to the modern Addon signals
	# Note: These signals are now the standard way to handle the results
	Supabase.auth.signed_in.connect(_on_signed_in)
	Supabase.auth.signed_up.connect(_on_signed_up)
	Supabase.auth.error.connect(_on_auth_error) # In 4.x it is often 'auth_error'

# --- 1. BUTTON TRIGGERS ---

func _on_login_btn_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text
	
	if email == "" or password == "":
		show_feedback("Please enter email and password", Color.RED)
		return
		
	show_feedback("Logging in...", Color.WHITE)
	Supabase.auth.sign_in(email, password)

func _on_register_btn_pressed():
	pending_username = username_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	var password = password_input.text
	
	if pending_username == "" or email == "" or password == "":
		show_feedback("Please fill in all fields", Color.RED)
		return

	show_feedback("Creating account...", Color.CYAN)
	Supabase.auth.sign_up(email, password)

# --- 2. CLOUD CALLBACKS ---

func _on_signed_up(user):
	show_feedback("Account created! Saving profile...", Color.CYAN)
	
	# 1. CORRECT GODOT SYNTAX: We build a SupabaseQuery object first.
	# (I added the square brackets [ ] back in just to be 100% safe with the addon's parser)
	var query = SupabaseQuery.new().from("profiles").insert([{
		"id": user.id,
		"username": pending_username
	}])
	
	# 2. We pass the query to the database, which creates a Task
	var task = Supabase.database.query(query)
	
	# 3. We await the task's built-in signal
	await task.completed
	
	# 4. We check the task's properties directly for errors
	if task.error == null:
		show_feedback("Profile saved! Entering VTT...", Color.GREEN)
	else:
		print("Database Error: ", task.error)
		show_feedback("Database error, entering anyway...", Color.YELLOW)
	
	GameState.player_name = pending_username
	GameState.user_id = user.id
	GameState.is_logged_in = true
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")


func _on_signed_in(user):
	show_feedback("Success! Fetching profile...", Color.GREEN)
	
	# 1. CORRECT GODOT SYNTAX for SELECT
	var query = SupabaseQuery.new().from("profiles").select(["username"]).eq("id", user.id)
	var task = Supabase.database.query(query)
	
	await task.completed
	
	# 2. Extract the data safely
	if task.error == null and task.data != null and task.data.size() > 0:
		GameState.player_name = task.data[0]["username"]
	else:
		GameState.player_name = "Unknown Shinobi"
		
	GameState.user_id = user.id
	GameState.is_logged_in = true
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")


func _on_auth_error(error):
	var msg = ""
	if error is Dictionary and error.has("message"):
		msg = error.message
	else:
		msg = str(error)
	# The 'error' object in 4.x usually has a 'message' property
	show_feedback("Error: " + str(error.message), Color.RED)

# Helper to keep the code clean
func show_feedback(text: String, color: Color):
	feedback_label.text = text
	feedback_label.modulate = color
