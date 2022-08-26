tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("NAudio", "res://addons/nsound/audio_framework.gd")


func _exit_tree():
	remove_autoload_singleton("NAudio")

