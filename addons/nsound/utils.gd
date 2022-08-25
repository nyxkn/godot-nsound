class_name NUtils


static func get_all_children(node: Node) -> Array:
	var children := []

	for child in node.get_children():
		children.append(child)

		if child.get_child_count() > 0:
			children.append_array(get_all_children(child))

	return children


static func merge_dict(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged = a.duplicate()
	for key in b:
		merged[key] = b[key]

	return merged


static func setup_buses(node: Bus) -> void:
	var children = get_all_children(node)
	children.push_front(node)
	for child in children:
		if child is Bus:
			var parent_node = child.get_parent()
			var send_bus
			if parent_node is Song and not parent_node is Section:
				send_bus = Audio.music_bus
			elif parent_node is AudioServerBus:
				send_bus = parent_node.bus_name
			else:
				send_bus = Audio.music_bus
			child.init(send_bus)


static func compile_regex(regex_string: String) -> RegEx:
	var re := RegEx.new()
	re.compile(regex_string)
	if not re.is_valid():
		Log.e(['warning: regex', regex_string, 'is not valid'], 'compile_regex')
	return re
