extends AudioServerBus
#class_name MultiTrack, "res://addons/nframework/assets/icons/icon_file_list.svg"
class_name MultiTrack, "res://addons/nframework/assets/icons/godot/Play.svg"

# you could have a progression type switch here
# but then you'd have to conform all types to the same variables
# which is probably fine. the silence_chance thing is likely useless
# and can be replaced instead by an empty silence track

# to be honest, random seems quite useless. it's not very fun. shuffle is probably strictly superior
# shuffle means that you want each track to play with equal frequency
# and that we don't play the same track twice in a row
enum Progression { RANDOM, SEQUENCE, SHUFFLE }
export(Progression) var progression := Progression.SHUFFLE

var last_played: int = -1
var tracks: Array


func _ready() -> void:
	tracks = get_children()

	if progression == Progression.SHUFFLE:
		tracks.shuffle()
		last_played = tracks.size() - 1


func get_next_track() -> Bus:
	var track: Bus

	match progression:
		Progression.RANDOM:
			var rnd = F.rng.randi_range(0, tracks.size() - 1)
			track = tracks[rnd]
			last_played = rnd
		Progression.SEQUENCE:
			last_played = (last_played + 1) % tracks.size()
			track = tracks[last_played]
		Progression.SHUFFLE:
			var new_track_number = (last_played + 1) % tracks.size()
			if new_track_number == 0:
				var last_track = tracks[tracks.size() - 1]
				tracks.shuffle()
				# ensure that after the shuffle, our next track isn't the same as the last
				# if it is, replace it to a random index != 0
				if tracks[0] == last_track:
					tracks.erase(last_track)
					var rnd = F.rng.randi_range(1, tracks.size())
					tracks.insert(rnd, last_track)
			track = tracks[new_track_number]
			last_played = new_track_number

	return track
