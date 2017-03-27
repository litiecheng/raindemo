extends Node2D


func _ready():
	set_process( true )

func _process( delta ):
	if Input.is_key_pressed( KEY_ESCAPE ):
		get_tree().quit()
	get_node( "CanvasLayer/fps_label" ).set_text(str(OS.get_frames_per_second()))
