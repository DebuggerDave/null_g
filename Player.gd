extends KinematicBody2D

const MAX_ACCELERATION: int = 100
const MAX_SPEED: int = 1000
const JUMP_DISTANCE: int = 10
const MAX_SNAP_ANGLE: float = PI / 4

var tileMap := preload("res://TileMap.gd")
var grounded := false
var floorNormal := Vector2()
var velocity := Vector2(0, -100)
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
			if (lastCollision != floor_normal_border_point(collision.position)):
				var lastMovement: Vector2 = floor_normal_border_point(collision.position) - lastCollision
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
	var rayEnd: Vector2 = lastCollision + lastMovement
	var rayStart: Vector2 = rayEnd + floorNormal
	rayCast.set_cast_to(rayEnd - get_position())
	rayCast.position = rayStart - get_position()
	rayCast.force_raycast_update()
	if (rayCast.is_colliding() &&
		(rayCast.get_collider() is tileMap) &&
		(rayCast.get_collision_normal() == floorNormal) &&
		(not grounded)
	):
		floorNormal = rayCast.get_collision_normal()
		lastCollision = get_actual_collision_point()
		grounded = true
	else:
		pass
	
	# Look back
	rayEnd = lastCollision
	rayStart = rayEnd + lastMovement
	rayCast.set_cast_to(rayEnd - get_position())
	rayCast.position = rayStart - get_position()
	rayCast.force_raycast_update()
	if (rayCast.is_colliding() && (not grounded)):
		var rotation: float = floorNormal.angle_to(rayCast.get_collision_normal())
		if ((abs(rotation) <= MAX_SNAP_ANGLE) && (rayCast.get_collider() is tileMap)):
			set_rotation(get_rotation() + rotation)
			floorNormal = rayCast.get_collision_normal()
			lastCollision = get_actual_collision_point()
			var moveBack: Vector2 = lastCollision - rayStart
			move_and_collide(moveBack)
			movement -= moveBack
			movement = movement.rotated(rotation)
			velocity = velocity.rotated(rotation)
			grounded = true
			
	return movement

# I don't trust rayCast.get_collision_point(), I don't think it returns vertex points?
func get_actual_collision_point() -> Vector2:
	var rayEnd: Vector2 = rayCast.get_cast_to() + get_position()
	var rayStart: Vector2 = rayCast.position + get_position()
	return line_intersection(rayCast.get_collision_normal().rotated(PI/2), rayCast.get_collision_point(), rayStart, rayEnd - rayStart)

func line_intersection(direction1: Vector2, point1: Vector2, direction2: Vector2, point2: Vector2) -> Vector2:
	var intersection := Vector2()
	
	var slope1: float = direction1.y / direction1.x
	var slope2: float = direction2.y / direction2.x
	var intercept1: float = point1.y - (slope1 * point1.x)
	var intercept2: float = point2.y - (slope2 * point2.x)
	intersection.x = (intercept2 - intercept1) / (slope1 - slope2)
	intersection.y = (intersection.x * slope1) + intercept1
	
	return intersection

func floor_normal_border_point(borderPoint: Vector2) -> Vector2:
	var transformed_border_point: Vector2 = borderPoint * floorNormal.abs()
	var transformed_position: Vector2 = get_position() * floorNormal.rotated(PI/2).abs()
	var x: float = sqrt(pow(transformed_border_point.x, 2) + pow(transformed_position.x, 2))
	var y: float = sqrt(pow(transformed_border_point.y, 2) + pow(transformed_position.y, 2))
	return Vector2(x, y)

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
		if (rotateX > PI/2):
				rotateX = (PI/2) - rotateX
				
		var rotateY: float = Vector2.RIGHT.angle_to(floorNormal)
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
