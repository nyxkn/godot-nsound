
# it's useless to load the Log class since static functions cannot use it
# workaround is to make use of the Log instance of NAudio autoload

# ================
# utils
# ================


static func get_all_children(node: Node) -> Array:
	var children := []

	for child in node.get_children():
		children.append(child)

		if child.get_child_count() > 0:
			children.append_array(get_all_children(child))

	return children


static func merge_dict(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged = a.duplicate()
	for key in b:
		merged[key] = b[key]

	return merged


static func setup_buses(node: Bus) -> void:
	var children = get_all_children(node)
	children.push_front(node)
	for child in children:
		if child is Bus:
			var parent_node = child.get_parent()
			var send_bus
			if parent_node is Song and not parent_node is Section:
#				send_bus = NAudio.music_bus
				send_bus = parent_node.bus_name
			elif parent_node is AudioServerBus:
				send_bus = parent_node.bus_name
			else:
				send_bus = NAudio.music_bus
			child.init(send_bus)


# ================
# string utils
# ================


static func compile_regex(regex_string: String) -> RegEx:
	var re := RegEx.new()
	re.compile(regex_string)
	if not re.is_valid():
		NAudio.Log.e(['warning: regex', regex_string, 'is not valid'], 'compile_regex')
	return re


static func get_filename(file_path: String, with_ext = true) -> String:
	var split = file_path.split("/")
	var file_name = split[-1]
	if not with_ext:
		file_name = file_name.split(".")[0]
	return file_name


static func is_alphanumeric(s: String) -> bool:
	var re = compile_regex("^[a-zA-Z0-9]*$")
#	var result =
	if re.search(s):
		return true
	return false


static func camel_to_snake(string: String) -> String:
	var result := PoolStringArray()
#	var result := ""
	var prev_is_number = false
#	var prev_is_symbol = false

	for i in string.length():
		var ch = string[i]
		var ascii = ch.to_ascii()[0]

		if ascii >= 48 and ascii <= 57:
			# this is a number
			if prev_is_number:
				# if this is a second number after a first number, leave unchanged
				result.append(ch)
			else:
				# mark this as being a number. 1 becomes _1
				# treating this the same as an uppercase letter
				# at times no underscore before a number looks better
				# but this is an automated translation
				# so let's be consistent and use the simple generic approach
				result.append('_' + ch)
				prev_is_number = true
		else:
			# this is a letter
			if is_alphanumeric(ch) and ch == ch.to_upper():
				# uppercase letter L becomes _l
				result.append('_' + ch.to_lower())
			else:
				# this is a lowercase letter or a symbol. leave as is
				result.append(ch)
			prev_is_number = false

	var result_str = result.join('')
	# remove accidental double underscores. e.g. if there's already an underscore before a number
	result_str = result_str.replace("__", "_")

	return result_str


static func pascal_to_snake(string: String) -> String:
	var s := camel_to_snake(string)
	s = s.lstrip("_")
	return s


# ================
# file utils
# ================


static func dir_exists(dir_path: String) -> bool:
	var dir = Directory.new()
	return dir.dir_exists(dir_path)


static func print_file_error(err: int, file_path: String = "", category = "FileUtils"):
	if category != "FileUtils":
		category = "FileUtils." + category

	NAudio.Log.e(["error while opening file: ", file_path], category, err)


static func get_files_in_dir_recursive(dir_path: String, ext: String = "", regex = null) -> Array:
	var files := []

	# running once without constraints so that we also read directories
	var dir_files = get_files_in_dir(dir_path)
	for f in dir_files:
		if dir_exists(f):
			files.append_array(get_files_in_dir_recursive(f, ext, regex))

	# running a second time with the required constraints
	files.append_array(get_files_in_dir(dir_path, ext, regex))

	return files
#	return get_files_in_dir_recursive(


## find files in directory. return matching filenames
## if no ext or regex is provided, list all files (except .import)
## if ext provided we match file extension. if ext passed has no leading dot we'll add it.
## if regex provided we match regex (ignores ext param)
## TODO named parameters would be better here
## regex is either a compiled RegEx or a string
static func get_files_in_dir(dir_path: String, ext: String = "", regex = null) -> Array:
	if regex is String:
		regex = compile_regex(regex)
	if ext and not ext.begins_with("."):
		ext = "." + ext

	dir_path = dir_path.trim_suffix("/")

	var dir: Directory = Directory.new()

	var files := []

	var err = dir.open(dir_path)
	if err == OK:
		dir.list_dir_begin(true)
		var file_name = dir.get_next()
		while file_name != "":
			var matching = false
			if !ext and !regex and !file_name.ends_with(".import"):
				matching = true
			elif regex and regex.search(file_name):
				matching = true
			elif ext and file_name.ends_with(ext):
				matching = true

			if matching:
				files.append(dir_path + "/" + file_name)

			file_name = dir.get_next()
	else:
		print_file_error(err, dir_path, "get_files_in_dir")
#		NAudio.Log.e(["error", err, "opening dir_path"], "get_files_in_dir")

	return files


## https://docs.godotengine.org/en/stable/classes/class_packedscene.html
## this saves the node and all the nodes it owns
## if you want the children to be saved, make sure node owns them
static func save_scene(dir_path: String, node: Node, tscn: bool = false) -> void:
	if not dir_exists(dir_path):
		NAudio.Log.e(["directory", dir_path, "does not exist"], "save_scene")
		return

	var scene = PackedScene.new()
	var scene_name = pascal_to_snake(node.name)
	var extension = ".scn"
	if tscn:
		extension = ".tscn"
	var file_path = dir_path + "/" + scene_name + extension

	var result = scene.pack(node)
	if result == OK:
		var err = ResourceSaver.save(file_path, scene)
		if err != OK:
			NAudio.Log.e(["an error occurred while saving scene", file_path, "to disk"], "save_scene", err)


