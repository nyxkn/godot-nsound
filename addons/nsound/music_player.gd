extends Node
class_name MusicPlayer

signal loop_beat(n)
signal beat(n)
signal bar(n)
signal barbeat(n)
signal odd_bar(n)
signal loop(n)
signal level(n)


const silence_ogg = preload("res://addons/nframework/assets/audio/silence-10m.ogg")


# process is the most simple and most independent. might not be the most accurate
# the other two are equally accurate. silence uses a custom silence track
# whereas song uses a stream from the loop
enum ReferenceMethod { SONG_STREAM, PROCESS, SILENCE }
const reference_method: int = ReferenceMethod.SILENCE



#const USE_REFERENCE_STREAM := true
var process_diffs := []

# progress counters
var bar: int
var beat: int # current beat in the bar
var loop_beat: int # current beat in the loop
var barbeat: float # current beat in float format
var loop: int

var last_beat: int

# song/section variables
# a section is a loop. start section and play loop are essentially the same things
# except that start section starts it the first time, and play loop reruns every loop

#var sections: Dictionary
var section: Section

# section-specific variables
var bpm: int
var beats_per_bar: int
var bars: int


# status
var playing: bool = false
var reference_stream_song: AudioStreamPlayer # track we use to get our time from
var reference_stream_silence: AudioStreamPlayer = AudioStreamPlayer.new()
var active_streams := []

var loop_time: float # current time in seconds within the reference track loop
var test_loop_time_delta: float

var loop_length: float
var beat_length: float
var section_beats: int

var level: int = 0 setget set_level
#var active_levels_tracks := []
var levels_tracks := []

var tracks_queue := []

#var stingers := {}
#var transitions := {}


func _ready() -> void:
	reference_stream_silence.stream = silence_ogg
	reference_stream_silence.volume_db = -80
	reference_stream_silence.bus = "Null"
	reference_stream_silence.name = "ReferenceStreamSilence"
	add_child(reference_stream_silence)


#func _input(event: InputEvent) -> void:
#	if event.is_action_pressed("ui_down"):
#		var layout = AudioServer.generate_bus_layout()
#		ResourceSaver.save("res://test/adaptive_music/saves/bus_layout.res", layout)
#		Log.d('saved bus layout', name)
#	if event.is_action_pressed("ui_right"):
#		var all_children = Utils.get_all_children(song)
#		for c in all_children:
#			# this is because if we own stream we'll end up with duplicated streams
#			if not c is AudioStreamPlayer:
#				c.owner = song
#		FileUtils.save_scene("res://test/adaptive_music/saves/", song, true)
#		Log.d('saved song', name)


#var test_diff
#var last_test_diff = 0
#var test_all_diffs = []
func _process(delta: float) -> void:
	if playing:
		match reference_method:
			ReferenceMethod.SONG_STREAM:
				if not reference_stream_song:
					Log.e("we don't have a reference stream. cannot play", name)
					playing = false
					return
				else:
					loop_time = reference_stream_song.get_playback_position()
			ReferenceMethod.PROCESS:
				loop_time += delta
			ReferenceMethod.SILENCE:
				loop_time = reference_stream_silence.get_playback_position()

		# peformance testing
		test_loop_time_delta += delta
		process_diffs.append(loop_time - test_loop_time_delta)


		# this starts at 0. helpful for math calculations
		var beat_progress = loop_time / beat_length

		var current_beat
		if is_equal_approx(beat_progress, section_beats):
			current_beat = int(round(beat_progress))
		else:
			current_beat = int(floor(beat_progress))

		# at this point we move beats to start from 1, because music
		# doing math with beat will typically require you to first subtract 1 to get back to 0
		loop_beat = current_beat + 1

		# anytime you do modulus calculations, you need to bring beats back to start on 0 instead of 1
		# these calculations could also just go in _beat and _bar respectively
		# but if you add them here they'll be updated with seeking
		beat = (loop_beat - 1) % beats_per_bar + 1
		bar = (loop_beat - 1) / beats_per_bar + 1

		if loop_beat != last_beat:
			_beat()
			last_beat = loop_beat

# ================================
# load and start of songs
# ================================
func ________LOAD_START_SONG(): pass


func load_song_section(song_node: Node, section_node: Section):
#	self.song = song_node
	# copy all exported song properties to here. for consistency
#	_copy_props_from(song)
	bpm = song_node.bpm
	beats_per_bar = song_node.beats_per_bar
	beat_length = 60.0 / bpm

	# -------

#	section = sections[section_name]
	self.section = section_node

