extends AudioServerBus
class_name Song

export(int) var bpm
export(int) var beats_per_bar
# bars is defined per section
#export(int) var bars := 0

# 3 levels of transitions
# 1. basic go to section. use default settings
# 2. define transition properties like level, stingers, target beat
# 3. run custom actions by writing the code

# transition is a simple transition where you can customize predefined settings
# but you can then define "actions", which are just going to be a function or a script
# and you can run these at any time
# you could even set which actions to run from a transition definition

#export(Array, Resource) var transitions
export(Dictionary) var transitions


var music_system


#func _ready() -> void:
#	transitions = []

# simply define the transition functions in your Song-derived script
# and we can then find them automatically with this
func list_functions():
	var script: Script = get_script()
	var methods = script.get_script_method_list()

	for m in methods:
		if m.name == "t_Theme1_to_Theme2":
			print(m)


func t_Theme1_to_Theme2() -> void:
	pass


func new_transition(from, to, level = 0, stinger = '', bars = 0, fade = -1):
#	for t in transitions:
#		if t.name == name:
#			return

	var t = A_SongTransition.new()
#	t.name = name
	t.from = from
	t.to = to
	t.level = level
	t.stinger = stinger
	t.bars = bars
	t.fade = fade
	return t


func _setup():
	pass
