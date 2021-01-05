extends KinematicBody2D

const MOVE_SCALAR: int = 10
const JUMP_SCALAR: int = 10

var velocity := Vector2(0, 1)
var tile := preload("res://TileMap.gd")
var floorNormal := Vector2(0, 0)
var grounded := false

func _physics_process(delta: float):
	if grounded:
		var moveDir := Vector2(0, 0)
		if Input.is_action_pressed("move_right"):
			moveDir.x += 1
		if Input.is_action_pressed("move_left"):
			moveDir.x -= 1
		if Input.is_action_pressed("move_down"):
			moveDir.y += 1
		if Input.is_action_pressed("move_up"):
			moveDir.y -= 1
			
		var moveTransform: Vector2 = floorNormal.rotated(PI/2).abs()
		velocity += moveDir * moveTransform * MOVE_SCALAR * delta
	
		if Input.is_action_just_pressed("jump"):
			velocity += floorNormal * JUMP_SCALAR
			grounded = false
	
	var collision: KinematicCollision2D = move_and_collide(velocity)
	if (collision && (collision.get_collider() is tile)):
		grounded = true
		floorNormal = collision.get_normal()
		velocity -= velocity * floorNormal.abs()
