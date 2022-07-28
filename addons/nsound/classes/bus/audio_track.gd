extends Bus
class_name AudioTrack, "res://addons/nsound/assets/icons/godot/AudioStreamPlayer.svg"


export(bool) var loop := false

var stream: AudioStreamPlayer


func _ready() -> void:
#	stream = get_node_or_null("Stream")
	# pick the first audiostreamplayer
	for child in get_children():
		if child is AudioStreamPlayer:
			stream = child
			break

	if not stream:
		Log.w(["bus", name, "has no audiostream"], name)
		return

	stream.connect("finished", self, "_stream_finished")


func init(send_bus_name: String = "Master") -> Bus:
	self.send = send_bus_name
	Audio.register_track(self)
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


func _stream_finished() -> void:
	if loop:
		play()
