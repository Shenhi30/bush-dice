extends Node

# This holds the file path so the Main Board knows what to load when it opens
var current_save_path: String = ""

# This is the MASTER dictionary for the entire campaign
var campaign_data: Dictionary = {
	"campaign_name": "New Campaign",
	"quests": [], # Global quests
	"active_scene_id": "default_map", 
	"scenes": {
		# We will store individual maps, tokens, and walls inside here!
		"default_map": {
			"map_image_path": "",
			"map_scale": 1.0,
			"tokens": [],
			"walls": []
		}
	}
}
