extends Node

# True = GM can see traps, hidden layers, and transparent monsters.
# False = Player view. Hidden things vanish completely.
var is_gm_mode: bool = false # Default to false for safety!
var is_gm_vision_active: bool = false # Keeping this since you had it!

var player_name: String = ""

# We create a signal so we can yell at all tokens instantly when the mode changes
signal gm_mode_changed(is_gm)

# --- NEW MULTIPLAYER FUNCTION ---
# The Main Menu uses this to strictly lock in the role when Hosting or Joining.
func set_gm_mode(is_gm: bool):
	is_gm_mode = is_gm
	gm_mode_changed.emit(is_gm_mode)

# --- OLD LOCAL TESTING FUNCTION ---
# You can keep this! If you (the GM) want a button on your GM Dashboard 
# to temporarily view the board through the players' eyes, this will still work!
func toggle_gm_mode():
	is_gm_mode = !is_gm_mode
	gm_mode_changed.emit(is_gm_mode)

# --- MULTIPLAYER RPCs ---

# "@rpc" tells Godot this function can be sent over the internet.
# "authority" means ONLY the server (Host) is allowed to send this command.
# "call_remote" means it will only run on the targeted player's PC, not the Host's.
# "reliable" means the packet won't get dropped if their internet blips.
@rpc("authority", "call_remote", "reliable")
func receive_gm_promotion(is_now_gm: bool):
	# When a player receives this message from the Host, they update their role!
	set_gm_mode(is_now_gm)
	
	if is_now_gm:
		print("The Host has promoted you to Game Master!")
	else:
		print("Your Game Master privileges have been revoked.")
