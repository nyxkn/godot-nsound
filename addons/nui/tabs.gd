tool
extends VBoxContainer

# usage
# you can instance this node and add a child container named "TabsContainer",
# under which you'll place the tabs
# you can nest TabsContainer wherever you want. we use find_node to look for it
# or you can instance this node and make it local if you need more customization

# set this to true if you plan to initialize this later and not on _ready()
export var lazy_init = false

#var first_focus := []
var tabs := []

onready var tabs_container: Control = find_node("TabsContainer")
onready var tab_buttons: HBoxContainer = $TabButtons


func _ready() -> void:
	if !lazy_init:
		init()
	else:
		Log.w("initialization skipped because lazy_init is set. remember to call init manually", name)


func init() -> void:
	if not tabs_container:
		Log.e("failed to initialize: no \"TabsContainer\" child found", name)
		return

	tabs = tabs_container.get_children()
#	assert(tabs.size() > 0, "Tabs failed to initialize: no tabs found in tabscontainer")
	if tabs.size() == 0:
		Log.e("failed to initialize: no tabs found under TabsContainer")
		return

	# removing placeholder buttons
	for b in tab_buttons.get_children():
		tab_buttons.remove_child(b)
		b.queue_free()

	var button_group: ButtonGroup = ButtonGroup.new()
	for t in tabs:
		var tab_name = t.name
		var button = Button.new()
		button.name = tab_name
		button.text = tab_name
		button.toggle_mode = true
		button.group = button_group
		button.connect("toggled", self, "_tab_button_toggled", [tab_name])
		tab_buttons.add_child(button)

	for i in tabs_container.get_child_count():
		var tab = tabs_container.get_child(i)
		# we need to set to visible to find the right next_valid_focus control
		tab.show()
		var next_focus: Control = tab.find_next_valid_focus()
		next_focus.focus_neighbour_top = next_focus.get_path_to(tab_buttons.get_child(i))
		tab.hide()

	# this also triggers the toggled signal
	# our toggled function also hides all unnecessary tabs
	tab_buttons.get_child(0).pressed = true


func hide_tabs() -> void:
	for tab in tabs_container.get_children():
		tab.visible = false


func show_tab(tab_name: String) -> void:
	hide_tabs()
#	Log.d(["showing tab:", tab_name], name)
	tabs_container.get_node(tab_name).show()


func _tab_button_toggled(toggled: bool, tab_name: String) -> void:
	if toggled:
		show_tab(tab_name)


#func _clips_input() -> bool:
#	return true
