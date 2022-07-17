tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("InputRecorder", "res://addons/hasa1002.input_macros/recorder.tscn")
	add_autoload_singleton("InputPlayback","res://addons/hasa1002.input_macros/playback.tscn" )


func _exit_tree() -> void:
	remove_autoload_singleton("InputRecorder")
	remove_autoload_singleton("InputPlayback")
