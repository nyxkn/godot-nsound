extends Node
class_name Music

# the value for inaudible db. should be between -80 and -60
# https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html
const MIN_DB := -80

enum When { NOW, BEAT, BAR, ODD_BAR, LOOP }

