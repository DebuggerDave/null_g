extends RigidBody2D

const MOVE_FORCE: int = 100
const JUMP_IMPULSE: int = 100
const MASS: int = 1

var tile := preload("res://TileMap.gd")
var grounded := true
var contactBodies: Array = []
var gravVec := Vector2(0, 0)
	
	#var collision: KinematicCollision2D = move_and_collide(velocity)
#	if (collision):
#		print(collision.get_collider().world_to_map())
#	if (collision && (collision.get_collider() is tile)):
#		grounded = true
#		floorNormal = collision.get_normal()
#		velocity -= velocity * floorNormal.abs()

func _ready():
	self.connect("body_entered", self, "_on_collision_enter")
	self.connect("body_exited", self, "_on_collision_exit")

func _on_collision_enter(body: Node):
	contactBodies.push_back(body)
	grounded = true
	
func _on_collision_exit(body: Node):
	contactBodies.erase(body)
	if (contactBodies.size() == 0):
		grounded = false

var velocity
var force

func _integrate_forces(state: Physics2DDirectBodyState):
	gravVec = state.get_total_gravity()
	force = get_applied_force()
	velocity = state.get_linear_velocity()
	
func _physics_process(delta: float):
	var impulse := Vector2(0, 0)
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
		
		var moveTransform : Vector2 = Vector2(1, 1)
		if (not gravVec.is_equal_approx(Vector2(0, 0))):
			moveTransform = gravVec.normalized().rotated(PI/2).abs()
		impulse += moveDir * moveTransform * MOVE_FORCE * delta
			
		if Input.is_action_just_pressed("jump"):
			impulse += gravVec.normalized() * -1 * JUMP_IMPULSE
		
		apply_central_impulse(impulse)
