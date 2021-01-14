extends KinematicBody2D

const ACCELERATION: int = 1000
const MAX_SPEED: int = 10000
const JUMP_DISTANCE: int = 10
const MAX_SNAP_ANGLE: float = TAU / 8 

var tileMap := preload("res://TileMap.gd")
var grounded := false
var floorNormal := Vector2()
var velocity := Vector2(0, 100)
var lastCollision := Vector2()

# TODO debug line, remove later
onready var line = get_node("DEBUG_LINE")

func _physics_process(delta: float) -> void:
	if grounded:
		get_new_velocity(delta)
	var movement: Vector2 = velocity * delta
	
	while (not movement.is_equal_approx(Vector2())):
		var collision: KinematicCollision2D = move_and_collide(movement)
		
		if (collision && (collision.get_collider() is tileMap)):
			grounded = true
			lastCollision = collision.position
			floorNormal = collision.get_normal()
			movement = collision.get_remainder()
			
			# Cancel out movement into floor
			if (move_dir().is_equal_approx(Vector2())):
				movement = Vector2()
				velocity = Vector2()
			else:
				movement = movement.project(move_dir())
				velocity = velocity.project(move_dir())
				
			if (lastCollision != centered_floor_contact_point(collision.position)):
				var lastMovement: Vector2 = centered_floor_contact_point(collision.position) - lastCollision
				grounded = false
				movement += query_floor(lastMovement)
		else:
			var lastMovement: Vector2 = movement
			movement = Vector2()
			if grounded:
				grounded = false
				movement += query_floor(lastMovement)

func query_floor(lastMovement: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var errorMargin: Vector2 = -floorNormal
	
	# Look below
	var rayEnd: Vector2 = lastCollision + lastMovement + errorMargin
	var rayStart: Vector2 = lastCollision + lastMovement + floorNormal
	var result: Dictionary = space_state.intersect_ray(rayStart, rayEnd, [self])
	if (
		(not result.empty()) &&
		(result["collider"] is tileMap) &&
		floorNormal.is_equal_approx(result["normal"]) &&
		(not grounded)
	):
		lastCollision = result["position"]
		floorNormal = result["normal"]
		grounded = true
		return Vector2()
	
	# Look back towards last collision
	rayEnd = lastCollision + errorMargin
	rayStart = lastCollision + lastMovement
	result = space_state.intersect_ray(rayStart, rayEnd, [self])
	if ((not result.empty()) && (not grounded)):
		var rads: float = floorNormal.angle_to(result["normal"])
		if ((abs(rads) <= MAX_SNAP_ANGLE) && (result["collider"] is tileMap)):
			# Correct collision position for added errorMargin
			# Correct position is the intersection of our current plane and the next one
			lastCollision = line_intersection(move_dir().rotated(rads), result["position"], move_dir(), lastCollision)
			floorNormal = result["normal"]
			
			var rotation: Transform2D = Transform2D(rads, Vector2())
			var rotationAdjust: Vector2 = rayStart - (get_transform() * rotation * get_transform().inverse() * rayStart)
			var moveBack: Vector2 = lastCollision - rayStart
			set_rotation(get_rotation() + rads)
			set_position(get_position() + rotationAdjust + moveBack)
			
			var movement: Vector2 = -moveBack
			movement = movement.rotated(rads)
			velocity = velocity.rotated(rads)
			movement = movement.project(move_dir())
			velocity = velocity.project(move_dir())
			
			grounded = true
			return movement
			
	return Vector2()

func move_dir(turnTowards: Vector2 = velocity) -> Vector2:
	if (floorNormal.angle_to(turnTowards) > 0):
		return floorNormal.rotated(TAU/4)
	if (floorNormal.angle_to(turnTowards) < 0):
		return floorNormal.rotated(-TAU/4)
	else:
		return Vector2()

func line_intersection(dir1: Vector2, point1: Vector2, dir2: Vector2, point2: Vector2) -> Vector2:
	var planeNormal2D1: Vector2 = dir1.rotated(TAU/4)
	var plane1 := Plane(Vector3(planeNormal2D1.x, planeNormal2D1.y, 0), planeNormal2D1.dot(point1))
	
	var planeNormal2D2: Vector2 = dir2.rotated(TAU/4)
	var plane2 := Plane(Vector3(planeNormal2D2.x, planeNormal2D2.y, 0), planeNormal2D2.dot(point2))
	
	var frustum := Plane(Vector3(0, 0, 1), 0)
	
	var intersection = frustum.intersect_3(plane1, plane2)
	if (intersection != null):
		intersection = intersection as Vector3
		return Vector2(intersection.x, intersection.y)
	else:
		return Vector2.INF

func infinite_slope(slope: Vector2) -> bool:
	return slope.is_equal_approx(Vector2(0, slope.y))

func centered_floor_contact_point(borderPoint: Vector2) -> Vector2:
	return line_intersection(floorNormal.rotated(TAU/4), borderPoint, floorNormal, get_position())

func aggregate_floor_normals() -> Vector2:
	var aggregate := Vector2(floorNormal.x, floorNormal.y)
	var original_direction: Vector2 = floorNormal
	
	for rads in range(TAU/4, TAU, TAU/4):
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

		if ((not moveDir.is_equal_approx(Vector2(0, 0))) && (floorNormal.angle_to(moveDir) != 0)):
			var delta_velocity: float = ACCELERATION * delta
			var scale := Transform2D(Vector2((move_dir(moveDir).abs().x * delta_velocity), 0), Vector2(0, (move_dir(moveDir).abs().y * delta_velocity)), Vector2())
			velocity += (scale * moveDir).project(move_dir(moveDir))
			
		if Input.is_action_just_pressed("jump"):
			grounded = false
			velocity += aggregate_floor_normals() * JUMP_DISTANCE / delta
