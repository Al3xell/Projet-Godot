extends CharacterBody3D

@export var SPEED : float = 5.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY : float = 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)
@export var CAMERA_CONTROLLER : Camera3D
@export var ANIMATION : AnimationPlayer
@export var ANIMATION_TREE: AnimationTree
@export_range(5, 10, 0.1) var CROUCH_SPEED : float = 7.0
@export var CROUCH_SHAPECAST: Node3D
@export var isPlayer: bool = true
@export var ball: Node3D
@export var hasBall: bool = false


var _mouse_input : bool = false
var _rotation_input : float
var _tilt_input : float
var _mouse_rotation : Vector3
var _player_rotation : Vector3
var _camera_rotation : Vector3

var _is_crouching : bool = false
@export var THROW_FORCE: float = 3
var picked_up = null
var collider = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _unhandled_input(event: InputEvent) -> void:
	
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY
		
func _input(event): 	
	if event.is_action_pressed("exit"):
		get_tree().quit()

		
func _update_camera(delta):
	
	# Rotates camera using euler rotation
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0,_mouse_rotation.y,0.0)
	_camera_rotation = Vector3(_mouse_rotation.x,0.0,0.0)

	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	global_transform.basis = Basis.from_euler(_player_rotation)
	
	CAMERA_CONTROLLER.rotation.z = 0.0

	_rotation_input = 0.0
	_tilt_input = 0.0
	
func _ready():
	# Get mouse input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	CROUCH_SHAPECAST.add_exception($".")

func _physics_process(delta):
	if(isPlayer):
		# Update camera movement based on mouse movement
		_update_camera(delta)

		# Add the gravity.
		if not is_on_floor():
			velocity.y -= gravity * delta

		# Handle Jump.
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			
		if Input.is_action_just_pressed("crouch"):
			crouch()

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

		# check collision
		if $CameraController/Camera3D/RayCast3D.is_colliding() && !picked_up:
			collider = $CameraController/Camera3D/RayCast3D.get_collider()
			
		if Input. is_action_just_pressed( "pick" ) and !picked_up:
			# No object in direct sight
			if !collider or (collider && !collider.has_method("pick_up")):
				var bodies = $CameraController/Camera3D/PickPoint/PickArea.get_overlapping_bodies()
				if !bodies: return
				var smallest_dist = 100000
				var closest_object = null
				for body in bodies:
					var dist = global_transform.origin.distance_to(body.global_transform.origin)
					if dist < smallest_dist && body.has_method("pick_up"):
						smallest_dist = dist
						closest_object = body
				if picked_up: return 
				elif closest_object:
					closest_object. pick_up($CameraController/Camera3D/PickPoint)
					picked_up = closest_object
			# Object collide with raycast
			else:
				if picked_up: return 
				elif collider.has_method( "pick_up"):
					collider. pick_up($CameraController/Camera3D/PickPoint)
					picked_up = collider
			
		elif Input.is_action_just_pressed("throw"):
			if !picked_up: return
			picked_up.let_go(-$CameraController/Camera3D/PickPoint.global_transform.basis.z * THROW_FORCE)
			picked_up = null
		ANIMATION_TREE.set("parameters/conditions/Idle", input_dir == Vector2.ZERO && is_on_floor() && !_is_crouching)
		ANIMATION_TREE.set("parameters/conditions/Move", input_dir != Vector2.ZERO && is_on_floor() && !_is_crouching)
		ANIMATION_TREE.set("parameters/conditions/Jump", !is_on_floor())
		ANIMATION_TREE.set("parameters/conditions/Landed", is_on_floor())
		ANIMATION_TREE.set("parameters/conditions/Crouch", Input.is_action_just_pressed("crouch") && _is_crouching)
		ANIMATION_TREE.set("parameters/conditions/UnCrouch", Input.is_action_just_pressed("crouch") && !_is_crouching)
		ANIMATION_TREE.set("parameters/conditions/MoveCrouch", input_dir != Vector2.ZERO && is_on_floor() && _is_crouching)
		ANIMATION_TREE.set("parameters/conditions/IdleCrouch", input_dir == Vector2.ZERO && is_on_floor() && _is_crouching)
		move_and_slide()
	else:
		# Add the gravity.
		if not is_on_floor():
			velocity.y -= gravity * delta
		var distance  = $".".position.distance_to(ball.position)
		var direction = $".".position.direction_to(ball.position) if distance > 1 else Vector3.ZERO
		$".".look_at(Vector3(ball.position.x, 0.0, ball.position.z))
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
		ANIMATION_TREE.set("parameters/conditions/Idle", !direction && is_on_floor() && !_is_crouching)
		ANIMATION_TREE.set("parameters/conditions/Move", direction && is_on_floor() && !_is_crouching)
		ANIMATION_TREE.set("parameters/conditions/Jump", !is_on_floor())
		ANIMATION_TREE.set("parameters/conditions/Landed", is_on_floor())
		ANIMATION_TREE.set("parameters/conditions/Crouch", Input.is_action_just_pressed("crouch") && _is_crouching)
		ANIMATION_TREE.set("parameters/conditions/UnCrouch", Input.is_action_just_pressed("crouch") && !_is_crouching)
		ANIMATION_TREE.set("parameters/conditions/MoveCrouch", direction && is_on_floor() && _is_crouching)
		ANIMATION_TREE.set("parameters/conditions/IdleCrouch", !direction && is_on_floor() && _is_crouching)
		move_and_slide()

func crouch():
	if _is_crouching and !CROUCH_SHAPECAST.is_colliding():
		print("UNCROUCH")
	elif !_is_crouching:
		print("CROUCH")
	_is_crouching = !_is_crouching

