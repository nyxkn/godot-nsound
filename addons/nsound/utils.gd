# it's useless to load the Log class since static functions cannot use it
# workaround is to make use of the Log instance of NSound autoload

# ================
# utils
# ================

static func tail(array: Array):
	return array.slice(1)

static func heads(array: Array):
	return array.slice(0, -1)


static func get_all_children(node: Node, type: String = "") -> Array:
	var children := []

	for child in node.get_children():
		if type == "" or child.get_class() == type:
			children.append(child)

		if child.get_child_count() > 0:
			children.append_array(get_all_children(child))

	return children


static func merge_dict(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged = a.duplicate()
	for key in b:
		merged[key] = b[key]

	return merged


# ================
# string utils
# ================


## string or regex
## if regex we just return it
## if string we compile the regex
static func compile_regex(regex_string: String) -> RegEx:
	var re := RegEx.new()
	re.compile(regex_string)
	if not re.is_valid():
		NSound.Log.e(['warning: regex', regex_string, 'is not valid'], 'compile_regex')
	return re


#static func get_scene_file_path(file_path: String, with_ext = true) -> String:
#	var split = file_path.split("/")
#	var file_name = split[-1]
#	if not with_ext:
#		file_name = file_name.split(".")[0]
#	return file_name


static func indent_print(tabs, str):
	print("\t".repeat(tabs), str)


static func pretty_print(data, indent = 0):
	if data is Array:
		indent_print(indent, "[")
	else:
		indent_print(indent, "{")

	for e in data:
		var key
		var value
		if data is Array:
			value = e
		else:
			key = e
			value = data[e]

		if value is Dictionary:
			if key != null:
				indent_print(indent+1, str(key, ":"))
			pretty_print(value, indent + 1)
		elif value is Array:
			pretty_print(value, indent + 1)
		else:
			indent_print(indent+1, str(key, ": ", value))
	indent_print(indent, "]" if data is Array else "}")


# ================
# file utils
# ================


static func dir_exists(dir_path: String) -> bool:
	return DirAccess.dir_exists_absolute(dir_path)


static func print_file_error(err: int, file_path: String = "", category = "FileUtils"):
	if category != "FileUtils":
		category = "FileUtils." + category

	NSound.Log.e(["error while opening file: ", file_path], category, err)


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


## find files in directory. return matching filenames
## if no ext or regex is provided, list all files (except super.import)
## if ext provided we match file extension. if ext passed has no leading dot we'll add it.
## if regex provided we match regex (ignores ext param)
## TODO named parameters would be better here
## regex is either a compiled RegEx or a string
static func get_files_in_dir(dir_path: String, ext: String = "", regex = null) -> Array:
	if regex is String:
		regex = compile_regex(regex)
	if ext != "" and not ext.begins_with("."):
		ext = "." + ext

	var matching_files := []

	var dir = DirAccess.open(dir_path)
	if dir == null:
		NSound.Log.e(["error while opening file: ", dir_path], DirAccess.get_open_error())
		return []


	var dir_files = dir.get_files()
	for file_name in dir_files:
		var matching = false
		if ext == null and regex == null and !file_name.ends_with(".import"):
			matching = true
		elif regex and regex.search(file_name):
			matching = true
		elif ext != null and file_name.ends_with(ext):
			matching = true

		if matching:
			matching_files.append(dir_path + "/" + file_name)

		file_name = dir.get_next()

	return matching_files


## https://docs.godotengine.org/en/stable/classes/class_packedscene.html
## this saves the node and all the nodes it owns
## if you want the children to be saved, make sure node owns them
static func save_scene(dir_path: String, node: Node, tscn: bool = false) -> void:
	if not dir_exists(dir_path):
		NSound.Log.e(["directory", dir_path, "does not exist"], "save_scene")
		return

	var scene = PackedScene.new()
	var scene_name = node.name.to_snake_case()
	var extension = ".scn"
	if tscn:
		extension = ".tscn"
	var file_path = dir_path + "/" + scene_name + extension

	var result = scene.pack(node)
	if result == OK:
		var err = ResourceSaver.save(scene, file_path)
		if err != OK:
			NSound.Log.e(["an error occurred while saving scene", file_path, "to disk"], err)


