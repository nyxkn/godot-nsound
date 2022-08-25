extends Control

signal hook_value_changed(value)


var music_system

var _current_music_player
var _song_name


func init(music_system: MusicSystem) -> void:
	self.music_system = music_system

	music_system.connect("section_started", self, "_on_MusicSystem_section_started")
	music_system.connect("song_started", self, "_on_MusicSystem_song_started")
	music_system.connect("song_loaded", self, "_on_MusicSystem_song_loaded")

	get_node("%Songs").clear()
	for name in music_system.songs:
		get_node("%Songs").add_item(name)


func attach_to_player(music_player):
	if _current_music_player:
		_current_music_player.disconnect("beat", self, "_on_Music_beat")
		_current_music_player.disconnect("loop_beat", self, "_on_Music_loop_beat")
		_current_music_player.disconnect("bar", self, "_on_Music_bar")
		_current_music_player.disconnect("loop", self, "_on_Music_loop")
		_current_music_player.disconnect("level", self, "_on_Music_level")

	_current_music_player = music_player

	_current_music_player.connect("beat", self, "_on_Music_beat")
	_current_music_player.connect("loop_beat", self, "_on_Music_loop_beat")
	_current_music_player.connect("bar", self, "_on_Music_bar")
	_current_music_player.connect("loop", self, "_on_Music_loop")
	_current_music_player.connect("level", self, "_on_Music_level")

	$"%BPB".value = _current_music_player.beats_per_bar
	$"%BPM".value = _current_music_player.bpm
	$"%Bars".value = _current_music_player.bars

	$"%Timeline".max_value = _current_music_player.loop_length
	$"%Timeline".value = _current_music_player.loop_time
	$"%Timeline/TotalTime".text = str("%0.1f" % _current_music_player.loop_length, 's')
	$"%Time".text = str("%0.1f" % _current_music_player.loop_time, 's')

#	var total_barbeats = _current_music_player._get_barbeat(
#		_current_music_player.bars,
#		_current_music_player.beats_per_bar)
	var total_barbeats = BBT.new().init(
		_current_music_player.bars,
		_current_music_player.beats_per_bar).to_float()
	$"%BBT".value = _current_music_player.bbt.to_float()
	$"%BBT/Total".text = str(total_barbeats)

	_on_Music_level(_current_music_player.level)

	update_status()



func update_status():
	$"%Bar".value = _current_music_player.bbt.bar
	$"%Beat".value = _current_music_player.bbt.beat
	$"%LoopBeat".value = _current_music_player.loop_beat
	$"%Loop".value = _current_music_player.loop


func _process(delta: float) -> void:
	if _current_music_player:
		$"%Timeline".value = _current_music_player.loop_time
		$"%Time".text = str("%0.1f" % _current_music_player.loop_time, 's')
		$"%BBT".value = _current_music_player.bbt.to_float()


func _on_Music_beat(n) -> void:
#	print(str('beat: ', n))
	$"%Beat".value = n


func _on_Music_loop_beat(n) -> void:
#	print(str('loop_beat: ', n))
	$"%LoopBeat".value = n


func _on_Music_bar(n) -> void:
#	print(str('bar: ', n))
	$"%Bar".value = n


func _on_Music_loop(n) -> void:
#	print(str('loop: ', n))
	$"%Loop".value = n


func _on_MusicSystem_song_loaded(song_node) -> void:
	_song_name = song_node.name
	$"%SongTitle".text = _song_name


	get_node("%Transitions").clear()
	for name in music_system.transitions:
		get_node("%Transitions").add_item(name)

	get_node("%Stingers").clear()
	for name in music_system.stingers:
		get_node("%Stingers").add_item(name)

	get_node("%Sections").clear()
	for name in music_system.sections:
		get_node("%Sections").add_item(name)

	get_node("%Mixer").init_song(song_node)


func _on_MusicSystem_section_started(section_node) -> void:
	attach_to_player(music_system.current_music_player)


func _on_MusicSystem_song_started(song_node) -> void:
	pass


func _on_Music_level(n) -> void:
	$"%Level/SpinBox".value = n


func _on_Play_pressed() -> void:
	music_system.play_and_switch(_song_name)


func _on_Level_value_changed(value) -> void:
	_current_music_player.level = value


func _on_NextLoop_pressed() -> void:
	_current_music_player._loop_end()


func _on_RunTransition_pressed() -> void:
	var t = get_node("%Transitions")
	music_system.run_transition(t.get_item_text(t.get_selected_id()))


func _on_RunStinger_pressed() -> void:
	var options = get_node("%Stingers")
	music_system.queue_stinger(options.get_item_text(options.get_selected_id()))


func _on_GotoSection_pressed() -> void:
	var options = get_node("%Sections")
	var item = options.get_item_text(options.get_selected_id())
	music_system.goto_section(item)
#	attach_to_player(music_system._current_music_player)


func _on_GotoSong_pressed() -> void:
	var options = get_node("%Songs")
	var item = options.get_item_text(options.get_selected_id())
	music_system.goto_song(item)


func _on_Stop_pressed() -> void:
	music_system.stop()


func _on_Timeline_value_changed(value) -> void:
	_current_music_player.seek(value)
	yield(get_tree().create_timer(0.1), "timeout")
	update_status()


func _on_HookValue_value_changed(value) -> void:
	emit_signal("hook_value_changed", value)


func _on_BBT_value_changed(value) -> void:
	_current_music_player.seek_to_barbeat(float(value))