#	_copy_props_from(section, true)
	bars = section.bars
	if section.beats_per_bar: beats_per_bar = section.beats_per_bar

	section_beats = bars * beats_per_bar
	match reference_method:
		ReferenceMethod.PROCESS, ReferenceMethod.SILENCE:
			loop_length = beat_length * section_beats

	Log.d(["loop length calculated as:", loop_length])

	_setup_buses(section_node)

	# initialize nodes
	levels_tracks.clear()
	for node in Utils.get_all_children(section_node):
		if node is LevelsTrack:
			levels_tracks.append(node)
			for child in node.get_children():
				if child is Bus:
					child.volume_db = Config.MIN_DB


func start():
	loop = 0
	last_beat = -1
	start_loop()


func start_loop() -> void:
	loop += 1
	bar = 1
	beat = 1
	loop_beat = 1

	loop_time = 0.0
	if reference_method == ReferenceMethod.SONG_STREAM:
		# reset the song stream so we can set it anew in play_track by using the first found track
		reference_stream_song = null

	# testing avg
	Log.d(["avg:", Math.avg(process_diffs)])
	process_diffs.clear()
	test_loop_time_delta = 0

	# stopping everything in case we are starting a new loop in the middle of previous loop
	stop_all_streams()
	tracks_queue.clear()

	# restart the silence stream
	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_silence.play()

#	for node in section.get_children():
#		play_track(node)
	play_track(section)

	# we only get song's reference stream after calling play_track
	if reference_method == ReferenceMethod.SONG_STREAM:
		loop_length = reference_stream_song.stream.get_length()

	playing = true


# ================================
# play tracks
# ================================
func ________PLAY_TRACKS(): pass

# recursive function to enable both multitracks and single audiostream
# you could also wrap audiostream in a custom track class where you can define things
func play_track(track: Bus):
	if track.disabled:
		return

	if track is AudioTrack:
		play_audiotrack(track)
		if reference_method == ReferenceMethod.SONG_STREAM and not reference_stream_song:
			reference_stream_song = track.stream
			Log.d(["set reference stream to", track], name)

	elif track is Section:
		for subtrack in track.get_children():
			play_track(subtrack)
	# if we're dealing with levels tracks, simply play all tracks
	elif track is LevelsContainer:
		for subtrack in track.get_children():
			play_track(subtrack)
	elif track is LevelsTrack:
		for subtrack in track.get_children():
			play_track(subtrack)


	elif track is SegmentsTrack:
		for segment in track.timeline:
			var target_beat = _barbeat_to_loop_beat(track.timeline[segment])
			queue_track_on_beat(target_beat, track.get_node(segment))
		# version for array timeline
#		for i in track.timeline.size():
#			var target_beat = _barbeat_to_loop_beat(track.timeline[i])
#			queue_track_on_beat(target_beat, track.get_child(i))

	elif track is MultiTrack:
		var sub_track = track.get_next_track()
		Log.d(["multi-track", track, "now playing", sub_track], name)
		play_track(sub_track)


func play_audiotrack(track: AudioTrack):
	track.play()
	active_streams.append(track.stream)


func seek(to_position: float) -> void:
	Log.d(["seeking to", to_position])
	loop_time = to_position
	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_silence.seek(to_position)
	for stream in active_streams:
		stream.seek(to_position)


func seek_to_barbeat(barbeat: float) -> void:
	var to_position = _barbeat_to_loop_beat(barbeat) * beat_length
	seek(to_position)


func stop_all_streams() -> void:
	for stream in active_streams:
		if _is_stream_stinger(stream):
			Log.d(["not stopping stinger", stream])
		else:
			stream.stop()
	active_streams.clear()


func stop() -> void:
	stop_all_streams()
	playing = false


# ================================
# adaptive management
# ================================
func ________LEVELS(): pass


func set_level(value: int, when: int = Music.When.ODD_BAR) -> void:
	level = value
	Log.d(["set level", value])

	for levels_track in levels_tracks:
		if levels_track.get_child_count() == 0:
			continue

		# fetch the highest level track that fits under current level
		var highest_track: String
		for i in range(level, 0, -1):
			var find_res = levels_track.levels.values().find(i)
			if find_res != -1:
				highest_track = levels_track.levels.keys()[find_res]
				break

		# did we find a track to play?
		var selected_track: Bus = null
		if highest_track:
			selected_track = levels_track.get_node(highest_track)
#			Log.d(["fade in", selected_track])
			fade_in(selected_track, when)


		for track in levels_track.get_children():
			if track != selected_track:
#				Log.d(["fade out", track])
				fade_out(track, when)


	emit_signal("level", value)



# ================================
# queues / transitions
# ================================
func ________QUEUE_TRANSITIONS(): pass





