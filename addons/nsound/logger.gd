extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

const LOG_SHOW = true

var registered_context: String = ""

#class LoggerClass:

## objects can be an array or a single basic type
func print_log(objects, context = null, level: int = Level.DEBUG):
	# Don't log if globally off
	if not LOG_SHOW: return
#	if config.log_hide_level.has(level) and config.log_hide_level[level] == true: return

	# Format objects depending on type
	var objects_str = ""
	if objects is Array:
		for obj in objects:
			objects_str += str(obj) + " "
		objects_str = objects_str.trim_suffix(" ")
	else:
		objects_str = str(objects)

	var context_str = registered_context
	if context:
		if context is String:
			context_str = context
		elif context is Object:
			context_str = context.get_script().resource_path.get_file().trim_suffix(".gd")

	var final_str = "[%s] [%s] [%s] %s" % [
		Time.get_datetime_string_from_system(false, true),
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


# inspired by godot heightmap plugin
# https://github.com/Zylann/godot_heightmap_plugin/blob/master/addons/zylann.hterrain/util/logger.gd
# but instead of returning a new instance from a static function
# we simply initialize when already instanced
# var Log = preload("res://addons/nsound/logger.gd").new().init(self)
# this has the advantage that it's fully compatible with using this class as an autoload
# it's up to the user whether to initialize the instance or just call the autoload methods
func init(owner):
	if owner is Object:
		registered_context = owner.get_script().resource_path.get_file().trim_suffix(".gd")
	elif owner is String:
		registered_context = owner

	return self
