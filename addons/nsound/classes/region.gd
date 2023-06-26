class_name Region
extends Node

# region is necessarily section-local
# barbeat numbers are always section-local
# also the purpose of these is to help with seeking
# transitioning to a different section requires a different music_player
# but of course you can still define transitions as jumps between regions of different sections

# start and end are bbt floats
var start: float
var end: float
var loop: bool
# the section this region belongs to
# this gets initialized by music_player
var _section: Section : get = section

func init(start: float, end: float = -1) -> Region:
	self.start = start
	self.end = end
	if self.end == -1:
		self.end = self.start
	return self

func section() -> Section:
	return _section