# this plays a track that can be started at any time within the loop
func queue_track_on_beat(on_beat: int, track: Bus):
	tracks_queue.append([on_beat, track])


func determine_fade_duration(when: int) -> float:
	var duration: float
	match when:
		Music.When.NOW:
			duration = 0.0
		Music.When.BEAT:
			duration = beat_length * 0.5
		Music.When.BAR:
			duration = beat_length * (beats_per_bar / 2)
		Music.When.ODD_BAR:
			duration = beat_length * beats_per_bar

	return duration


func wait_until(when: int) -> void:
	match when:
		Music.When.NOW:
			# hack. we need to wait at least one frame for yield to register
			yield(get_tree(), "idle_frame")
		Music.When.BEAT:
			yield(self, "beat")
		Music.When.BAR:
			yield(self, "bar")
		Music.When.ODD_BAR:
			yield(self, "odd_bar")
		Music.When.LOOP:
			yield(self, "loop")

	return


func fade_in(track: Bus, when: int = Music.When.ODD_BAR, duration: float = -1) -> void:
	var dur = duration
	if dur == -1:
		dur = determine_fade_duration(when)

	if dur == 0:
		# if we were ordered to fade while we weren't playing, just set the new level directly
		# this is so set_level works before starting the play
		# TODO might have to move this to set_level if this here creates unforseen issues
		track.volume_db = 0
		return
	else:
		yield(wait_until(when), "completed")
		track.fade(null, null, dur)
		Log.d(["fading in track", track, "duration", dur])


func fade_out(track: Bus, when: int = Music.When.ODD_BAR, duration: float = -1) -> void:
	var dur = duration
	if dur == -1:
		dur = determine_fade_duration(when)

	if dur == 0:
		track.volume_db = Config.MIN_DB
		return
	else:
		yield(wait_until(when), "completed")
		track.fade(null, Config.MIN_DB, dur)
		Log.d(["fading out track", track])




# ================================
# private functions / util
# ================================
func ________PRIVATE_UTIL(): pass


func _copy_props_from(node: Node, if_not_zero = false) -> void:
	var props = node.get_property_list()
	for prop in props:
		if prop.usage == (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_DEFAULT):
			if if_not_zero:
				if node.get(prop.name) != 0:
					set(prop.name, node.get(prop.name))
			else:
				set(prop.name, node.get(prop.name))


func _setup_buses(node: Bus) -> void:
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


#func _get_all_tracks(node: Node) -> Array:
#	var streams := []
#
#	for n in node.get_children():
#		if n is AudioTrack:
#			streams.append(n)
#		elif n.get_child_count() > 0:
#			streams.append_array(_get_all_tracks(n))
#
#	return streams


func _barbeat_to_loop_beat(beat_float: float):
	var integer = int(beat_float) # bar
	var bar_portion = integer

	var fractional = beat_float - integer # beat
	var s = str(fractional).trim_prefix("0.")
	var beat_portion = int(s)

	return (bar_portion-1) * beats_per_bar + (beat_portion-1)


func _get_barbeat(bar: int, beat: int) -> float:
	# this is actually surprisingly (very slightly) faster than doing bar + beat * 0.1
	var bb = float(str(bar, ".", beat))
	return bb



func _is_stream_stinger(node: Node) -> bool:
	if node is StingersContainer:
		return true
	elif node is Song:
		return false
	else:
		return _is_stream_stinger(node.get_parent())


# ================================
# on signals
# ================================
func ________SIGNALS(): pass


func _beat() -> void:
	# signals should happen from largest section to smallest
	# loop signals first, then bar, then beat
	if loop_beat > section_beats:
		# this restarts the loop as well so it resets the numbers correctly
		# so that the signal we emit at the end is beat 1
		_loop_end()

	# anytime you do modulus calculations, you need to bring beats back to start on 0 instead of 1
#	beat = (loop_beat - 1) % beats_per_bar + 1
#	bar = (loop_beat - 1) / beats_per_bar + 1

	if beat == 1:
		_bar()

	for t in tracks_queue:
		if loop_beat == t[0]:
#			Log.d(["playing queued track", t[1]], name)
			play_track(t[1])

	barbeat = _get_barbeat(bar, beat)

	emit_signal("loop_beat", loop_beat)
	emit_signal("beat", beat)
	emit_signal("barbeat", barbeat)


func _bar() -> void:
#	bar = (loop_beat - 1) / beats_per_bar + 1
	emit_signal("bar", bar)
	if bar % 2 == 1:
		emit_signal("odd_bar", bar)


func _loop_end() -> void:
	start_loop()
	emit_signal("loop", loop)

