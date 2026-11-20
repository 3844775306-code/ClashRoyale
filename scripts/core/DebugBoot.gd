extends Node

func _ready() -> void:
	var line := "[%s] DEBUG_BOOT exe=%s user=%s" % [Time.get_datetime_string_from_system(), OS.get_executable_path(), ProjectSettings.globalize_path("user://")]
	print("[DEBUG_BOOT] ", line)
	var exe_dir := OS.get_executable_path().get_base_dir()
	for p in ["C:/Users/18749/clash_boot_debug.log", exe_dir + "/clash_boot_debug.log", OS.get_environment("TEMP") + "/clash_boot_debug.log", "user://clash_boot_debug.log"]:
		var f := FileAccess.open(p, FileAccess.READ_WRITE)
		if f == null:
			f = FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)
			f.close()
