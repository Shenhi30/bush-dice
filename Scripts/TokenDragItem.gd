extends VBoxContainer

var token_image_path: String = ""
@export var is_enemy: bool = true

func _get_drag_data(_at_position: Vector2):
	# Grab the texture from the child node!
	var tex = $Icon.texture
	if tex == null: return null

	var preview = TextureRect.new()
	preview.texture = tex
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	preview.modulate.a = 0.6 
	
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2.0 
	set_drag_preview(c)
	
	return {
		"type": "token_drop",
		"path": token_image_path,
		"is_enemy": is_enemy
	}
