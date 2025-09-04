extends Node

class_name CodebaseExporter

# Main function to export the entire codebase
func export_codebase_to_file(output_path: String = "res://codebase_export.txt", filter = true) -> void:
	var project_name = ProjectSettings.get_setting("application/config/name", "UNNAMED PROJECT")
	var output_content = project_name + "\n\n"
	
	# Start from the root directory
	output_content += _process_directory("res://", "", filter)
	
	# Write to file
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		file.store_string(output_content)
		file.close()
		print("Codebase exported to: ", output_path)
	else:
		print("Error: Could not create output file at ", output_path)

# Recursively process directories
func _process_directory(dir_path: String, indent: String, filter = true) -> String:
	var dir = DirAccess.open(dir_path)
	if not dir:
		print("Error: Could not open directory ", dir_path)
		return ""
	
	var content = ""
	var folder_name = dir_path.get_file()
	if folder_name == "":
		folder_name = "ROOT"
	
	# Add folder header
	content += indent + folder_name.to_upper() + ":\n"
	
	# Collect all files and subdirectories
	var script_files = []
	var non_script_files = []
	var subdirs = []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		if dir.current_is_dir():
			# Skip hidden directories and common Godot directories that don't contain user scripts
			if not file_name.begins_with(".") and file_name != "addons" and file_name != ".godot":
				subdirs.append(full_path)
		else:
			# Separate script files from non-script files
			if _is_script_file(file_name):
				script_files.append(full_path)
			elif filter and _is_ignored_file(file_name):
				pass
			else:
				non_script_files.append(file_name)
		file_name = dir.get_next()
	
	# Display non-script files as simple filenames
	for file_name2 in non_script_files:
		content += indent + "    " + file_name2 + "\n"
	
	# Process script files in current directory
	for file_path in script_files:
		content += _process_script_file(file_path, indent)
	
	# Recursively process subdirectories
	for subdir_path in subdirs:
		content += _process_directory(subdir_path, indent + "  ")
	
	return content

# Process individual script files
func _process_script_file(file_path: String, indent: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error: Could not read file ", file_path)
		return ""
	
	var script_content = file.get_as_text()
	file.close()
	
	var file_name = file_path.get_file()
	var content = ""
	
	content += indent + "_______________\n"
	content += indent + "(" + file_name + "):\n"
	
	# Add each line of the script with proper indentation
	var lines = script_content.split("\n")
	for line in lines:
		content += indent + line + "\n"
	
	content += indent + "_______________\n"
	
	return content

func _is_ignored_file(file_name: String) -> bool:
	var script_extensions = [".import", ".gitattributes", ".gitignore", ".aseprite", ".uid", ".tmp"]  # Add more extensions as needed
	for ext in script_extensions:
		if file_name.ends_with(ext):
			return true
	return false

# Check if file is a script file
func _is_script_file(file_name: String) -> bool:
	var script_extensions = [".gd", ".cs", ".vs", ".fs", ".gdshader"]  # Add more extensions as needed
	for ext in script_extensions:
		if file_name.ends_with(ext):
			if file_name.begins_with("codebase"):
				return false
			return true
	return false

# Convenience function to call from anywhere
func _ready():
	# Uncomment the line below to automatically export on scene load
	export_codebase_to_file()
	pass

# You can also call this function from the Godot editor
func _export_codebase():
	export_codebase_to_file()
