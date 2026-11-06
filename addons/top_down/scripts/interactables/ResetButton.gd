## Turns every row and column lever off.
class_name ResetButton
extends GridControl

func _can_use()->bool:
	return super._can_use() && (get_grid().row_select.has(1) || get_grid().col_select.has(1))

func _use()->void:
	sprite.frame = 1
	get_tree().create_timer(0.2).timeout.connect(func()->void: sprite.frame = 0)
	get_grid().clear_selection()

func _prompt_text()->String:
	return "Reset levers"
