class_name Log

const LOG_SHOW = true

enum Level { DEBUG, INFO, WARN, ERROR }

## category can be a string or a value from Category enum
## objects can be an array or a single basic type
static func print_log(objects, category: String, level: int = Level.DEBUG):
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

	var final_str = "[%s] [%s] [%s] %s" % [
		Time.get_datetime_string_from_system(false, true),
		Level.keys()[level],
		category,
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


static func d(objects, category = "") -> void:
	print_log(objects, category, Level.DEBUG)

static func i(objects, category = "") -> void:
	print_log(objects, category, Level.INFO)

static func w(objects, category = "") -> void:
	print_log(objects, category, Level.WARN)

static func e(objects, category = "", error_code = 0) -> void:
	print_log(objects, category, Level.ERROR)
