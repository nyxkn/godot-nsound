extends Node

var Log = preload("res://addons/nsound/logger.gd").new(self)
const Utils = preload("res://addons/nsound/utils.gd")
#const BBT = preload("res://addons/nsound/classes/bbt.gd")

signal loop_beat_signal(n: int)
signal beat(n: int)
signal bar(n: int)
signal barbeat_signal(n: float)
signal odd_bar(n: int)
signal loop_signal(n: int)
signal level_signal(n: int)

signal end_signal(song: Song, section: Section)

signal faded_in(track: Bus)
signal faded_out(track: Bus)


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


# state
var playing: bool = false
var reference_stream_player_song: AudioStreamPlayer # track we use to get our time from
var reference_stream_player_silence: AudioStreamPlayer = AudioStreamPlayer.new()
var active_stream_players := []

var loop_time: float # current time in seconds within the reference track loop
var test_loop_time_delta: float

var loop_length: float
var beat_length: float
var section_beats: int

# https://github.com/godotengine/godot/issues/74144#issuecomment-1607602901
# workaround. setters cannot take extra arguments. might be fixed in the future
var _level: int = 1
var level: int:
	get: return _level
	set(v): set_level(v)

#var active_levels_tracks := []
var levels_tracks := []
var max_level := 0

var tracks_queue := []

var last_seek_time := 0

var looping_regions := {}

# the loop-beat at which we'll be transitioning away from this track
# useful to plan things ahead. specifically avoid playing tracks that were queued for this beat
var transition_beat := -1

#var stingers := {}
#var transitions := {}

var waiting := false
var wait_id := 0


func _ready() -> void:
	reference_stream_player_silence.stream = silence_ogg
	reference_stream_player_silence.volume_db = -80
	reference_stream_player_silence.bus = "Null"
	reference_stream_player_silence.name = "ReferenceStreamSilence"
	add_child(reference_stream_player_silence)


#var test_diff
#var last_test_diff = 0
#var test_all_diffs = []
func _process(delta: float) -> void:
	if playing:
		match reference_method:
			ReferenceMethod.SONG_STREAM:
				if not reference_stream_player_song:
					Log.e("we don't have a reference stream_player. cannot play")
					playing = false
					return
				else:
					loop_time = reference_stream_player_song.get_playback_position()
			ReferenceMethod.PROCESS:
				loop_time += delta
			ReferenceMethod.SILENCE:
				loop_time = reference_stream_player_silence.get_playback_position()

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
		var beats_in_track = (bpm / 60.0) * first_audiotrack.stream_player.stream.get_length()
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

	NSound.setup_buses(section_node)

	# initialize nodes
	max_level = 0
	levels_tracks.clear()
	for node in Utils.get_all_children(section_node):
		if node is LevelsTrack:
			levels_tracks.append(node)
			for l in node.levels.values():
				if l > max_level:
					max_level = l
#			for child in node.get_children():
#				if child is Bus:
#					child.volume_db = NDef.MIN_DB


func start():
	Log.d(["section started", section.name])
	loop = 0
	last_beat = -1
	transition_beat = -1
	start_loop()
	set_level(level, NDef.When.NOW)


func start_loop() -> void:
	# stopping is probably unneeded?
#	if stopping:
#		Log.d(["won't start next loop because stopping", section.name])
#		# but we still need to have music_player call stop to make sure
#		return

	Log.d(["loop started", section.name])
	loop += 1
	bbt.bar = 1
	bbt.beat = 1
	loop_beat = 1

	loop_time = 0.0
	if reference_method == ReferenceMethod.SONG_STREAM:
		# reset the song stream so we can set it anew in play_track by using the first found track
		reference_stream_player_song = null

	# testing avg
#	Log.d(["avg:", Math.avg(process_diffs)])
	process_diffs.clear()
	test_loop_time_delta = 0

	# stopping everything in case we are starting a new loop in the middle of previous loop
	stop_all_streams()
	tracks_queue.clear()

	# restart the silence stream
	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_player_silence.play()

