extends AudioServerBus
class_name Section

#export(int) var bpm := 0
# this is mandatory
export(int) var bars
# this is an override of song bpb. maybe we should remove it from song for clarity
export(int) var beats_per_bar

export(Dictionary) var loops


func _ready() -> void:
	assert(bars, "bars number must be set in section")
