extends TextureRect

# This tells the MainBoard exactly WHICH player brain to pull from the vault
var pc_name: String = ""

func _get_drag_data(_at_position: Vector2):
	# 1. Create the Ghost Preview (what follows your mouse)
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	preview.modulate.a = 0.6 # Ghostly transparency
	
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2.0
	set_drag_preview(c)
	
	# 2. Package the data as a "vault_drop" instead of a generic token
	return {
		"type": "vault_drop",
		"pc_name": pc_name
	}
