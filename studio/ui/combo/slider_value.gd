tool
extends HBoxContainer


signal value_changed(value)

export(float) var min_value: float = 0 setget set_min_value
export(float) var max_value: float = 10 setget set_max_value
export(float) var step: float = 1 setget set_step
export(float) var value: float setget set_value

var dragging := false


func _ready():
	$Label.text = name


# unless the slider is focused, this shouldn't trigger the value changed signal
func set_value(v) -> void:
	if not dragging:
		value = v
		$HSlider.value = value


func set_min_value(v) -> void:
	min_value = v
	$HSlider.min_value = min_value
	$SpinBox.min_value = min_value


func set_max_value(v) -> void:
	max_value = v
	$HSlider.max_value = max_value
	$SpinBox.max_value = max_value


func set_step(v) -> void:
	step = v
	$HSlider.step = step
	$SpinBox.step = step


# this is called when value changes both from code and gui
func _on_HSlider_value_changed(value: float) -> void:
	$SpinBox.value = value

	# check if we've got focus, which means it's a user change and not from code
	if get_focus_owner() == $HSlider:
		# actually even better to just use drag_ended signal
		pass
#		emit_signal("value_changed", value)


# this is called when value changes both from code and gui
func _on_SpinBox_value_changed(value: float) -> void:
	$HSlider.value = value

	# check if we've got focus, in which case register the change as being user made
	# spinbox child 0 is the lineedit that gets focused when changing the value
	# both if changing the number and if pressing the arrows
	# WARN: this still emits if it's a code change and the box happened to be focused
	if get_focus_owner() == $SpinBox.get_child(0):
		emit_signal("value_changed", value)


# this guarantees that it gets called only on user input and not code change
func _on_HSlider_drag_ended(value_changed: bool) -> void:
	dragging = false
	if value_changed:
		value = $HSlider.value
#		$SpinBox.value = value
		emit_signal("value_changed", value)


func _on_HSlider_drag_started() -> void:
	dragging = true
