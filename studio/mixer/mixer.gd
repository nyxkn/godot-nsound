extends Control

var Log = preload("res://addons/nsound/logger.gd").new().init(self)

const Fold = preload("res://studio/ui/fold.tscn")
const ChannelStrip = preload("res://studio/mixer/channel_strip.tscn")
onready var core_strips: HBoxContainer = $Strips/CoreStrips
onready var runtime_strips: HBoxContainer = $Strips/RuntimeStrips


func _ready() -> void:
	pass
	init_core_buses()


func show_section(section):
	pass


func init_core_buses():
	for bus in NAudio.core_buses.values():
		var abc = ChannelStrip.instance().init(bus)
		core_strips.add_child(abc)


#func init_all_buses() -> void:
#	for bus in NAudio.runtime_buses.values():
#		var abc = ChannelStrip.instance().init(bus)
#		abc.name = bus.bus_name
#		$Strips/RuntimeStrips.add_child(abc)

func clear() -> void:
	for s in runtime_strips.get_children():
		s.queue_free()


func init_song(root_node: Node) -> void:
	var strips = {}

	var all_nodes = NUtils.get_all_children(root_node)
#	all_nodes.push_front(root_node)
	for node in all_nodes:
		if node is Bus:
			var bus: Bus = node
			var strip = ChannelStrip.instance().init(bus)
			strip.name = bus.name
			if not bus.send:
				Log.e(["bus", bus, "is missing a send"])
			if node is AudioServerBus:
				if not bus.bus_name:
					Log.e(["bus", bus, "is missing a bus_name. i.e. it wasn't initialized correctly"])
				strips[bus.bus_name] = strip
			else:
				strips[bus.name] = strip
			if node.disabled:
				strip.visible = false

	# adding all top-level strips
	for k in strips:
		if strips[k].bus.send in NAudio.core_buses:
			runtime_strips.add_child(strips[k])

	# waiting for the top-level strips to be readied
	yield(get_tree(), "idle_frame")

	for k in strips:
		var strip = strips[k]
		var bus_send = strip.bus.send
		if not bus_send:
			Log.e(["strip", strip, "has no bus send"])
		elif bus_send in NAudio.core_buses:
			pass
			# already added
		elif bus_send in strips:
			if not strips[bus_send].is_inside_tree():
				Log.e(["the strip for bus", bus_send, "wasn't created successfully"])
			else:
				strips[bus_send].add_substrip(strip)
		else:
			Log.e(["the bus", bus_send, "(bus_send of bus", strip.bus.name, ") does not exist"])
