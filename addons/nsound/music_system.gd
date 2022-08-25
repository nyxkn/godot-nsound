extends Node
class_name MusicSystem

signal section_started(node)
signal song_started(node)
signal song_loaded(song_name)

var music_players := {}
var songs := {}
var sections := {}
var stingers := {}
var transitions := {}


var current_section: String
var current_song: String

var current_music_player: MusicPlayer

func _ready() -> void:
	for song in get_children():
		songs[song.name] = song


func _input(event: InputEvent) -> void:
	pass
#	if event.is_action_pressed("ui_down"):
#		var layout = AudioServer.generate_bus_layout()
#		ResourceSaver.save("res://studio/saves/bus_layout.res", layout)
#		Log.d('saved bus layout', name)
#	if event.is_action_pressed("ui_right"):
#		for song in get_children():
#			if song is Song:
#				var all_children = NUtils.get_all_children(song)
#				for c in all_children:
#					# this is because if we own stream we'll end up with duplicated streams
#					if not c is AudioStreamPlayer:
#						c.owner = song
#				FileUtils.save_scene("res://studio/saves/", song, true)
#				Log.d('saved song', name)


func load_song(song_name: String):
	var song_node = songs[song_name]

	sections.clear()
	stingers.clear()
	for node in NUtils.get_all_children(song_node):
		if node is Section:
			sections[node.name] = node
		elif node is StingersContainer:
			for track in node.get_children():
				stingers[track.name] = track
			NUtils.setup_buses(node)

	transitions = song_node.transitions


	music_players[song_name] = {}
	for section_name in sections:
		var section_node = sections[section_name]

		var music_player := MusicPlayer.new()
		add_child(music_player)
		music_players[song_name][section_name] = music_player

		music_player.load_song_section(song_node, section_node)

	song_node.music_system = self
	song_node._setup()

	emit_signal("song_loaded", song_node)

	return song_node



func play_only(song_name: String, section_name: String = ""):
	music_players[song_name][section_name].start()


func play_and_switch(song_name: String, section_name: String = "", stop: bool = true):
	if song_name != current_song:
		emit_signal("song_started", songs[song_name])

	current_song = song_name

	if not section_name:
		section_name = music_players[current_song].keys()[0]
	current_section = section_name

	if stop and current_music_player:
		current_music_player.stop()

	current_music_player = music_players[current_song][current_section]
	current_music_player.start()

	emit_signal("section_started", sections[section_name])


func goto_section(section_name: String, when: int = Music.When.ODD_BAR) -> void:
	yield(current_music_player.wait_until(when), "completed")
	play_and_switch(current_song, section_name)


func goto_song(song_name: String) -> void:
	pass


func run_transition(transition_name: String) -> void:
	var transition = transitions[transition_name]
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
		sections[to_section].volume_db = Music.MIN_DB
		from_music_player.fade_out(from_music_player.section, Music.When.NOW, from_music_player.beat_length * 4)
		to_music_player.fade_in(to_music_player.section, Music.When.NOW, from_music_player.beat_length * 4)
		yield(from_music_player, "faded_out")
		from_music_player.stop()
	else:
		# always duplicate?
		if from_music_player != to_music_player:
			from_music_player.stop()


func queue_stinger(stinger: String, when: int = Music.When.BAR) -> void:
	yield(current_music_player.wait_until(when), "completed")

	Log.d(["playing stinger", stinger], name)
	current_music_player.play_track(stingers[stinger])



