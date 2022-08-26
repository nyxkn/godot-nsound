extends Node
class_name MusicSystem


signal section_started(node)
signal song_started(node)
signal song_finished(node)
signal song_loaded(node)
signal song_unloaded()


# play modes
# once and stop. at the end of a song we stop there
# loop. at the end of a song we restart it (does this belong here or in song?)
# sequence. at the end of a song we move on to the next one
# shuffle. at the end of a song we randomly choose another one
enum PlayMode { SONG_ONCE, LOOP_SONG, SEQUENCE, SHUFFLE }
export(PlayMode) var play_mode = PlayMode.SEQUENCE


var songs := {}
# we instance one music player for each section of a song
# music_players[song][section]
var music_players := {}

# song-specific
var sections := {}
var stingers := {}
var transitions := {}

# state
var loaded_songs := []

var current_song: String
var current_section: String

var played_songs := []

#var song_loaded: bool = false

var _music_players_node


func _ready() -> void:
	for song in get_children():
		songs[song.name] = song
		sections[song.name] = {}
		stingers[song.name] = {}
		transitions[song.name] = {}

	# set initial values
#	unload_song()

	# placeholder node for adding music_players
	_music_players_node = Node.new()
	_music_players_node.name = "MusicPlayers"
	add_child(_music_players_node)

	for song_name in songs:
		load_song(song_name)


# the advantage of using a getter is that you don't have to store
# current_music_player as a variable
# which will create problems if you try to free it and recreate it
func current_music_player() -> MusicPlayer:
	if current_song and current_section:
		return music_players[current_song][current_section]
	else:
		return null

#func set_current_music_player(song_name: String, section_name: String):
#	current_song = song_name
#	current_section = section_name


func load_song(song_name: String):
	Log.i(["loading song", song_name], name)

	var song_node = songs[song_name]

	for node in NUtils.get_all_children(song_node):
		if node is Section:
			sections[song_name][node.name] = node
		elif node is StingersContainer:
			for track in node.get_children():
				stingers[song_name][track.name] = track
			NUtils.setup_buses(node)

#	yield(get_tree(), "idle_frame")

	transitions[song_name] = song_node.transitions

	music_players[song_name] = {}
	for section_name in sections[song_name]:
		var section_node = sections[song_name][section_name]

		var music_player := MusicPlayer.new()
		music_player.name = "MusicPlayer_" + song_name + "_" + section_name
		_music_players_node.add_child(music_player)
		music_players[song_name][section_name] = music_player

		music_player.connect("end", self, "on_section_end")

		music_player.load_song_section(song_node, section_node)

	song_node.music_system = self
	song_node._setup()
#	song_node.connect("hook_value_changed", self, "on_hook_value_changed")


	loaded_songs.append(song_name)

	emit_signal("song_loaded", song_node)

	Log.i(["buses count:", Audio.get_buses_count()], name)

	return song_node


func unload_song(song_name: String):
	Log.i(["unloading song", song_name], name)

	stop()

#	loaded_songs.erase(song_name)

#	song_loaded = false

#	if current_music_player:
#		current_music_player.queue_free()
#	current_music_player = null

	for k in music_players[song_name]:
		music_players[song_name][k].queue_free()
	music_players.erase(song_name)

	Audio.remove_all_buses()

	sections[song_name].clear()
	stingers[song_name].clear()
	transitions[song_name].clear()

#	songs.erase(current_song)

#	current_section = ""
#	current_song = ""

	emit_signal("song_unloaded")

	Log.i(["buses count:", Audio.get_buses_count()], name)


func stop():
	if current_music_player():
		current_music_player().stop()


#func play_only(song_name: String, section_name: String = ""):
#	music_players[song_name][section_name].start()


func play_and_switch(song_name: String = "", section_name: String = "", stop: bool = true):
	if not song_name:
		song_name = current_song

	# check whether song is loaded
	if not song_name in loaded_songs:
		Log.e(["song", song_name, "isn't loaded"])
		return

	# using current music player here and later is confusing
	# what's happeneing is that by changing current_song and section
	# current music player will return a different player
	if stop and current_music_player():
		Log.i(["stopping current song/section", current_song, current_section], name)
		current_music_player().stop()


	current_song = song_name

	if not section_name:
		section_name = music_players[current_song].keys()[0]
	current_section = section_name

	Log.i(["starting song/section", current_song, current_section], name)