#	for node in section.get_children():
#		play_track(node)
	play_track(section)

	# we only get song's reference stream after calling play_track
	if reference_method == ReferenceMethod.SONG_STREAM:
		loop_length = reference_stream_player_song.stream_player.get_length()

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
		if reference_method == ReferenceMethod.SONG_STREAM and not reference_stream_player_song:
			reference_stream_player_song = track.stream_player
			Log.d(["set reference stream_player to", track])

	elif track is Section:
		for subtrack in track.get_children():
			play_track(subtrack)
	# if we're dealing with levels tracks, simply play all tracks
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
		Log.d(["multi-track", track, "now playing", sub_track])
		play_track(sub_track)


func play_audiotrack(track: AudioTrack):
	track.play()
	active_stream_players.append(track.stream_player)


func seek(to_position: float) -> void:
	Log.d(["seeking to time:", to_position, "s"])
	loop_time = to_position

	if Time.get_ticks_msec() < last_seek_time + 10:
		Log.w(["seeking too quickly. ignoring seek."])
		return

	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_player_silence.seek(to_position)
	for stream_player in active_stream_players:
		stream_player.seek(to_position)

	last_seek_time = Time.get_ticks_msec()


func seek_to_bbt(bbt: BBT) -> void:
	var to_position = _loop_beat_to_position(_bbt_to_loop_beat(bbt))
	seek(to_position)


func seek_to_barbeat(barbeat: float) -> void:
	var bbt = BBT.new().from_float(barbeat)
	seek_to_bbt(bbt)


func stop_all_streams() -> void:
	for stream_player in active_stream_players:
#		print(stream_player.name)
		if _is_stream_stinger(stream_player):
			Log.d(["not stopping stinger", stream_player])
		else:
			stream_player.stop()

	# WARN: it is possible for streams not to have stopped properly
	# e.g. if you call stop() on the same frame as play(), stop will fail
	# nonetheless, it's somewhat hard to check whether the stream has truly stopped
	active_stream_players.clear()

#	await get_tree().process_frame

#	var streams_still_playing = []
#	for stream_player in active_stream_players:
#		if stream_player.playing:
#			Log.e(["failed to stop stream_player", stream_player])
#			streams_still_playing.append(stream_player)
#
#	active_stream_players = streams_still_playing


func stop() -> void:
	stop_all_streams()
	playing = false


func pause() -> void:
	playing = false
	for stream_player in active_stream_players:
		stream_player.stream_paused = true
	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_player_silence.stream_paused = true

func unpause() -> void:
	for stream_player in active_stream_players:
		stream_player.stream_paused = false
	if reference_method == ReferenceMethod.SILENCE:
		reference_stream_player_silence.stream_paused = false
	playing = true

# ================================
# adaptive management
# ================================
func ________LEVELS(): pass


func set_level(value: int, when: int = NDef.When.ODD_BAR) -> void:
	_level = value
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

			LevelsTrack.LayerMode.ADDITIVE:
				for track_name in levels_track.levels:
					var track_level = levels_track.levels[track_name]
					if track_level <= level:
						fade_in(levels_track.get_node(track_name), when)
					else:
						fade_out(levels_track.get_node(track_name), when)
#				if highest_track:
#					for track_name in levels_track.levels:
#						fade_in(levels_track.get_node(track_name))
#						if track_name == highest_track:
#							break





	level_signal.emit(value)



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
		NDef.When.NOW:
			duration = 0.0
		NDef.When.BEAT:
			duration = beat_length * 0.5
		NDef.When.BAR:
			duration = beat_length * (beats_per_bar / 2)
		NDef.When.ODD_BAR:
			duration = beat_length * beats_per_bar

	return duration


