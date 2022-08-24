class_name NSoundUtils

static func setup_buses(node: Bus) -> void:
	var children = Utils.get_all_children(node)
	children.push_front(node)
	for child in children:
		if child is Bus:
			var parent_node = child.get_parent()
			var send_bus
			if parent_node is Song and not parent_node is Section:
				send_bus = "Music"
			elif parent_node is AudioServerBus:
				send_bus = parent_node.bus_name
			else:
				send_bus = "Music"
			child.init(send_bus)
