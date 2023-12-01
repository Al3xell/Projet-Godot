extends RigidBody3D

@onready var original_parent = get_parent()
@onready var original_collision_layer = collision_layer
@onready var original_collision_mask = collision_mask

@export var speed = 5.0
@export var is_dangerous  = false
var has_bounced = false

var original_transform
var picked_up_by = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _physics_process (delta):
	if !has_bounced:
		# Check for collisions
		var collision_info = move_and_collide(Vector3.ZERO)
		if collision_info:
			has_bounced = true
			is_dangerous = false
			print("bounce")
		
	if !picked_up_by: 
		return
	global_transform.origin = lerp(global_transform.origin, picked_up_by.global_transform.origin, speed * delta)

func pick_up(by):
	if picked_up_by == by:
		return

	if picked_up_by:
		let_go()
	
	has_bounced = false
	picked_up_by = by
	original_transform = global_transform
	
	# turn off physics for our pickable object
	freeze = 1
	freeze_mode = FREEZE_MODE_KINEMATIC
	collision_layer = 0
	collision_mask = 0
	
	# now reparent it
	original_parent. remove_child( self)
	picked_up_by.add_child(self)
	
	# keep the original transform
	global_transform = original_transform

func let_go(impulse = Vector3(0.0, 0.0, 0.0)):
	if picked_up_by:
		is_dangerous = true
		
		# get our current global transform
		var t = global_transform
		
		# reparent it
		picked_up_by.remove_child(self)
		original_parent.add_child(self)
		
		# reposition it and apply impulse
		global_transform = t
		freeze = 0
		collision_layer = original_collision_layer
		collision_mask = original_collision_mask
		apply_impulse(impulse, Vector3(0.0, 0.0, 0.0))
		
		picked_up_by = null


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
