extends PanelContainer

var Log = preload("res://addons/nsound/logger.gd").new(self)

var bus: Bus
var channel: Dictionary = { "peak_l": -100, "peak_r": -100 }

@onready var user_volume_slider: VSlider = get_node("%UserVolumeSlider")
@onready var auto_volume_slider: VSlider = get_node("%AutoVolumeSlider")
@onready var spinbox: SpinBox = get_node("%SpinBox")
@onready var vu_l: TextureProgressBar = get_node("%VuL")
@onready var vu_r: TextureProgressBar = get_node("%VuR")
@onready var effects: Tree = $"%Effects"
#onready var substrips = $"%Substrips"
@onready var substrips = get_node("%Substrips")


func init(bus: Bus) -> Node:
#	print('initing strip with bus', str(bus))

	self.bus = bus

	get_node("%ShowFold").visible = false

	get_node("%BusName").text = bus.name
	get_node("%SendName").text = bus.send

	if bus is AudioServerBus:
		get_node("%AudioServerBusName").text = str(bus.bus_name)
		get_node("%Progress").hide()
	elif bus is AudioTrack:
		get_node("%AudioServerBusName").hide()
		get_node("%VuMeter").hide()
		get_node("%Effects").hide()
		$"%Time".text = "%.1f" % bus.stream_player.get_playback_position()
		$"%TotalTime".text = "%.1f" % bus.stream_player.stream.get_length() + "s"

	return self


func _ready() -> void:
#	assert(bus, "bus wasn't initialized")
	if not bus:
		Log.e(["bus", name, "wasn't initialized"])
		return

	bus.user_volume_changed.connect(on_user_volume_changed)
	bus.auto_volume_changed.connect(on_auto_volume_changed)

#	set_process(false)
#	if bus is AudioServerBus:
#		set_process(true)

	on_user_volume_changed(bus.user_volume_db)
	on_auto_volume_changed(bus.auto_volume_db)

	if bus is AudioServerBus:
		var bus_effects = bus.get_effects()

		var root: TreeItem = effects.create_item()
		for i in bus_effects.size():
			var afx: AudioEffect = bus_effects[i]
			var fx: TreeItem = effects.create_item(root)
			fx.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			fx.set_editable(0, true)
			fx.set_checked(0, bus.is_effect_enabled(i))
			fx.set_text(0, afx.resource_name)
			fx.set_metadata(0, i)


func _process(delta: float) -> void:
#	if not is_instance_valid(bus):
#		return

#	if bus.bus_idx == -1:
#		return

	if bus is AudioServerBus and bus.bus_idx != -1:
		var real_peak = [-100, -100]

		var cc = AudioServer.get_bus_channels(bus.bus_idx)

		real_peak[0] = max(real_peak[0], AudioServer.get_bus_peak_volume_left_db(bus.bus_idx, 0))
		real_peak[1] = max(real_peak[1], AudioServer.get_bus_peak_volume_right_db(bus.bus_idx, 0))

		if real_peak[0] > channel.peak_l:
			channel.peak_l = real_peak[0]
		else:
			channel.peak_l -= delta * 60.0

		if real_peak[1] > channel.peak_r:
			channel.peak_r = real_peak[1]
		else:
			channel.peak_r -= delta * 60.0

		vu_l.value = channel.peak_l
		vu_r.value = channel.peak_r

	elif bus is AudioTrack:
		var is_playing = bus.is_playing()
		$"%Icons".get_node("Play").visible = is_playing
		$"%Icons".get_node("Pause").visible = not is_playing

		if is_playing:
			var time = bus.stream_player.get_playback_position()
			$"%Time".text = "%.1f" % time
			$"%ProgressBar".value = inverse_lerp(0, bus.stream_player.stream.get_length(), time)


func add_substrip(strip: Node):
	substrips.add_child(strip)
	get_node("%ShowFold").visible = true


func on_user_volume_changed(db):
	spinbox.value = db
	var norm = _scaled_db_to_normalized_volume(db)
	user_volume_slider.value = norm


func on_auto_volume_changed(db):
	var norm = _scaled_db_to_normalized_volume(db)
	auto_volume_slider.value = norm


# using drag ended instead of value changed because this one gets called from code as well
func _on_UserVolumeSlider_value_changed(value: float) -> void:
	pass
#	var db = _normalized_volume_to_scaled_db(value)
#	spinbox.value = db
#	bus.user_volume_db = db


func _on_AutoVolumeSlider_value_changed(value: float) -> void:
	pass
#	var db = _normalized_volume_to_scaled_db(value)
#	bus.auto_volume_db = db


func _on_UserVolumeSlider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		var value = user_volume_slider.value
		var db = _normalized_volume_to_scaled_db(value)
		spinbox.value = db
		bus.user_volume_db = db


func _on_AutoVolumeSlider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		var value = user_volume_slider.value
		var db = _normalized_volume_to_scaled_db(value)
		bus.auto_volume_db = db


func _on_Solo_toggled(button_pressed: bool) -> void:
	bus.solo = button_pressed


func _on_Mute_toggled(button_pressed: bool) -> void:
	bus.mute = button_pressed


func _on_Bypass_toggled(button_pressed: bool) -> void:
	pass


# these two functions are lifted verbatim from editor_audio_buses.cpp
# can't really say i understand what's going on
func _normalized_volume_to_scaled_db(normalized: float) -> float:
	if normalized > 0.6:
		return 22.22 * normalized - 16.2
	elif normalized < 0.05:
		return 830.72 * normalized - 80.0
	else:
		return 45.0 * pow(normalized - 1.0, 3)


func _scaled_db_to_normalized_volume(db: float) -> float:
	if db > -2.88:
		return (db + 16.2) / 22.22
	elif db < -38.602:
		return (db + 80.00) / 830.72
	else:
		if db < 0.0:
			var positive_x: float = pow(abs(db) / 45.0, 1.0 / 3.0) + 1.0
			var position: Vector2 = Vector2(1.0, 0.0) - Vector2(positive_x, abs(db))
			var reflected_position: Vector2 = Vector2(1.0, 0.0) + position
			return reflected_position.x
		else:
			return pow(db / 45.0, 1.0 / 3.0) + 1.0



