extends WindowDialog


var macro : File = null
var mouse_state := 0


func _ready() -> void:
	if !InputMap.has_action("input_playback"):
		var ir := InputEventKey.new()
		ir.scancode = KEY_F11
		ir.control = true
		InputMap.add_action("input_playback")
		InputMap.action_add_event("input_playback", ir)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_released("input_playback", true):
		if visible:
			Input.set_mouse_mode(mouse_state)
			hide()
		else:
			mouse_state = Input.get_mouse_mode()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			popup()


func display_macros():
	$Macros.clear()
	var dir := Directory.new()
	if dir.open("user://screenshot_macros/") != OK:
		Logger.warn("Folder does not exists. Please record macros first.", self)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue

		$Macros.add_item("user://screenshot_macros/".plus_file(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func play_macro(path: String):
	if macro:
		stop_macro()
	macro = File.new()
	if macro.open(path, File.READ) != OK:
		Logger.err("Failed to open macro for reading", path)
		return

	continue_macro()


func stop_macro():
	macro.close()
	macro = null


func continue_macro():
	if !macro:
		Logger.err("Continued macro with having one", self)
		return
	while !macro.eof_reached():
		var obj = str2var(macro.get_line())
		if obj is InputEvent:
			Input.parse_input_event(obj)
		if obj is float:
			get_tree().create_timer(obj).connect("timeout", self, "_on_Timer_timeout")
			return


func _on_Playback_about_to_show() -> void:
	display_macros()


func _on_Macros_item_activated(index: int) -> void:
	Input.set_mouse_mode(mouse_state)
	hide()
	play_macro($Macros.get_item_text(index))


func _on_Timer_timeout() -> void:
	if macro:
		continue_macro()
