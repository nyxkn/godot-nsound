tool
extends MarginContainer

var Log = preload("res://addons/nsound/logger.gd").new(self)


# to use, unpack as editable children, then add your content under the Content node

onready var content := $VBoxContainer/Content


func _ready() -> void:
	if content.get_child_count() == 0:
		Log.w("you need to add your own content under the Content node")

	get_node("%ShowFold").connect("pressed", self, "_on_ShowFold_pressed")
	# ensure content is hidden
	content.visible = false


func _on_ShowFold_pressed() -> void:
	content.visible = !content.visible
