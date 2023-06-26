@tool
extends AudioServerBus
class_name SegmentsTrack

# or maybe should we add this as properties on an audiostreamplayer custom class?
#export var timeline setget set_timeline # (Array, float)

# you must NOT initialize this to a default value in here
@export var timeline: Dictionary
const DEFAULT_VALUE = 1.1


func _ready() -> void:
	# use this to reset ALL data in EVERY instance
#	timeline.clear()

	if Engine.is_editor_hint():
		if timeline.is_empty():
			for node in get_children():
				add_entry(node.name)

		# these functions are probably evil and lead to data loss
#		connect("child_entered_tree",Callable(self,"child_entered_tree"))
#		connect("child_exiting_tree",Callable(self,"child_exiting_tree"))

		for n in get_children():
			n.renamed.connect(child_renamed.bind(n))


func child_renamed(node: Node):
	# finding the old name is a little clunky because we don't store the nodes
	var children_names = []
	for child in get_children():
		children_names.append(node.name)

	var old_name = ""
	for node_name in timeline:
		if ! children_names.has(node_name):
			old_name = node_name

	remove_entry(old_name)
	add_entry(node.name)


func add_entry(node_name: String):
	if not timeline.has(node_name):
		timeline[node_name] = DEFAULT_VALUE


func remove_entry(node_name: String):
	timeline.erase(node_name)


func child_entered_tree(node: Node):
	add_entry(node.name)


func child_exiting_tree(node: Node):
	remove_entry(node.name)


#func set_timeline(time):
#	for i in time.size():
#		if time[i] < 1:
#			time[i] = 1.0
#
#		if time[i] == int(time[i]):
#			time[i] += 0.1
#
#	timeline = time
##	if timer: timer.start()
#
#
#func update_inspector():
#	notify_property_list_changed()


