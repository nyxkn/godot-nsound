tool
extends AudioServerBus
class_name LevelsTrack

# you must NOT initialize levels to a default value in here
# if you do it will be shared between all instances
# for some very strange reason, this dictionary doesn't preserve order across reloads
# so you end up with a default ordering with 11 before 1
# not sure there's anything we can do here
export(Dictionary) var levels: Dictionary

export(bool) var regex_match := false

# single only activates the highest level (elias)
# add activates everything up to level
# pad activates level and adjacent levels
enum Type { SINGLE, ADD, PAD }
export(Type) var type := Type.SINGLE


func _ready() -> void:
	# to clear ALL data in EVERY instance
#	levels.clear()

	if Engine.editor_hint:
		if levels.empty():
			for node in get_children():
				add_levels_entry(node)


func add_levels_entry(node: Node):
	if regex_match:
		var level = 0
		# try to guess the level number by using the first encountered number
		var re = StringUtils.compile_regex("([0-9]+)")
		var re_match: RegExMatch = re.search(node.name)
		if re_match:
			level = int(re_match.get_string())

		levels[node.name] = level
	else:
		levels[node.name] = levels.size() + 1
