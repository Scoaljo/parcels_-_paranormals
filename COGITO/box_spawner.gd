extends Area3D

@export var spawn_interval: float = 3.0
@export var random_position: bool = true
@export var paranormal_chance: float = 0.5 # 50% chance for paranormal boxes

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
	
	if random_position:
		var shape_extents = collision_shape.shape.size / 2
		var random_x = randf_range(-shape_extents.x, shape_extents.x)
		var random_y = randf_range(-shape_extents.y, shape_extents.y)
		var random_z = randf_range(-shape_extents.z, shape_extents.z)
		box.global_position = global_position + Vector3(random_x, random_y, random_z)
		print("Spawned at position: ", box.global_position)
	else:
		box.global_position = global_position
		print("Spawned at center: ", box.global_position)
	
	print("=== Spawn Complete ===\n")