func wait_until(when: int) -> void:
	match when:
		NDef.When.NOW:
			# hack. we need to wait at least one frame for yield to register
			await get_tree().process_frame
		NDef.When.BEAT:
			await self.beat
		NDef.When.BAR:
			await self.bar
		NDef.When.ODD_BAR:
			await self.odd_bar
		NDef.When.LOOP:
			await self.loop
#	return true

func determine_transition_beat(when: int, transition_bars):
	match when:
		NDef.When.NOW:
			transition_beat = loop_beat
		NDef.When.BEAT:
			transition_beat = loop_beat + 1
		NDef.When.BAR:
			transition_beat = bbt.bar * beats_per_bar + 1
		NDef.When.ODD_BAR:
			transition_beat = (bbt.bar + (bbt.bar % 2)) * beats_per_bar + 1
		NDef.When.LOOP:
			transition_beat = 0

	transition_beat += beats_per_bar * transition_bars

	# wrapping around total
	var loop_beats = beats_per_bar * bars
	transition_beat = transition_beat % loop_beats


func fade_in(track: Bus, when: int = NDef.When.ODD_BAR, duration: float = -1) -> void:
	var dur = duration
	if dur == -1:
		dur = determine_fade_duration(when)

	if dur == 0:
		# if we were ordered to fade while we weren't playing, just set the new level directly
		# this is so set_level works before starting the play
		# TODO might have to move this to set_level if this here creates unforseen issues
		track.auto_volume_db = 0
		return
	else:
		await wait_until(when)
		track.fade(null, 0.0, dur)
#		Log.d(["fading in track", track, "duration", dur])

	await get_tree().create_timer(dur).timeout
	faded_in.emit(track)


func fade_out(track: Bus, when: int = NDef.When.ODD_BAR, duration: float = -1) -> void:
	var dur = duration
	if dur == -1:
		dur = determine_fade_duration(when)

	if dur == 0:
		track.auto_volume_db = NDef.MIN_DB
		return
	else:
		await wait_until(when)
		track.fade(null, NDef.MIN_DB, dur)
#		Log.d(["fading out track", track])

	await get_tree().create_timer(dur).timeout
	faded_out.emit(track)



# ================================
# private functions / util
# ================================
func ________PRIVATE_UTIL(): pass


#func _copy_props_from(node: Node, if_not_zero = false) -> void:
#	for prop in Utils.get_export_variables(node):
#		if if_not_zero:
#			if node.get(prop.name) != 0:
#				set(prop.name, node.get(prop.name))
#		else:
#			set(prop.name, node.get(prop.name))


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
	return (bbt.bar-1) * beats_per_bar + bbt.beat


func _loop_beat_to_position(loop_beat):
	return (loop_beat - 1) * beat_length


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
				Log.d(["skipping playing of track", t[1], "because it falls on transition beat"])
			else:
				Log.d(["playing queued track", t[1]])
				play_audiotrack(t[1])

	for k in looping_regions:
		var region: Region = looping_regions[k]
		var end_bbt = BBT.new().from_float(region.end)
		if barbeat == end_bbt.to_float():
			seek_to_barbeat(region.start)



	if bbt.beat == 1:
		_bar()

	loop_beat_signal.emit(loop_beat)
	beat.emit(bbt.beat)
	barbeat_signal.emit(barbeat)



func _bar() -> void:
#	bar = (loop_beat - 1) / beats_per_bar + 1
	bar.emit(bbt.bar)
	if bbt.bar % 2 == 1:
		odd_bar.emit(bbt.bar)


func _loop_end() -> void:
	Log.d(["loop ended", section.name])
	if section.play_mode == Section.PlayMode.LOOP:
		Log.d(["restarting loop", section.name])
#		if not stop_at_loop:
		start_loop()
		loop_signal.emit(loop)
#		stop_at_loop = false
	else:
		Log.d(["stopping loop", section.name])
		# we have to at least set playing=false so that processing stops
		stop()
		end_signal.emit(song, section)

