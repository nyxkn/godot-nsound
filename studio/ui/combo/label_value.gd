@tool
extends HBoxContainer


signal value_changed(value)

# these setters get called on scene reload as long as a custom value was provided
# they won't get called on reload if the value is the default value defined here
# note, these get called BEFORE _ready. so anything you do in _ready will override these
@export var label: String = "" : set = set_label
# don't type this as String so you can use numbers too
@export var value = "" : set = set_value
@export var separator: String = "" : set = set_separator
@export var suffix: String = "" : set = set_suffix
@export var total: String = "" : set = set_total
@export var editable: bool = false : set = set_editable


func _ready() -> void:
	# if label is still empty when _readying, set it to the name
	# not the value of label, just the visible text
	if label == "":
		$Label.text = name


func set_label(value) -> void:
	label = value

	# setters will get called before the scene is ready
	# that is okay for setting the variable above (it's independent of anything else in the scene)
	# but anything that depends on the scene being ready needs to wait for ready
	if not is_node_ready():
		await ready

	$Label.text = value


func set_value(v) -> void:
	value = str(v)

	if not is_node_ready():
		await ready

	$Value.text = value


func set_separator(value) -> void:
	separator = value

	if not is_node_ready():
		await ready

	if separator:
		$Separator.text = separator
		$Separator.show()
	else:
		$Separator.hide()


func set_suffix(value) -> void:
	suffix = value

	if not is_node_ready():
		await ready

	if suffix:
		$Suffix.text = suffix
		$Suffix.show()
	else:
		$Suffix.hide()


func set_total(value) -> void:
	total = value

	if not is_node_ready():
		await ready

	if total:
		$TotalSeparator.show()
		$Total.show()
		$Total.text = value
	else:
		$Total.hide()
		$TotalSeparator.hide()


func set_editable(value) -> void:
	editable = value

	if not is_node_ready():
		await ready

	$LineEdit.visible = value
