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
		$LineEdit.text = str(value)


func set_min_value(v) -> void:
	min_value = v
	$HSlider.min_value = min_value


func set_max_value(v) -> void:
	max_value = v
	$HSlider.max_value = max_value


func set_step(v) -> void:
	step = v
	$HSlider.step = step


# this is called when value changes both from code and gui
func _on_HSlider_value_changed(value: float) -> void:
	$LineEdit.text = str(value)


# this guarantees that it gets called only on user input and not code change
func _on_HSlider_drag_ended(value_changed: bool) -> void:
	dragging = false
	if value_changed:
		value = $HSlider.value
		$LineEdit.text = str(value)
		emit_signal("value_changed", value)


func _on_HSlider_drag_started() -> void:
	dragging = true


func _on_LineEdit_text_entered(new_text: String) -> void:
	self.value = float(new_text)
#	$HSlider.value = value
	emit_signal("value_changed", value)
