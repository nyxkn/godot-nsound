extends Bus
class_name AudioServerBus

# identifies which audioserver bus we're encapsulating. same as the audioserver bus idx
# note: this is not a reliable index. if a previous index bus is removed, all will be shifted down
# you should use bus_name instead as your unique id, and fetch bus_idx everytime you need it
var bus_idx: int = -1

# name is not unique. this is just the name in the scene editor
# bus_name is unique. this is the name of the bus registered in the AudioServer
# which is guaranteed to be unique (numbers get added)
var bus_name: String


# wrap is to initialize this not from scratch but as a wrapper around an already
# existing audioserver bus
# use init instead to create a new audioserver bus
func wrap(audio_server_bus_name: String = "Master") -> void:
	assert(bus_idx == -1, "bus " + str(self) + " is already initialized")

	var idx = AudioServer.get_bus_index(audio_server_bus_name)
	if idx >= 0:
		bus_idx = idx
		bus_name = audio_server_bus_name
		# setting bus_send without calling the setter (we don't need to write to audioserver again)
		send = AudioServer.get_bus_send(bus_idx)
	else:
		Log.e(["bus named", bus_name, "does not exist"])


# we have to initialize buses manually from top to bottom
# if they get initialized in _ready it happens from bottom to top
# and that's a problem because sends only work from right to left
# so in bottom to top initialization, the deepest children end up on the left of the audio mixer
# and that way they cannot send properly to their parents who will spawn on their right
func init(send_bus_name: String = "Master") -> Bus:
	assert(bus_idx == -1, "bus " + str(self) + " is already initialized")

	register()

	# must happen after bus initialization
	self.send = send_bus_name

	Log.d(["bus", bus_name, "was initialized with id", bus_idx])

	return self


func on_bus_layout_changed() -> void:
	# reobtaining the correct index after a layout change
	# should we rather just use bus_name?
	bus_idx = AudioServer.get_bus_index(bus_name)


# this is guaranteed to always return the correct index
func idx() -> int:
	return AudioServer.get_bus_index(bus_name)


func register() -> void:
	assert(bus_idx == -1, "trying to register an already initialized bus")

	AudioServer.add_bus()
	bus_idx = AudioServer.bus_count - 1

	# here we try to set audioserver bus name to our node name
	# but since our node name is not guaranteed to be unique, and audioserver wants unique names
	# we store the actual audioserver bus_name as well, auto-unique-ified by audioserver
#	if not name: name = "Bus"
	AudioServer.set_bus_name(bus_idx, name)
	bus_name = AudioServer.get_bus_name(bus_idx)

	NAudio.register_bus(self)

	AudioServer.connect("bus_layout_changed", self, "on_bus_layout_changed")


func unregister() -> void:
	AudioServer.remove_bus(bus_idx)
	bus_idx = -1

#	NAudio.unregister_bus(self)

	AudioServer.disconnect("bus_layout_changed", self, "on_bus_layout_changed")


func set_volume_db(value: float) -> void:
	if bus_idx == -1:
		Log.w(["bus", name, "isn't initialized"])
		return

	AudioServer.set_bus_volume_db(bus_idx, value)
	.set_volume_db(value)


func set_send(value: String) -> void:
	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")
#	if bus_idx == -1:
#		Log.e(["bus", name, "isn't initialized"])
#		return

	AudioServer.set_bus_send(bus_idx, value)
	.set_send(value)


#func get_bus_send() -> String:
#	# we had some issues with the program stopping here and giving very vague error messages
##	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")
##	if bus_idx == -1:
##		print("bus is uninitialized")
##		return ""
#
#	assert(bus_send == AudioServer.get_bus_send(bus_idx),
#			"bus" + name + "has a bus_send value out of sync with AudioServer")
#	return bus_send


func set_mute(value: bool) -> void:
	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")
	AudioServer.set_bus_mute(bus_idx, value)
	.set_mute(value)


#func set_solo(value: bool) -> void:
#	AudioServer.set_bus_solo(bus_idx, value)
#	solo = value


# --------------------------------
# audioserver specific


func add_effect(effect: AudioEffect):
	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")
	AudioServer.add_bus_effect(bus_idx, effect)
#	var effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1


func get_effect(effect_idx: int) -> AudioEffect:
	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")
	return AudioServer.get_bus_effect(bus_idx, effect_idx)


func get_effects() -> Array:
	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")

	var effects := []
	var effect_count = AudioServer.get_bus_effect_count(bus_idx)
	effects.resize(effect_count)

	for i in range(effect_count):
		effects[i] = get_effect(i)
	return effects


func is_effect_enabled(effect_idx: int) -> bool:
	assert(bus_idx != -1, "bus " + str(self) + " isn't initialized")
	return AudioServer.is_bus_effect_enabled(bus_idx, effect_idx)
