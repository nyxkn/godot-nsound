extends AudioServerBus
class_name Section

# this is mandatory
export(int) var bars
# this is an override of song bpb. maybe we should remove it from song for clarity
export(int) var bpm := 0
export(int) var beats_per_bar := 0

export(Dictionary) var regions


enum PlayMode { LOOP, ONCE }
export(PlayMode) var play_mode = PlayMode.LOOP


func _ready() -> void:
	assert(bars, "bars number must be set in section")
