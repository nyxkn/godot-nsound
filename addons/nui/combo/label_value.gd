tool
extends HBoxContainer


signal value_changed(value)

# these setters get called on scene reload as long as a custom value was provided
# they won't get called on reload if the value is the default value defined here
# note, these get called BEFORE _ready. so anything you do in _ready will override these
export(String) var label: String = "" setget set_label
export(String) var value: String = "" setget set_value
export(String) var separator: String = "" setget set_separator
export(String) var total: String = "" setget set_total
export(bool) var editable: bool = false setget set_editable

# this setup seems to be the best possible. this has been reviewed a few times.
# it's better than manually setting label text in _ready
# because this way we get to make use of the export setget fully
func _ready() -> void:
	$Separator.visible = false
	# calling set_label so we update the label to "name" if no label was provided
	# we cannot set text here otherwise the setget will be overridden
	if not label: set_label(label)


func set_label(value) -> void:
	label = str(value)
	if label:
		$Label.text = value
	else:
		$Label.text = name


func set_value(v) -> void:
	value = str(v)
	$Value.text = value


func set_separator(value) -> void:
	separator = str(value)
	if separator:
		$Separator.text = separator
		$Separator.show()
	else:
		$Separator.hide()


func set_total(value) -> void:
	total = str(value)
	if total:
		$TotalSeparator.show()
		$Total.show()
		$Total.text = value
	else:
		$Total.hide()
		$TotalSeparator.hide()


func set_editable(value) -> void:
	editable = value
	$LineEdit.visible = value


func _on_LineEdit_text_entered(new_text: String) -> void:
	self.value = new_text
	emit_signal("value_changed", value)
