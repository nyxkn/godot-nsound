extends Node

# load instead of preload to avoid cyclic reference
var Utils = load("res://addons/nsound/utils.gd")

enum Level { DEBUG, INFO, WARN, ERROR }

const LOG_SHOW := true


var _registered_context: String = ""


# when calling new() you want to pass in a context name or the object self
# var Log = preload("res://addons/nsound/logger.gd").new(self)
# but actually if we use the call stack method you don't need either, and make this param optional
func _init(context):
	if context is Object:
		_registered_context = context.get_script().resource_path.get_file().trim_suffix(".gd")
	elif context is String:
		_registered_context = context


func print_log(objects, context = null, level: int = Level.DEBUG):
	# Don't log if globally off
	if not LOG_SHOW: return

	# Format objects depending on type
	var objects_str = ""
	if objects is Array:
		for obj in objects:
			objects_str += str(obj) + " "
		objects_str = objects_str.trim_suffix(" ")
	else:
		objects_str = str(objects)

	var context_str = ""
	if context:
		if context is String:
			context_str = context
		elif context is Object:
			context_str = context.get_script().resource_path.get_file().trim_suffix(".gd")
	else:
		context_str = _registered_context

	var final_str = "[%s] [%s] [%s] %s" % [
		Time.get_time_string_from_system(),
		Level.keys()[level],
		context_str,
		objects_str]

	final_str = final_str.replace(" [] ", " ")

	if level == Level.ERROR:
		printerr(final_str)
		push_error(final_str)
	elif level == Level.WARN:
		print(final_str)
		push_warning(final_str)
	else:
		print(final_str)


func d(objects, context = "") -> void:
	print_log(objects, context, Level.DEBUG)

func i(objects, context = "") -> void:
	print_log(objects, context, Level.INFO)

func w(objects, context = "") -> void:
	print_log(objects, context, Level.WARN)

func e(objects, context = "", error_code = 0) -> void:
	print_log(objects, context, Level.ERROR)


func trace():
	var stack = Utils.tail(get_stack())
	Utils.pretty_print(stack)
#	Utils.pretty_print(Utils.tail(get_stack()))



