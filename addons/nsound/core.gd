extends Node

# nsound core autoload where we keep state

var Log = preload("res://addons/nsound/logger.gd").new(self)
const Utils = preload("res://addons/nsound/utils.gd")

# { bus_name: Bus }
var core_buses := {}
var runtime_buses := {}
# we can't have names index for tracks because track names are not guaranteed to be unique
# you could force a unique name in register_track though and feed it back to the track
var runtime_tracks := []


var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var music_bus := "Music"


func _ready() -> void:
#	AudioServer.connect("bus_layout_changed",Callable(self,"on_bus_layout_changed"))

	for i in AudioServer.bus_count:
		var bus_name = AudioServer.get_bus_name(i)
		var bus = AudioServerBus.new()
		bus.wrap(bus_name)
		core_buses[bus_name] = bus
	Log.d(["core buses", core_buses])


# would like to use type AudioServerBus but sometimes we get cyclic dependency errors
func register_bus(bus: AudioServerBus) -> void:
	if runtime_buses.has(bus.bus_name):
		Log.e(["attempting to register bus", bus.name, ", but a bus of the same name is already registered"])
		return

	runtime_buses[bus.bus_name] = bus


#func unregister_bus(bus: AudioServerBus) -> void:
#	if runtime_buses.has(bus.bus_name):
#		runtime_buses.erase(bus.bus_name)


# would like to use type AudioTrack but sometimes we get cyclic dependency errors
func register_track(bus: AudioTrack) -> void:
	if runtime_tracks.has(bus):
		Log.e(["attempting to register an already registered track", bus.name])
		return

	runtime_tracks.append(bus)


func get_bus(bus_name: String) -> Bus:
	var buses = Utils.merge_dict(core_buses, runtime_buses)
	return buses[bus_name]


func get_all_buses() -> Array:
	var buses = core_buses.values()
	buses.append_array(runtime_buses.values())
	return buses


func remove_all_buses() -> void:
#	for track in runtime_tracks:
#		track.queue_free()

	Log.d(["buses size", AudioServer.bus_count])

	runtime_tracks.clear()

#	for i in range(AudioServer.bus_count - 1, -1, -1):
#		AudioServer.remove_bus(i)

	for k in runtime_buses:
#		AudioServer.remove_bus(runtime_buses[k].bus_idx)
		runtime_buses[k].unregister()
#		runtime_buses[k].queue_free()

	runtime_buses.clear()

#func on_bus_layout_changed() -> void:
#	Log.d("bus layout changed")


func get_buses_count() -> Dictionary:
	var count = {
		'core buses': core_buses.size(),
		'runtime buses': runtime_buses.size(),
		'runtime tracks': runtime_tracks.size(),
		'audioserver buses': AudioServer.bus_count,
		}

	return count


func setup_buses(node: Bus) -> void:
	var children = Utils.get_all_children(node)
	children.push_front(node)
	for child in children:
		if child is Bus:
			var parent_node = child.get_parent()
			var send_bus
			if parent_node is Song and not parent_node is Section:
#				send_bus = NSound.music_bus
				send_bus = parent_node.bus_name
			elif parent_node is AudioServerBus:
				send_bus = parent_node.bus_name
			else:
				send_bus = music_bus
			child.init(send_bus)
