class_name Section
extends AudioServerBus

# this is mandatory
@export var bars: int
# this is an override of song bpb. maybe we should remove it from song for clarity
@export var bpm: int = 0
@export var beats_per_bar: int = 0

@export var regions: Dictionary


enum PlayMode { LOOP, ONCE }
@export var play_mode: PlayMode = PlayMode.LOOP


func _ready() -> void:
	pass
#	assert(bars) #,"bars value must be set in section: " + name)
