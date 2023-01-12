extends Bus
class_name AudioTrack, "res://addons/nsound/assets/icons/godot/AudioStreamPlayer.svg"

# this is a bus that does not make use of a godot audioserver
# it interacts with audiostream directly


const Utils = preload("res://addons/nsound/utils.gd")

export(bool) var loop := false
export(AudioStream) var audio_file: AudioStream

var stream_player: AudioStreamPlayer

#var seamless_fade_dur := 0.01
#var seamless_fading := false


func _ready() -> void:
#	stream_player = get_node_or_null("Stream")
	# pick the first audiostreamplayer
	for child in get_children():
		if child is AudioStreamPlayer:
			stream_player = child
			break

# create the stream player child loaded with the audio file
	if not stream_player:
		if audio_file:
			stream_player = AudioStreamPlayer.new()
			stream_player.stream = audio_file

			add_child(stream_player)
		else:
			Log.w(["bus", name, "has no audiostream"])
			return

#	print(Utils.get_filename(stream_player.stream.resource_path))
	stream_player.name = Utils.get_filename(stream_player.stream.resource_path).replace(".", "_")

	stream_player.connect("finished", self, "_stream_player_finished")


#func _process(delta: float) -> void:
#	if loop and not seamless_fading:
#		if stream_player.get_playback_position() >= stream_player.stream.get_length() - seamless_fade_dur * 2:
#			seamless_fading = true
#			print('seamless looping fadeout')
#			fade(null, -80, seamless_fade_dur, 0.0)


func init(send_bus_name: String = "Master") -> Bus:
#	if not stream_player.name:
#		stream_player.name = name
	self.send = send_bus_name
	NSound.register_track(self)
	return self


func play():
	if stream_player:
		stream_player.play()
	else:
		# should we warn about this?
		# a silence track without stream is valid
		Log.w(["trying to play track", name, ", but it has no stream"])


func is_playing() -> bool:
	return stream_player.playing


func set_volume_db(value: float) -> void:
	if not stream_player: return

	stream_player.volume_db = value
	.set_volume_db(value)


func set_send(value: String) -> void:
	if not stream_player: return

	stream_player.bus = value
	.set_send(value)


func set_mute(value: bool) -> void:
	if not stream_player: return

	if value:
#		stream_player.volume_db = NDef.MIN_DB
		self.auto_volume_db = NDef.MIN_DB
	else:
#		stream_player.volume_db = _volume_db
		self.auto_volume_db = 0.0
	.set_mute(value)


#func set_solo(value: bool) -> void:
#	AudioServer.set_bus_solo(bus_idx, value)
#	solo = value


func _stream_player_finished() -> void:
	if loop:
		play()
#		if seamless_fading:
#			print('seamless looping fadein')
#			fade(null, 0.0, seamless_fade_dur, 0.0)
#			seamless_fading = false
