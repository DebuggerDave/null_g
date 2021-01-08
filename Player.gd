extends KinematicBody2D

const MAX_ACCELERATION: int = 100
const MAX_SPEED: int = 1000
const JUMP_DISTANCE: int = 10
const MAX_SNAP_ANGLE: float = PI / 4

var tileMap := preload("res://TileMap.gd")
var grounded := false
var floorNormal := Vector2()
var velocity := Vector2(0, 100)
var lastCollision := Vector2()
var lastMovement := Vector2()
var rayCast := RayCast2D.new()

func _init():
	rayCast.set_name("floorQuery")
	add_child(rayCast)
	rayCast.set_enabled(true)
	
	
func _physics_process(delta: float) -> void:
	if grounded:
		get_new_velocity(delta)
		
	var movement: Vector2 = velocity * delta
	var moved: bool = not movement.is_equal_approx(Vector2())
	var collision: KinematicCollision2D = null
	
	while (not movement.is_equal_approx(Vector2())):
		lastMovement = movement
		collision = move_and_collide(movement)
		if (collision && (collision.get_collider() is tileMap)):
			grounded = true
			lastCollision = collision.position
			floorNormal = collision.get_normal()
			movement = collision.get_remainder()
			movement -= movement * floorNormal.abs()
			velocity -= velocity * floorNormal.abs()
		else:
			movement = Vector2()
			var foundFloor: bool = false
			var space_state: Physics2DDirectSpaceState = get_world_2d().get_direct_space_state()
			
			# Look down
			var rayEnd: Vector2 = lastCollision + lastMovement
			var rayStart: Vector2 = rayEnd + floorNormal
			rayCast.set_cast_to(rayEnd - get_position())
			rayCast.position = rayStart - get_position()
			rayCast.force_raycast_update()
			if (rayCast.is_colliding() && (rayCast.get_collider() is tileMap)):
				lastCollision = rayCast.get_collision_point()
				floorNormal = rayCast.get_collision_normal()
				foundFloor = true
			else:
				pass
			
			# Look back
			rayEnd = lastCollision
			rayStart = lastCollision + lastMovement
			rayCast.set_cast_to(rayEnd - get_position())
			rayCast.position = rayStart - get_position()
			rayCast.force_raycast_update()
			if (rayCast.is_colliding() && (not foundFloor)):
				var rotation: float = floorNormal.angle_to(rayCast.get_collision_normal())
				if ((rayCast.get_collider() is tileMap) && (rotation <= MAX_SNAP_ANGLE)):
					var moveBack: Vector2 = rayCast.get_collision_point() - rayStart
					move_and_collide(moveBack)
					lastCollision = rayCast.get_collision_point()
					movement += moveBack
					movement = movement.rotated(rotation)
					velocity = velocity.rotated(rotation)
					floorNormal = rayCast.get_collision_normal()
					foundFloor = true
			
			if foundFloor == false:
				pass
			
			grounded = foundFloor

# Only call in _physics_process
func floor_normal(collision_normal: Vector2, collision_point: Vector2, object: Object) -> Vector2:
	var space_state: Physics2DDirectSpaceState = get_world_2d().get_direct_space_state()
	var rayEnd: Vector2 = lastCollision + lastMovement
	var rayStart: Vector2 = rayEnd + floorNormal
	var rayCollision: Dictionary = space_state.intersect_ray(rayStart, rayEnd, [self])
	return Vector2()

func aggregate_floor_normals(floorNormal: Vector2) -> Vector2:
	var aggregate := Vector2(floorNormal.x, floorNormal.y)
	var original_direction: Vector2 = floorNormal * -1
	
	for deg in range(90, 360, 90):
		var rads: float = deg * PI / 180
		var query_direction: Vector2 = original_direction.rotated(rads)
		var testCollision: KinematicCollision2D = move_and_collide(query_direction, true, true, true)
		if (testCollision && (testCollision.get_collider() is tileMap)):
			aggregate += testCollision.get_normal()
		
	return aggregate

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
