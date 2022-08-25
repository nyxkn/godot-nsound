extends Node
class_name BBT


var bar: int
var beat: int
# tick isn't being used. setting it to 0 so we can ignore it
var tick: int = 0


func init(bar: int, beat: int, tick: int = 0) -> BBT:
	if not _validate_values(bar, beat, tick):
		return null

	self.bar = bar
	self.beat = beat
	self.tick = tick
	return self


func from_float(bbt: float) -> BBT:
	return from_string(str(bbt))


func from_string(bbt: String) -> BBT:
	var re := NUtils.compile_regex("\\d+(\\.\\d+)?(\\.\\d+)?")
	var result = re.search_all(bbt)
	if not result.size() == 1:
		Log.e(["float bbt", bbt, "is incorrectly formatted"])
		return null

	var r: RegExMatch = result[0]

	var split = r.subject.split('.')
	var values = [1, 1, 0]
	for i in split.size():
		values[i] = int(split[i])

	if not _validate_values(values[0], values[1], values[2]):
		return null

	bar = values[0]
	beat = values[1]
	tick = values[2]

	return self


func to_float() -> float:
	# this is actually surprisingly (very slightly) faster than doing bar + beat * 0.1
	var bb = float(str(bar, ".", beat))
	return bb


func _validate_values(bar: int, beat: int, tick: int = 0) -> bool:
	if bar < 1:
		printerr("invalid bar")
		return false
	if beat < 1:
		printerr("invalid beat")
		return false
	if tick < 0:
		printerr("invalid tick")
		return false

	return true