#	current_music_player = music_players[current_song][current_section]
	current_music_player().start()

	emit_signal("section_started", sections[song_name][section_name])


func goto_section(section_name: String, when: int = Music.When.ODD_BAR) -> void:
	yield(current_music_player().wait_until(when), "completed")
	play_and_switch(current_song, section_name)


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
		Log.i("running transition from the wrong section", name)
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

	var from_music_player = music_players[current_song][from_section]
	var to_music_player = music_players[current_song][to_section]

	from_music_player.determine_transition_beat(transition.when, transition.bars)

	yield(from_music_player.wait_until(transition.when), "completed")

	if transition.stinger:
		queue_stinger(transition.stinger, Music.When.NOW)

	for i in transition.bars:
		yield(from_music_player, "bar")

	to_music_player.set_level(transition.level, Music.When.NOW)
	play_and_switch(current_song, to_section, false)

#	if transition.barbeat != 1.1:
	if to_barbeat and to_barbeat != 1.1:
		to_music_player.seek_to_bbt(BBT.new().from_float(to_barbeat))

	# crossfade can only happen after the new section has started
	# i.e. you cannot start the new section at full volume (cannot fade_in before the track even exists)
	if transition.fade == Transition.FadeType.CROSS:
		sections[current_song][to_section].volume_db = Music.MIN_DB
		from_music_player.fade_out(from_music_player.section, Music.When.NOW, from_music_player.beat_length * 4)
		to_music_player.fade_in(to_music_player.section, Music.When.NOW, from_music_player.beat_length * 4)
		yield(from_music_player, "faded_out")
		from_music_player.stop()
	else:
		# always duplicate?
		if from_music_player != to_music_player:
			from_music_player.stop()


func queue_stinger(stinger: String, when: int = Music.When.BAR) -> void:
	yield(current_music_player().wait_until(when), "completed")

	Log.d(["playing stinger", stinger], name)
	current_music_player().play_track(stingers[current_song][stinger])


func on_section_end(song_name: String, section_name: String) -> void:
#	var section_nodes = songs[song_name].get_children()
	var section_nodes = sections[song_name].values()
#	var song_nodes = get_children()
	var song_nodes = songs.values()
#	song_nodes

	Log.d(["section_nodes:", section_nodes])
	Log.d(["song_nodes:", song_nodes])

	var section_idx = -1
	for i in section_nodes.size():
		if section_nodes[i].name == section_name:
			section_idx = i
			break



	if section_idx == section_nodes.size() - 1:
		pass
		# play next song
		match play_mode:
			PlayMode.SONG_ONCE:
				Log.i("song finished. stopping")
				emit_signal("song_finished", songs[song_name])

			PlayMode.LOOP_SONG:
				Log.i("looping song")
				play_and_switch(song_name, section_nodes[0].name)

			PlayMode.SEQUENCE:
				Log.i("moving on to next song in sequence")

				var song_idx = -1
				for i in song_nodes.size():
					if song_nodes[i].name == song_name:
						song_idx = i
						break

				if song_idx == song_nodes.size() - 1:
					# stop?
					Log.i("end of sequence. stopping")
				else:
					play_and_switch(song_nodes[song_idx + 1].name)

			PlayMode.SHUFFLE:
				Log.i("shuffling for the next song")

				for song in played_songs:
					song_nodes.erase(song)

				if song_nodes.size() == 0:
					song_nodes = songs.values()
					song_nodes.erase(played_songs[-1])

				var song_idx = Audio.rng.randi_range(0, song_nodes.size() - 1)
				play_and_switch(song_nodes[song_idx].name)
				played_songs.append(song_nodes[song_idx])


	elif section_idx < section_nodes.size() - 1:
		# play next section
		# switching to the next section should happen exactly in time
		# so ensure everything is already loaded
		play_and_switch(song_name, section_nodes[section_idx + 1].name)

