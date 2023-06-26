class_name Transition
extends Resource

#export var name: String

# to/from could be passed as different types (Section, Region, Marker)
# or maybe as strings with a prefix (s.Section1, r.Region1, m.Marker)
# to needs to be specified as a section and optionally a barbeat
# if from is not specified, it means we can transition from any section
# only exported as string, but you can actually pass Sections and Regions

# godot4 export requires type. but we want to pass multiple types here. TODO
var to
@export var from: String

@export var level: int = 1
@export var stinger: String
# what beat do we seek to
@export var barbeat: float = 1.1
# how many bars does the transition take (e.g. if playing stinger)
# that is, how many bars are we staying on the from track
@export var bars: int
@export var when := NDef.When.ODD_BAR # (NDef.When)

enum FadeType { CROSS, IN, OUT }
@export var fade: FadeType
