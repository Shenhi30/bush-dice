extends Node

var current_save_path: String = ""

signal blueprint_updated
signal fast_roll_requested(char_name: String, roll_name: String, modifier: int, dice_logic: String, is_whisper: bool)
signal token_data_edit_requested(token_name: String, key: String, new_value: Variant)

# --- NEW SIGNAL FOR UI REFRESH ---
signal campaign_loaded 

# --- MULTIPLAYER SYNC ---

func gm_update_blueprint(new_template: Dictionary):
	if not multiplayer.is_server():
		return
		
	campaign_data["sheet_template"] = new_template
	blueprint_updated.emit()
	
	if multiplayer.multiplayer_peer and multiplayer.get_peers().size() > 0:
		rpc("sync_blueprint_to_clients", new_template)

@rpc("authority", "call_remote", "reliable")
func sync_blueprint_to_clients(new_template: Dictionary):
	campaign_data["sheet_template"] = new_template
	blueprint_updated.emit()

# --- CAMPAIGN MANAGEMENT ---

func set_campaign_system(system_id: String):
	# 1. Make sure the system actually exists in our templates
	if not SheetTemplates.TEMPLATES.has(system_id): 
		return
		
	# 2. Grab the new blueprint dictionary
	var new_template = SheetTemplates.TEMPLATES[system_id]
	
	# 3. Update the tracking ID
	campaign_data["system_id"] = system_id
	
	# 4. (Optional) Wipe old character data so stats don't bleed between systems
	campaign_data["pc_vault"] = {}
	
	print("Switched campaign to system: ", system_id)
	
	# 5. Send it through your secure network function! 
	# This automatically updates the GM's local UI AND beams the new template to all players.
	gm_update_blueprint(new_template)

var campaign_data: Dictionary = {
	"campaign_name": "New Campaign",
	"system_id": "dnd_5e", # Track which system is active
	"quests": [],
	"backpacks": {},
	"loot_containers": {},
	"pc_vault": {},
	"sheet_template": {}, 
	"active_scene_id": "default_map", 
	"scenes": {
		"default_map": {
			"map_image_path": "",
			"map_scale": 1.0,
			"tokens": [],
			"walls": []
		}
	}
}

# ==========================================
# SAVE / LOAD JSON MECHANICS
# ==========================================

func save_campaign(file_path: String):
	var json_string = JSON.stringify(campaign_data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		current_save_path = file_path
		print("Campaign successfully saved to: ", file_path)
	else:
		print("Error: Could not save campaign!")

func load_campaign(file_path: String):
	if not FileAccess.file_exists(file_path):
		print("Error: Save file not found!")
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		# Parse the JSON string back into a dictionary
		var parsed_data = JSON.parse_string(json_string)
		
		if parsed_data is Dictionary:
			campaign_data = parsed_data
			current_save_path = file_path
			print("Campaign successfully loaded from: ", file_path)
			
			# THE CRITICAL TRIGGER: Tell the rest of the game the data has changed!
			campaign_loaded.emit()
		else:
			print("Error: Save file is corrupted or invalid.")
