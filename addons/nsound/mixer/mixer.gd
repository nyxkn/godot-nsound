extends Control


const Fold = preload("res://addons/nsound/mixer/fold.tscn")
const ChannelStrip = preload("res://addons/nsound/mixer/channel_strip.tscn")


func _ready() -> void:
	pass
#	get_node("%MusicSystem").connect("song_loaded", self, "_on_song_loaded")
	init_core_buses()


func show_section(section):
	pass


func _on_song_loaded(song_name: String):
	print("signal")
	var song_node = get_node("%Music").get_node(song_name)
	init_song(song_node)


func init_core_buses():
	for bus in Audio.core_buses.values():
		var abc = ChannelStrip.instance().init(bus)
		$Strips/CoreStrips.add_child(abc)


func init_all_buses() -> void:
	for bus in Audio.runtime_buses.values():
		var abc = ChannelStrip.instance().init(bus)
		abc.name = bus.bus_name
		$Strips/RuntimeStrips.add_child(abc)


func init_song(root_node: Node) -> void:
	var all_strips = []
	var audioserver_bus_strips = {}

	var all_nodes = Utils.get_all_children(root_node)
	all_nodes.push_front(root_node)
	for node in all_nodes:
		if node is Bus:
			var bus: Bus = node
			var strip = ChannelStrip.instance().init(bus)
			strip.name = bus.name
			all_strips.append(strip)
			if node is AudioServerBus:
				audioserver_bus_strips[bus.bus_name] = strip
			if node.disabled:
				strip.visible = false

	for strip in all_strips:
		var bus_send = strip.bus.send
		if not bus_send:
			Log.e(["strip", strip, "has no bus send"])
		elif bus_send in Audio.core_buses:
			$Strips/RuntimeStrips.add_child(strip)
		else:
			audioserver_bus_strips[bus_send].add_substrip(strip)
