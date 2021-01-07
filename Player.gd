extends KinematicBody2D

const MAX_ACCELERATION: int = 100
const MAX_SPEED: int = 1000
const JUMP_DISTANCE: int = 10
const MAX_SNAP_ANGLE: int = 45

var tile := preload("res://TileMap.gd")
var grounded := false
var floorNormal := Vector2()
var velocity := Vector2(0, 100)
	
func _physics_process(delta: float) -> void:
	if grounded:
		get_new_velocity(delta)
		
	var movement: Vector2 = velocity * delta
	var lastMovement: Vector2 = movement
	var moved: bool = not movement.is_equal_approx(Vector2())
	var collision: KinematicCollision2D = null
	
	while (not movement.is_equal_approx(Vector2())):
		collision = move_and_collide(movement)
		lastMovement = movement
		if (tile_collision(collision)):
			grounded = true
			floorNormal = collision.get_normal()
			movement -= collision.get_travel() * movement.normalized()
			movement -= movement * floorNormal.abs()
			velocity -= velocity * floorNormal.abs()
		else:
			movement = Vector2()
			
	if (moved && not tile_collision(collision)):
		var floorQueryMag: float = ceil(tan(MAX_SNAP_ANGLE) * lastMovement.length())
		var floorQueryDir: Vector2 = lastMovement.rotated(floorNormal.angle_to(lastMovement)).normalized()
		var floorQuery: Vector2 = floorQueryDir * floorQueryMag
		var testCollision: KinematicCollision2D = move_and_collide(floorQuery, true, true, true)
		
		if (tile_collision(testCollision)):
			var moveAngle = floorNormal.angle_to(testCollision.get_normal())
			if (moveAngle < MAX_SNAP_ANGLE):
				move_and_collide(floorQuery)
				floorNormal = testCollision.get_normal()
				velocity = velocity.rotated(moveAngle)
				grounded = true
			else:
				grounded = false
				floorNormal = Vector2()
		else:
			grounded = false
			floorNormal = Vector2()
	
func aggregate_floor_normals(floorNormal: Vector2) -> Vector2:
	var aggregate := Vector2(floorNormal.x, floorNormal.y)
	var original_direction: Vector2 = floorNormal * -1
	
	for deg in range(90, 360, 90):
		var rads: float = deg * PI / 180
		var query_direction: Vector2 = original_direction.rotated(rads)
		var testCollision: KinematicCollision2D = move_and_collide(query_direction, true, true, true)
		if (tile_collision(testCollision)):
			aggregate += testCollision.get_normal()
		
	return aggregate
			
func tile_collision(collision: KinematicCollision2D) -> bool:
	return (
		collision &&
		(collision.get_collider() is tile)
	)

func get_new_velocity(delta: float) -> void:
		var moveDir := Vector2()
		
		if Input.is_action_pressed("move_right"):
			moveDir.x += 1
		if Input.is_action_pressed("move_left"):
			moveDir.x -= 1
		if Input.is_action_pressed("move_down"):
			moveDir.y += 1
		if Input.is_action_pressed("move_up"):
			moveDir.y -= 1
		
		var moveTransform: Vector2 = floorNormal.rotated(PI/2).abs()
		velocity += moveDir * moveTransform * MAX_ACCELERATION * delta
			
		if Input.is_action_just_pressed("jump"):
			velocity += aggregate_floor_normals(floorNormal) * JUMP_DISTANCE / delta
