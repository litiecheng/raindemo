extends KinematicBody2D

var input_states = preload( "res://input_states.gd" )
var btn_left = input_states.new( "btn_left" )
var btn_right = input_states.new( "btn_right" )
var anim_cur = ""
var anim_nxt = "idle"
var dir_cur = ""
var dir_nxt = "right"
var speed = 0
const MAX_SPEED = 50
const ACCEL = 10

func _ready():
	set_fixed_process( true )
func _fixed_process( delta ):
	if btn_left.check() == 2:
		anim_nxt = "walk"
		dir_nxt = "left"
		speed = lerp( speed, -MAX_SPEED, ACCEL * delta )
	elif btn_right.check() == 2:
		anim_nxt = "walk"
		dir_nxt = "right"
		speed = lerp( speed, MAX_SPEED, ACCEL * delta )
	else:
		anim_nxt = "idle"
		speed = lerp( speed, 0, 3 * ACCEL * delta )
	
	if dir_nxt != dir_cur:
		dir_cur = dir_nxt
		if dir_cur == "right":
			get_node( "Sprite" ).set_scale( Vector2( 1, 1 ) )
		else:
			get_node( "Sprite" ).set_scale( Vector2( -1, 1 ) )
	if anim_cur != anim_nxt:
		anim_cur = anim_nxt
		get_node( "AnimationPlayer" ).play( anim_cur )
	
	var motion = Vector2( speed, 0 ) * delta
	move( motion )
	