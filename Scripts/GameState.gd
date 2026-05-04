extends Node


# True = GM can see traps, hidden layers, and transparent monsters.
# False = Player view. Hidden things vanish completely.
var is_gm_mode: bool = true 
var is_gm_vision_active: bool = false

# We create a signal so we can yell at all tokens instantly when the mode changes!
signal gm_mode_changed(is_gm)

func toggle_gm_mode():
	is_gm_mode = !is_gm_mode
	gm_mode_changed.emit(is_gm_mode)
