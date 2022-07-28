extends Resource
class_name A_SongTransition

#export(String) var name

# to/from could be passed as different types (Section, Region, Marker)
# or maybe as strings with a prefix (s.Section1, r.Region1, m.Marker)
# to needs to be specified as a section and optionally a barbeat
# if from is not specified, it means we can transition from any section
export(String) var to
export(String) var from

export(int) var level := 1
export(String) var stinger
# what beat do we seek to
export(float) var barbeat := 1.1
# how many bars does the transition take (e.g. if playing stinger)
# that is, how many bars are we staying on the from track
export(int) var bars
export(Music.When) var when := Music.When.ODD_BAR

enum FadeType { CROSS, IN, OUT }
export(FadeType) var fade
