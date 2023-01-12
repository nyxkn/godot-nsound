tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("NSound", "res://addons/nsound/core.gd")


func _exit_tree():
	remove_autoload_singleton("NSound")

