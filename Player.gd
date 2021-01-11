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
var rayCast := RayCast2D.new()

func _init():
	rayCast.set_name("floorQuery")
	add_child(rayCast)
	rayCast.set_enabled(true)
	
	
func _physics_process(delta: float) -> void:
	if grounded:
		get_new_velocity(delta)
	var movement: Vector2 = velocity * delta
	
	while (not movement.is_equal_approx(Vector2())):
		var collision: KinematicCollision2D = move_and_collide(movement)
		if (collision && (collision.get_collider() is tileMap)):
			grounded = true
			floorNormal = collision.get_normal()
			lastCollision = collision.position
			movement = collision.get_remainder()
			movement -= movement * floorNormal.abs()
			velocity -= velocity * floorNormal.abs()
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
	var movement := Vector2()
	
	
	
	# Look torwards floor
	var rayEnd: Vector2 = lastCollision + lastMovement - floorNormal
	var rayStart: Vector2 = lastCollision + lastMovement + floorNormal
	rayCast.set_cast_to(rayEnd - get_position())
	rayCast.position = rayStart - get_position()
	rayCast.force_raycast_update()
	var ah = rayCast.is_colliding()
	var ahh = rayCast.get_collider() is tileMap
	var ahhh = rayCast.get_collision_normal() == floorNormal
	
	var space_state = get_world_2d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(rayStart, rayEnd, [self])
	if ((not result.empty()) &&
		(result["collider"] is tileMap) &&
		(not grounded)
	):
		lastCollision = line_intersection(floorNormal.rotated(PI/2), lastCollision, floorNormal, result["position"])
		grounded = true
	else:
		pass
	
	# Look back
	rayEnd = lastCollision
	rayStart = rayEnd + lastMovement
	rayCast.set_cast_to(rayEnd - get_position())
	rayCast.position = rayStart - get_position()
	rayCast.force_raycast_update()
	result = space_state.intersect_ray(rayStart - floorNormal, rayEnd - floorNormal, [self])
	if ((not result.empty()) && (not grounded)):
		var rotation: float = floorNormal.angle_to(result["normal"])
		if ((abs(rotation) <= MAX_SNAP_ANGLE) && (result["collider"] is tileMap)):
			var rotationTransform: Transform2D = Transform2D(rotation, Vector2())
			var lastFloorNormal: Vector2 = floorNormal
			floorNormal = result["normal"]
			lastCollision = line_intersection(floorNormal.rotated(PI/2), result["position"], lastFloorNormal.rotated(PI/2), lastCollision)
			var adjustForRotation: Vector2 = rayStart - (rotationTransform.basis_xform(rayStart - get_position()) + get_position())
			var moveBack: Vector2 = lastCollision - rayStart
			set_rotation(get_rotation() + rotation)
			set_position(get_position() + adjustForRotation + moveBack)
			movement -= moveBack
			movement = movement.rotated(rotation)
			velocity = velocity.rotated(rotation)

			grounded = true
			
			var randomAngle: float = floorNormal.angle_to(Vector2.DOWN)
			movement = (movement.rotated(randomAngle) - (floorNormal.rotated(randomAngle) * movement.rotated(randomAngle))).rotated(-randomAngle)
			velocity = (velocity.rotated(randomAngle) - (floorNormal.rotated(randomAngle) * velocity.rotated(randomAngle))).rotated(-randomAngle)
			
	return movement

# I don't trust rayCast.get_collision_point(), I don't think it returns vertex points?
func get_actual_collision_point() -> Vector2:
	var rayEnd: Vector2 = rayCast.get_cast_to() + get_position()
	var rayStart: Vector2 = rayCast.position + get_position()
	return line_intersection(
		rayCast.get_collision_normal().rotated(PI/2),
		rayCast.get_collision_point(),
		rayEnd - rayStart,
		rayStart
	)

func line_intersection(direction1: Vector2, point1: Vector2, direction2: Vector2, point2: Vector2) -> Vector2:
	var intersection := Vector2()
	
	if (direction1.is_equal_approx(Vector2(0, direction1.y)) && direction2.is_equal_approx(Vector2(0, direction2.y))):
		intersection = Vector2.INF
	elif (direction1.is_equal_approx(Vector2(0, direction1.y)) && (not direction2.is_equal_approx(Vector2(0, direction2.y)))):
		var slope2: float = direction2.y / direction2.x
		var intercept2: float = point2.y - (slope2 * point2.x)
		intersection.x = point1.x
		intersection.y = (intersection.x * slope2) + intercept2
	elif ((not direction1.is_equal_approx(Vector2(0, direction1.y))) && direction2.is_equal_approx(Vector2(0, direction2.y))):
		var slope1: float = direction1.y / direction1.x
		var intercept1: float = point1.y - (slope1 * point1.x)
		intersection.x = point2.x
		intersection.y = (intersection.x * slope1) + intercept1
	else:
		var slope1: float = direction1.y / direction1.x
		var slope2: float = direction2.y / direction2.x
		var intercept1: float = point1.y - (slope1 * point1.x)
		var intercept2: float = point2.y - (slope2 * point2.x)
		if (slope1 == slope2):
			intersection = Vector2.INF
		else:
			intersection.x = (intercept2 - intercept1) / (slope1 - slope2)
			intersection.y = (intersection.x * slope1) + intercept1
	
	return intersection

func centered_floor_contact_point(borderPoint: Vector2) -> Vector2:
	return line_intersection(floorNormal.rotated(PI/2).abs(), borderPoint, floorNormal.abs(), get_position())

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
		
		var rotateX: float = Vector2.DOWN.angle_to(floorNormal)
		rotateX = wrapf(rotateX, -PI/2, PI/2)
		if (rotateX > PI/2):
				rotateX = (PI/2) - rotateX
				
		var rotateY: float = Vector2.RIGHT.angle_to(floorNormal)
		rotateY = wrapf(rotateY, -PI/2, PI/2)
		if (rotateY > PI/2):
				rotateY = (PI/2) - rotateX
		
		var moveTransform: Vector2 = floorNormal.rotated(PI/2).abs()
		var velocityX: Vector2 = Vector2(moveDir.x, 0) * moveTransform * MAX_ACCELERATION * delta
		velocityX = velocityX.rotated(rotateX)
		var velocityY: Vector2 = Vector2(0, moveDir.y) * moveTransform * MAX_ACCELERATION * delta
		velocityY = velocityY.rotated(rotateY)
		velocity += velocityX + velocityY
			
		if Input.is_action_just_pressed("jump"):
			grounded = false
			velocity += aggregate_floor_normals(floorNormal) * JUMP_DISTANCE / delta
