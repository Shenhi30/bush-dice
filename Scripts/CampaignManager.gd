extends Node

var current_save_path: String = ""
signal blueprint_updated
# Updated signature to include dice_logic!
signal fast_roll_requested(char_name: String, roll_name: String, modifier: int, dice_logic: String)

# --- NEW SIGNAL FOR EDITING STATS ON THE FLY ---
signal token_data_edit_requested(token_name: String, key: String, new_value: Variant)

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
	
	# 4. (Optional) Wipe old character data so D&D stats don't bleed into Shinobigami
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
	"pc_vault": {},
	# This now gets set by set_campaign_system()
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
