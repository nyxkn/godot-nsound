extends Bus
class_name AudioTrack, "res://addons/nsound/assets/icons/godot/AudioStreamPlayer.svg"

export(bool) var loop := false

var stream: AudioStreamPlayer

#var seamless_fade_dur := 0.01
#var seamless_fading := false


func _ready() -> void:
#	stream = get_node_or_null("Stream")
	# pick the first audiostreamplayer
	for child in get_children():
		if child is AudioStreamPlayer:
			stream = child
			break

	if not stream:
		Log.w(["bus", name, "has no audiostream"])
		return

	stream.connect("finished", self, "_stream_finished")


#func _process(delta: float) -> void:
#	if loop and not seamless_fading:
#		if stream.get_playback_position() >= stream.stream.get_length() - seamless_fade_dur * 2:
#			seamless_fading = true
#			print('seamless looping fadeout')
#			fade(null, -80, seamless_fade_dur, 0.0)


func init(send_bus_name: String = "Master") -> Bus:
	stream.name = name
	self.send = send_bus_name
	NAudio.register_track(self)
	return self


func play():
	if stream:
		stream.play()
	else:
		# should we warn about this?
		# a silence track without stream is valid
		Log.w(["trying to play track", name, ", but it has no stream"])


func is_playing() -> bool:
	return stream.playing


func set_volume_db(value: float) -> void:
	if not stream: return

	stream.volume_db = value
	.set_volume_db(value)


func set_send(value: String) -> void:
	if not stream: return

	stream.bus = value
	.set_send(value)


func set_mute(value: bool) -> void:
	if not stream: return

	if value:
		stream.volume_db = Music.MIN_DB
	else:
		stream.volume_db = volume_db
	.set_mute(value)


#func set_solo(value: bool) -> void:
#	AudioServer.set_bus_solo(bus_idx, value)
#	solo = value


func _stream_finished() -> void:
	if loop:
		play()
#		if seamless_fading:
#			print('seamless looping fadein')
#			fade(null, 0.0, seamless_fade_dur, 0.0)
#			seamless_fading = false
