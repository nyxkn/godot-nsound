extends Node
class_name MusicPlayer

var Log = preload("res://addons/nsound/logger.gd").new(self)
const Utils = preload("res://addons/nsound/utils.gd")
const SectionPlayer = preload("res://addons/nsound/section_player.gd")
#const BBT = preload("res://addons/nsound/classes/bbt.gd")

signal section_started(section: Section)
signal song_started(song: Song)
signal song_finished(song: Song)
signal song_loaded(song: Song)
signal song_unloaded()


# play modes
# once and stop. at the end of a song we stop there
# loop. at the end of a song we restart it (does this belong here or in song?)
# sequence. at the end of a song we move on to the next one
# shuffle. at the end of a song we randomly choose another one
enum PlayMode { STOP_EACH, LOOP_EACH, SEQUENCE, SEQUENCE_LOOP, SHUFFLE }
@export var play_mode: PlayMode = PlayMode.SEQUENCE

@export var stop_on_pause: bool = false
@export var pause_duck_volume: float = -12.0
@export var preload_all_songs: bool = false

var songs := {}
# we instance one music player for each section of a song
# section_players[song][section]
var section_players := {}

# song-specific
var sections := {}
var stingers := {}
var transitions := {}

# state
var loaded_songs := []

var current_song: String
var current_section: String

var _shuffle_remaining_songs := []

#var song_loaded: bool = false

var _section_players_node

var goto_section_call_id := 0


func _ready() -> void:
	if stop_on_pause:
		process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		# section players inherit the mode because they're our child
		process_mode = Node.PROCESS_MODE_ALWAYS

	for song in get_children():
		songs[song.name] = song
		sections[song.name] = {}
		stingers[song.name] = {}
		transitions[song.name] = {}

	# set initial values
#	unload_song()

	# placeholder node for adding section_players
	_section_players_node = Node.new()
	_section_players_node.name = "MusicPlayers"
	add_child(_section_players_node)

	if preload_all_songs:
		for song_name in songs:
			load_song(song_name)


func _process(delta: float) -> void:
	if current_section_player():
		if get_tree().paused and pause_duck_volume != 0:
			songs[current_song].auto_volume_db = pause_duck_volume
		else:
			songs[current_song].auto_volume_db = 0


# shortcut for getting currently active section player
# instead of section_players[current_song][current_section]
func current_section_player() -> SectionPlayer:
	if current_song in section_players and current_section in section_players[current_song]:
		return section_players[current_song][current_section]
	else:
		return null

#func set_current_section_player(song_name: String, section_name: String):
#	current_song = song_name
#	current_section = section_name


func load_song(song_name: String):
	Log.i(["loading song", song_name])

	var song_node = songs[song_name]

	song_node.init(NSound.music_bus)
	for node in Utils.get_all_children(song_node):
		if node is Section:
			sections[song_name][node.name] = node
		elif node is StingersContainer:
			for track in node.get_children():
				stingers[song_name][track.name] = track
			NSound.setup_buses(node)

#	await get_tree().process_frame

	transitions[song_name] = song_node.transitions

	section_players[song_name] = {}
	for section_name in sections[song_name]:
		var section_node = sections[song_name][section_name]

		var section_player := SectionPlayer.new()
		section_player.name = "SectionPlayer_" + song_name + "_" + section_name
		_section_players_node.add_child(section_player)
		section_players[song_name][section_name] = section_player

		section_player.end_signal.connect(_on_section_end)

		section_player.load_song_section(song_node, section_node)

	song_node.music_system = self
	song_node._setup()
#	song_node.connect("hook_value_changed",Callable(self,"on_hook_value_changed"))


	loaded_songs.append(song_name)

	song_loaded.emit(song_node)

	Log.i(["buses count:", NSound.get_buses_count()])

	return song_node


func unload_song(song_name: String):
	Log.i(["unloading song", song_name])

	stop()

#	loaded_songs.erase(song_name)

#	song_loaded = false

#	if current_section_player:
#		current_section_player.queue_free()
#	current_section_player = null

	for k in section_players[song_name]:
		section_players[song_name][k].queue_free()
	section_players.erase(song_name)

	NSound.remove_all_buses()

	sections[song_name].clear()
	stingers[song_name].clear()
	transitions[song_name].clear()

#	songs.erase(current_song)

#	current_section = ""
#	current_song = ""

	song_unloaded.emit()

	Log.i(["buses count:", NSound.get_buses_count()])


func stop():
#	if current_section_player():
	current_section_player().stop()


#func play_only(song_name: String, section_name: String = ""):
#	section_players[song_name][section_name].start()


func play_and_switch(song_name: String = "", section_name: String = "", stop: bool = true):
#func play_and_switch(song_name: String = "", section_name: String = ""):
	Log.d(["play_and_switch. changing to song/section:", song_name, section_name])

	# if no song_name, replay current song
	if not song_name:
		song_name = current_song

	# check whether song is loaded
	if not song_name in loaded_songs:
		Log.e(["song", song_name, "isn't loaded"])
		return

	if stop and section_players.has(current_song) and section_players[current_song].has(current_section):
		Log.i(["stopping current song/section", current_song, current_section])
		section_players[current_song][current_section].stop()

	Log.d([section_players])

	# start new song (setting new song as current_song)

	if not section_name:
		section_name = section_players[song_name].keys()[0]

	Log.i(["starting song/section", song_name, section_name])

	section_players[song_name][section_name].start()

	current_section = section_name
	# changing to a new song rather than just a different section
	if song_name != current_song:
		current_song = song_name
		song_started.emit(songs[current_song])

	section_started.emit(sections[current_song][current_section])


