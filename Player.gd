extends KinematicBody2D

const MOVE_SPEED = 500
const JUMP_FORCE = 1000
const GRAVITY = 10
const MAX_FALL_SPEED = 1000
const AntiGravityEnabled = false

onready var sprite = $Sprite

var y_velo = 0
var facing_right = false

func _physics_process(delta):
	var move_dir = 0
	if Input.is_action_pressed("move_right"):
		move_dir += 1
	if Input.is_action_pressed("move_left"):
		move_dir -= 1
	move_and_slide(Vector2(move_dir * MOVE_SPEED, y_velo), Vector2(0, -1))
	
	var groundeddown = is_on_floor()
	var groundedup = is_on_ceiling()
	print(groundeddown)
	y_velo += GRAVITY
	if groundeddown and Input.is_action_just_pressed("jump"):
		y_velo = -JUMP_FORCE
	if groundedup:
		y_velo = -500
		if groundedup and Input.is_action_just_pressed("jump"):
			y_velo = JUMP_FORCE	
	if y_velo > MAX_FALL_SPEED:
		y_velo = MAX_FALL_SPEED
	

func _on_AntiGravitychecker_body_entered(body):
	pass # Replace with function body.
