@tool
extends HBoxContainer


signal value_changed(value)

@export var min_value: float = 0 : set = set_min_value
@export var max_value: float = 10 : set = set_max_value
@export var step: float = 1 : set = set_step
@export var exponential: bool = false : set = set_exponential
@export var default_value: float = 0

@export_flags("Slider", "SpinBox", "ValueLabel") var components = 1|2

# we're using the private variable to be able to set the value without triggering set_value
# ideally we'd to without that, and set_value should take args to determine behaviour
# so e.g. we could pass no_signal to set_value to avoid triggering signal
# that would be more clear than using a double variable
var _value: float
var value: float :
	get: return _value
	set(v): set_value(v)


func _ready():
	# set without signal
	_value = default_value

	$Label.text = name

	$HSlider.visible = components & 1
	$SpinBox.visible = components & 2
	$Value.visible = components & 4


func set_min_value(v) -> void:
	min_value = v

	if not is_node_ready():
		await ready

	$HSlider.min_value = min_value
	$SpinBox.min_value = min_value


func set_max_value(v) -> void:
	max_value = v

	if not is_node_ready():
		await ready

	$HSlider.max_value = max_value
	$SpinBox.max_value = max_value


func set_step(v) -> void:
	step = v

	if not is_node_ready():
		await ready

	$HSlider.step = step
	$SpinBox.step = step


func set_exponential(v) -> void:
	exponential = v

	if not is_node_ready():
		await ready

	$HSlider.exp_edit = exponential
	$SpinBox.exp_edit = exponential


func set_value(new_value: float):
	_value = new_value

	if not is_node_ready():
		await ready

	$Value.text = str(new_value)
	$SpinBox.set_value_no_signal(new_value)
	$HSlider.set_value_no_signal(new_value)

	# it's safer to call this when ready. but is there any need for it to happen before ready?
	value_changed.emit(new_value)


func _on_h_slider_value_changed(new_value: float) -> void:
	value = new_value


func _on_spin_box_value_changed(new_value: float) -> void:
	value = new_value