func goto_section(section_name: String, when: int = NDef.When.ODD_BAR) -> void:
	goto_section_call_id += 1
	var current_id = goto_section_call_id

	if current_section_player():
#		current_section_player().stopping = true
		await current_section_player().wait_until(when)

	# if id is still the same as when we started the function, proceed
	# otherwise ignore the call because a new one was made
	if current_id == goto_section_call_id:
		play_and_switch(current_song, section_name)
	else:
		Log.e(["this goto section call has been superseded"])



func goto_song(song_name: String) -> void:
#	if current_song:
#		unload_song(current_song)

	if not song_name in loaded_songs:
		Log.i(["song", song_name, "wasn't loaded. loading"])
		load_song(song_name)

#	play_and_switch(song_name)


func run_transition(transition_name: String) -> void:
	var transition = transitions[current_song][transition_name]
	Log.d(["running transition", transition_name])

	var from_section = ""

	if not transition.from:
		from_section = current_section
	elif transition.from is Section:
		from_section = transition.from.name
	elif from_section is String:
		from_section = transition.from

	if from_section != current_section:
		Log.i("running transition from the wrong section")
		return

	var to_section
	var to_barbeat
	# region
	if transition.to is Region:
		to_section = transition.to.section().name
		to_barbeat = transition.to.start
	# section
	else:
		to_section = transition.to
		if to_section is Section:
			to_section = to_section.name
		to_barbeat = transition.barbeat

	var from_section_player = section_players[current_song][from_section]
	var to_section_player = section_players[current_song][to_section]

	from_section_player.determine_transition_beat(transition.when, transition.bars)

	await from_section_player.wait_until(transition.when)

	if transition.stinger:
		queue_stinger(transition.stinger, NDef.When.NOW)

	for i in transition.bars:
		await from_section_player.bar

	to_section_player.set_level(transition.level, NDef.When.NOW)
	play_and_switch(current_song, to_section, false)

#	if transition.barbeat != 1.1:
	if to_barbeat and to_barbeat != 1.1:
		to_section_player.seek_to_bbt(BBT.new().from_float(to_barbeat))

	# crossfade can only happen after the new section has started
	# i.e. you cannot start the new section at full volume (cannot fade_in before the track even exists)
	if transition.fade == Transition.FadeType.CROSS:
		sections[current_song][to_section].auto_volume_db = NDef.MIN_DB
		from_section_player.fade_out(from_section_player.section, NDef.When.NOW, from_section_player.beat_length * 4)
		to_section_player.fade_in(to_section_player.section, NDef.When.NOW, from_section_player.beat_length * 4)
		await from_section_player.faded_out
		from_section_player.stop()
	else:
		# always duplicate?
		if from_section_player != to_section_player:
			from_section_player.stop()


func queue_stinger(stinger: String, when: int = NDef.When.BAR) -> void:
	await current_section_player().wait_until(when)

	Log.d(["playing stinger", stinger])
	current_section_player().play_track(stingers[current_song][stinger])


# determine what to do at the end of a section
func _on_section_end(song: Song, section: Section) -> void:
	var section_nodes = sections[song.name].values()
	var song_nodes = songs.values()

	Log.d(["section ended:", section.name])

	Log.d(["section_nodes:", section_nodes])
	Log.d(["song_nodes:", song_nodes])

	var section_idx = -1
	for i in section_nodes.size():
		if section_nodes[i].name == section.name:
			section_idx = i
			break

	if section_idx < section_nodes.size() - 1:
		Log.d(["switching to next section"])
		# there's more sections in the song. play next section
		# switching to the next section should happen exactly in time
		# so ensure everything is already loaded
		play_and_switch(song.name, section_nodes[section_idx + 1].name)

	elif section_idx == section_nodes.size() - 1:
		Log.d(["switching to next song"])
		# this was the last section. play next song
		match play_mode:
			PlayMode.STOP_EACH:
				# you can manually decide what to do after
				Log.i("song finished. stopping")
				song_finished.emit(song)

			PlayMode.LOOP_EACH:
				# you can manually decide when to stop/change
				Log.i("looping song")
				play_and_switch(song.name, section_nodes[0].name)

			PlayMode.SEQUENCE, PlayMode.SEQUENCE_LOOP:
				Log.i("moving on to next song in sequence")

				var song_idx = song_nodes.find(song)

				if song_idx == song_nodes.size() - 1:
					if play_mode == PlayMode.SEQUENCE_LOOP:
						Log.i("end of sequence. looping")
						play_and_switch(song_nodes[0].name)
					else:
						# call stop manually? needed?
						Log.i("end of sequence. stopping")
				else:
					play_and_switch(song_nodes[song_idx + 1].name)

			PlayMode.SHUFFLE:
				# shuffle ensures all songs are played, in random order
				# you can implement a RANDOM mode where they are truly random
				Log.i("shuffling for the next song")

				if _shuffle_remaining_songs.is_empty():
					_shuffle_remaining_songs = song_nodes.duplicate()
					_shuffle_remaining_songs.erase(song) # remove song just played
					_shuffle_remaining_songs.shuffle()

				var next_song = _shuffle_remaining_songs.pop_front()
				play_and_switch(next_song.name)


