@tool
extends MarginContainer

## to use, unpack as editable children, then add your content under the Content node
## or use add_item

# we cannot use % for content because that doesn't work if the scene gets made local
@onready var content: MarginContainer = find_child("FoldContent")


func _ready() -> void:
	content.visible = false


func _on_show_fold_pressed() -> void:
	if content.get_child_count() == 0:
		NSound.Log.w("you need to add your own content under the Content node")

	content.visible = !content.visible


func add_item(control: Control):
	content.add_child(control)
