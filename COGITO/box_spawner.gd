extends Area3D

@export var spawn_interval: float = 3.0
@export var random_position: bool = true
@export var paranormal_chance: float = 0.5 # 50% chance for paranormal boxes
@export var eject_force: float = 2.0  # Force to push boxes out
@export var random_torque: float = 1.0  # Amount of random rotation

@onready var collision_shape = $CollisionShape3D
@onready var spawn_timer = $Timer

const BOX_SCENE = preload("res://Packages/scenes/PackageProps/cardboard_box_test.tscn")

func _ready():
	if !spawn_timer:
		spawn_timer = Timer.new()
		add_child(spawn_timer)
	
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	print("Spawner initialized with interval: ", spawn_interval)

func _on_spawn_timer_timeout():
	print("\n=== Spawning New Box ===")
	spawn_cardboard_box()

func spawn_cardboard_box():
	var box = BOX_SCENE.instantiate()
	
	# Configure paranormal properties BEFORE adding to scene
	var paranormal_component = box.find_child("ParanormalBoxComponent", true)
	if paranormal_component:
		var is_para = randf() < paranormal_chance
		print("Setting box paranormal state to: ", is_para)
		
		# Set paranormal state first
		paranormal_component.is_paranormal = is_para
		
		# Only randomize if paranormal
		if is_para:
			paranormal_component.randomize_properties()
	
	# Add to scene after configuration
	get_parent().add_child(box)
	
	# Position the box
	if random_position:
		var shape_extents = collision_shape.shape.size / 2
		var random_x = randf_range(-shape_extents.x, shape_extents.x)
		var random_z = randf_range(-shape_extents.z, shape_extents.z)
		# Keep Y at spawn point for better control
		box.global_position = global_position + Vector3(random_x, 0, random_z)
	else:
		box.global_position = global_position

	# Get the RigidBody3D component
	var rigid_body = box as RigidBody3D
	if rigid_body:
		# Add initial downward velocity with slight random horizontal movement
		var velocity = Vector3(
			randf_range(-1, 1),  # Small random X movement
			-eject_force,        # Downward force
			randf_range(-1, 1)   # Small random Z movement
		)
		rigid_body.linear_velocity = velocity

		# Add random rotation
		rigid_body.angular_velocity = Vector3(
			randf_range(-random_torque, random_torque),
			randf_range(-random_torque, random_torque),
			randf_range(-random_torque, random_torque)
		)
	
	print("Spawned box with initial velocity: ", rigid_body.linear_velocity if rigid_body else "No RigidBody")
