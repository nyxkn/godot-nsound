extends Node
class_name MusicPlayer

signal loop_beat(n)
signal beat(n)
signal bar(n)
signal barbeat(n)
signal odd_bar(n)
signal loop(n)
signal level(n)

signal end(song, section)

signal faded_in(track)
signal faded_out(track)


const silence_ogg = preload("res://addons/nsound/assets/audio/silence-10m.ogg")


# process is the most simple and most independent. might not be the most accurate
# the other two are equally accurate. silence uses a custom silence track
# whereas song uses a stream from the loop
enum ReferenceMethod { SONG_STREAM, PROCESS, SILENCE }
# set the default. although we can force override this in code later
# that is if bars value is not provided,
# we can still attempt to loop the audio by using the song stream
var reference_method: int = ReferenceMethod.SILENCE



#const USE_REFERENCE_STREAM := true
var process_diffs := []

# progress counters
#var bar: int
#var beat: int # current beat in the bar
var loop_beat: int # current beat in the loop
var bbt: BBT = BBT.new() # current beat in float format
var loop: int

var last_beat: int

# song/section variables
# a section is a loop. start section and play loop are essentially the same things
# except that start section starts it the first time, and play loop reruns every loop

#var sections: Dictionary
var song: Song
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

var level: int = 1 setget set_level
#var active_levels_tracks := []
var levels_tracks := []

var tracks_queue := []

var last_seek_time := 0

var looping_regions := {}

# the loop-beat at which we'll be transitioning away from this track
# useful to plan things ahead. specifically avoid playing tracks that were queued for this beat
var transition_beat := -1

#var stingers := {}
#var transitions := {}


func _ready() -> void:
	reference_stream_silence.stream = silence_ogg
	reference_stream_silence.volume_db = -80
	reference_stream_silence.bus = "Null"
	reference_stream_silence.name = "ReferenceStreamSilence"
	add_child(reference_stream_silence)


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
		bbt.beat = (loop_beat - 1) % beats_per_bar + 1
		bbt.bar = (loop_beat - 1) / beats_per_bar + 1

		if loop_beat != last_beat:
			_beat()
			last_beat = loop_beat

# ================================
# load and start of songs
# ================================
func ________LOAD_START_SONG(): pass


func load_song_section(song_node: Node, section_node: Section):
	song = song_node
	section = section_node

	# from song
#	_copy_props_from(song)
	bpm = song.bpm
	beats_per_bar = song.beats_per_bar

	# from section
#	_copy_props_from(section, true)
	bars = section.bars
	if section.bpm: bpm = section.bpm
	if section.beats_per_bar: beats_per_bar = section.beats_per_bar

	if bpm == 0:
		Log.e(["missing bpm value for song/section", section])
		assert(1 == 2)
	if beats_per_bar == 0:
		Log.e(["missing beats_per_bar value for song/section", section])
		assert(1 == 2)
	if bars == 0:
		Log.w(["missing bars value for song/section, attempting to autocalculate", section])
		# attempting to autocalculate bars
		var first_audiotrack = section.get_child(0)
		if not first_audiotrack is AudioTrack:
			Log.e(["failed to calculate bars value. input manually"])
			assert(1 == 2)
		var beats_in_track = (bpm / 60.0) * first_audiotrack.stream.stream.get_length()
		bars = round(beats_in_track / beats_per_bar)
		Log.i(["autocalculated bars for section", section.name, "to", bars])

	beat_length = 60.0 / bpm

	section_beats = bars * beats_per_bar
	match reference_method:
		ReferenceMethod.PROCESS, ReferenceMethod.SILENCE:
			loop_length = beat_length * section_beats

	Log.d(["loop length for section", section.name, "calculated as:", loop_length, "s"])

	for r in section.regions:
		section.regions[r]._section = section
		if section.regions[r].loop == true:
			looping_regions[r] = section.regions[r]

	NUtils.setup_buses(section_node)

	# initialize nodes
	levels_tracks.clear()
	for node in NUtils.get_all_children(section_node):
		if node is LevelsTrack:
			levels_tracks.append(node)
			for child in node.get_children():
				if child is Bus:
					child.volume_db = Music.MIN_DB


func start():
	loop = 0
	last_beat = -1
	transition_beat = -1
	start_loop()


func start_loop() -> void:
	loop += 1
	bbt.bar = 1
	bbt.beat = 1
	loop_beat = 1

	loop_time = 0.0
	if reference_method == ReferenceMethod.SONG_STREAM:
		# reset the song stream so we can set it anew in play_track by using the first found track
		reference_stream_song = null

	# testing avg
#	Log.d(["avg:", Math.avg(process_diffs)])
	process_diffs.clear()
	test_loop_time_delta = 0

	# stopping everything in case we are starting a new loop in the middle of previous loop
	stop_all_streams()
	tracks_queue.clear()

	# restart the silence stream
	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_silence.play()

	set_level(level)

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
			var bbt = BBT.new().from_float(track.timeline[segment])
			var target_beat = _bbt_to_loop_beat(bbt)
			queue_track_on_beat(target_beat, track.get_node(segment))
		# version for array timeline
#		for i in track.timeline.size():
#			var target_beat = _bbt_to_loop_beat(track.timeline[i])
#			queue_track_on_beat(target_beat, track.get_child(i))

	elif track is MultiTrack:
		var sub_track = track.get_next_track()
		Log.d(["multi-track", track, "now playing", sub_track], name)
		play_track(sub_track)


func play_audiotrack(track: AudioTrack):
	track.play()
	active_streams.append(track.stream)


