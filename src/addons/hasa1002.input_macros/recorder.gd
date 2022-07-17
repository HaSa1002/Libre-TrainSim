extends WindowDialog


var is_recording := false
var out : File = null
var desired_close := false
var timeout : float = 0
var mouse_state := 0


func _ready() -> void:
	set_process_input(false)
	set_process(false)
	if !InputMap.has_action("input_recorder"):
		var ir := InputEventKey.new()
		ir.scancode = KEY_F11
		ir.shift = true
		InputMap.add_action("input_recorder")
		InputMap.action_add_event("input_recorder", ir)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_released("input_recorder", true):
		if visible:
			desired_close = true
			Input.set_mouse_mode(mouse_state)
			hide()
			desired_close = false
		else:
			mouse_state = Input.get_mouse_mode()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			popup_centered()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_released("input_recorder", true):
		return
	if !$Controls/MouseMove.pressed and event is InputEventMouseMotion:
		return
	if !$Controls/KeyboardInput.pressed and event is InputEventKey:
		return
	if !$Controls/MouseButton.pressed and event is InputEventMouseButton:
		return

	if !is_zero_approx(timeout):
		out.store_string(var2str(timeout) + "\n")
		timeout = 0

	out.store_string(var2str(event))


func _process(delta: float) -> void:
	timeout += delta


func start_recording(path: String):
	$Controls/StartStop.text = "Stop Recording"
	$Controls/Pause.disabled = false
	set_process_input(true)
	set_process(true)
	is_recording = true
	create_file(path)
	timeout = 0


func stop_recording():
	$Controls/StartStop.text = "Start Recording"
	$Controls/Pause.disabled = true
	set_process_input(false)
	set_process(false)
	is_recording = false
	if out:
		out.close()
		out = null


func create_file(path: String):
	var dir := Directory.new()
	if dir.make_dir_recursive(path.get_base_dir()) != OK:
		Logger.err("Failed to create file path. Aborting recording.", path)
		stop_recording()
		return
	out = File.new()
	if out.open(path, File.WRITE) != OK:
		Logger.err("Failed to open file for writing. Aborting recording.", path)
		stop_recording()
		return


func _on_StartStop_pressed() -> void:
	if is_recording:
		stop_recording()
		return
	$FileDialog.popup_centered()


func _on_FileDialog_file_selected(path: String) -> void:
	start_recording(path)


func _on_Pause_pressed() -> void:
	if is_processing_input():
		$Controls/Pause.text = "Continue"
		set_process_input(false)
		set_process(false)
	else:
		$Controls/Pause.text = "Pause"
		set_process_input(true)
		set_process(true)


func _on_popup_hide() -> void:
	if desired_close:
		return
	show()
