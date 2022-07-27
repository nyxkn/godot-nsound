extends Resource
class_name A_SongTransition

#export(String) var name

export(String) var from
export(String) var to

export(int) var level := 1
export(String) var stinger
# which barbeat do we go to (float bar.beat)
export(float) var barbeat := 1.0
# how many bars does the transition take (e.g. if playing stinger)
# that is, how many bars are we staying on the from track
export(int) var bars
export(Music.When) var when := Music.When.ODD_BAR

enum FadeType { CROSS, IN, OUT }
export(FadeType) var fade