func seek(to_position: float) -> void:
	Log.d(["seeking to time:", to_position, "s"], name)
	loop_time = to_position

	if OS.get_ticks_msec() < last_seek_time + 10:
		Log.w(["seeking too quickly. ignoring seek."], name)
		return

	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_silence.seek(to_position)
	for stream in active_streams:
		stream.seek(to_position)

	last_seek_time = OS.get_ticks_msec()


func seek_to_bbt(bbt: BBT) -> void:
	var to_position = _bbt_to_loop_beat(bbt) * beat_length
	seek(to_position)


func seek_to_barbeat(barbeat: float) -> void:
	var bbt = BBT.new().from_float(barbeat)
	seek_to_bbt(bbt)


func stop_all_streams() -> void:
	for stream in active_streams:
#		print(stream.name)
		if _is_stream_stinger(stream):
			Log.d(["not stopping stinger", stream])
		else:
			stream.stop()

	# WARN: it is possible for streams not to have stopped properly
	# e.g. if you call stop() on the same frame as play(), stop will fail
	# nonetheless, it's somewhat hard to check whether the stream has truly stopped
	active_streams.clear()

#	yield(get_tree(), "idle_frame")

#	var streams_still_playing = []
#	for stream in active_streams:
#		if stream.playing:
#			Log.e(["failed to stop stream", stream])
#			streams_still_playing.append(stream)
#
#	active_streams = streams_still_playing


func stop() -> void:
	stop_all_streams()
	playing = false


# ================================
# adaptive management
# ================================
func ________LEVELS(): pass


func set_level(value: int, when: int = Music.When.ODD_BAR) -> void:
	level = value
#	Log.d(["set level", value])

	for levels_track in levels_tracks:
		# if levels_track has no children, skip
		if levels_track.get_child_count() == 0:
			continue

		match levels_track.layer_mode:

			LevelsTrack.LayerMode.SINGLE:
				# fetch the highest level track that fits under current level
				var highest_track: String
				for i in range(level, 0, -1):
					var levels_track_idx = levels_track.levels.values().find(i)
					if levels_track_idx != -1:
						highest_track = levels_track.levels.keys()[levels_track_idx]
						break

				# did we find a track to play?
				var selected_track: Bus = null
				if highest_track:
					selected_track = levels_track.get_node(highest_track)
#					Log.d(["fade in", selected_track])
					fade_in(selected_track, when)

				for track in levels_track.get_children():
					if track != selected_track:
#						Log.d(["fade out", track])
						fade_out(track, when)

			LevelsTrack.LayerMode.ADD:
				for track_name in levels_track.levels:
					var track_level = levels_track.levels[track_name]
					if track_level <= level:
						fade_in(levels_track.get_node(track_name))
					else:
						fade_out(levels_track.get_node(track_name))
#				if highest_track:
#					for track_name in levels_track.levels:
#						fade_in(levels_track.get_node(track_name))
#						if track_name == highest_track:
#							break





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


func determine_transition_beat(when: int, transition_bars):
	match when:
		Music.When.NOW:
			transition_beat = loop_beat
		Music.When.BEAT:
			transition_beat = loop_beat + 1
		Music.When.BAR:
			transition_beat = bbt.bar * beats_per_bar + 1
		Music.When.ODD_BAR:
			transition_beat = (bbt.bar + (bbt.bar % 2)) * beats_per_bar + 1
		Music.When.LOOP:
			transition_beat = 0

	transition_beat += beats_per_bar * transition_bars

	# wrapping around total
	var loop_beats = beats_per_bar * bars
	transition_beat = transition_beat % loop_beats


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
#		Log.d(["fading in track", track, "duration", dur])

	yield(get_tree().create_timer(dur), "timeout")
	emit_signal("faded_in", track)


func fade_out(track: Bus, when: int = Music.When.ODD_BAR, duration: float = -1) -> void:
	var dur = duration
	if dur == -1:
		dur = determine_fade_duration(when)

	if dur == 0:
		track.volume_db = Music.MIN_DB
		return
	else:
		yield(wait_until(when), "completed")
		track.fade(null, Music.MIN_DB, dur)
#		Log.d(["fading out track", track])

	yield(get_tree().create_timer(dur), "timeout")
	emit_signal("faded_out", track)



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



func _bbt_to_loop_beat(bbt: BBT):
	return (bbt.bar-1) * beats_per_bar + (bbt.beat)


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

	var barbeat = bbt.to_float()

	# this code should run before emitting signals
	# just to be sure it runs on time (code run on signals could take a long time)
	for t in tracks_queue:
		if loop_beat == t[0]:
			if loop_beat == transition_beat:
				Log.d(["skipping playing of track", t[1], "because it falls on transition beat"], name)
			else:
				Log.d(["playing queued track", t[1]], name)
				play_audiotrack(t[1])

	for k in looping_regions:
		var region: Region = looping_regions[k]
		var end_bbt = BBT.new().from_float(region.end)
		if barbeat == end_bbt.to_float():
			seek_to_barbeat(region.start)



	if bbt.beat == 1:
		_bar()

	emit_signal("loop_beat", loop_beat)
	emit_signal("beat", bbt.beat)
	emit_signal("barbeat", barbeat)



func _bar() -> void:
#	bar = (loop_beat - 1) / beats_per_bar + 1
	emit_signal("bar", bbt.bar)
	if bbt.bar % 2 == 1:
		emit_signal("odd_bar", bbt.bar)


func _loop_end() -> void:
	if section.play_mode == Section.PlayMode.LOOP:
		start_loop()
		emit_signal("loop", loop)
	else:
		# we have to at least set playing=false so that processing stops
		stop()
		emit_signal("end", song.name, section.name)

