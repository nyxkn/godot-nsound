extends Node

# { bus_name: Bus }
var core_buses := {}
var runtime_buses := {}
var runtime_tracks := []


var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var music_bus := "Master"


func _ready() -> void:
	for i in AudioServer.bus_count:
		var bus_name = AudioServer.get_bus_name(i)
		var bus = AudioServerBus.new()
		bus.wrap(bus_name)
		core_buses[bus_name] = bus


func register_bus(bus: AudioServerBus) -> void:
	if runtime_buses.has(bus.bus_name):
		Log.e(["attempting to register bus", bus.name, ", but a bus of the same name is already registered"], name)
		return

	runtime_buses[bus.bus_name] = bus


func register_track(bus: AudioTrack) -> void:
	if runtime_tracks.has(bus):
		Log.e(["attempting to register an already registered track", bus.name])
		return

	runtime_tracks.append(bus)


func get_bus(bus_name: String) -> Bus:
	var buses = NUtils.merge_dict(core_buses, runtime_buses)
	return buses[bus_name]


func get_all_buses() -> Array:
	var buses = core_buses.values()
	buses.append_array(runtime_buses.values())
	return buses
