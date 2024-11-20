extends CogitoWieldable

@export_group("Detector Settings")
@export var detection_range: float = 20.0
@export var base_rotation_speed := 0.2
@export var max_rotation_speed := 5.0
@export var pulse_frequency := 3.0
@export var lift_force: float = 25.0
@export var carry_distance: float = 2.0  # Closer carry distance
@export var lift_height: float = 0.0  # Centered height (no lift)

@export_group("Blast Settings")
@export var blast_force: float = 30.0
@export var blast_upward_bias: float = 0.1
@export var blast_spin_force: float = 8.0

# State tracking
var is_active := true
var detection_area: Area3D
var detected_boxes: Array[Node] = []
var currently_lifted_object: RigidBody3D = null
var desired_lift_position: Vector3
var is_toggled: bool = false

# Animation state
var current_intensity := 0.0
var pulse_time := 0.0
var ring_rotations := {
	"outer2": Vector3.ZERO,
	"outer1": Vector3.ZERO,
	"inner": Vector3.ZERO
}

@onready var detector_mesh = $Detector_Mesh
@onready var core_orb = $Detector_Mesh/CoreOrb
@onready var inner_ring = $Detector_Mesh/InnerRing
@onready var outer_ring1 = $Detector_Mesh/OuterRing1
@onready var outer_ring2 = $Detector_Mesh/OuterRing2

func _ready():
	if wieldable_mesh:
		wieldable_mesh.hide()
	setup_detection_area()
	setup_materials()

func _physics_process(_delta):
	if currently_lifted_object and is_instance_valid(currently_lifted_object):
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Keep object directly in front of camera with stronger position control
			var forward = -camera.global_transform.basis.z
			desired_lift_position = camera.global_position + (forward * carry_distance)
			
			var current_pos = currently_lifted_object.global_position
			var target_pos = desired_lift_position
			
			# More direct position control
			var direction = target_pos - current_pos
			var distance = direction.length()
			
			# Reduced strength for smoother pulling
			var strength = 15.0  # Reduced from 50.0 to make pulling less aggressive
			currently_lifted_object.linear_velocity = direction * strength
			currently_lifted_object.angular_velocity = Vector3.ZERO

func action_secondary(is_released: bool) -> Variant:
	if !is_released and currently_lifted_object and is_instance_valid(currently_lifted_object):
		blast_object()
	return null  # Add this return statement

func blast_object():
	if currently_lifted_object and is_instance_valid(currently_lifted_object):
		var camera = get_viewport().get_camera_3d()
		if camera:
			var blast_direction = -camera.global_transform.basis.z + (Vector3.UP * blast_upward_bias)
			blast_direction = blast_direction.normalized()
			
			# Reset physics properties
			var carryable = currently_lifted_object.get_node_or_null("CarryableComponent")
			if carryable:
				carryable.is_disabled = false
			
			currently_lifted_object.gravity_scale = 1.0
			currently_lifted_object.linear_damp = 0
			currently_lifted_object.angular_damp = 0
			currently_lifted_object.lock_rotation = false
			
			# Set velocity directly instead of using impulse to ignore mass
			currently_lifted_object.linear_velocity = blast_direction * blast_force
			
			currently_lifted_object = null
			is_toggled = false

func action_primary(_passed_item_reference: InventoryItemPD, is_released: bool):
	if is_released:  # Only handle the release of the button
		if is_toggled:
			release_object()
			is_toggled = false
		else:
			var success = try_grab_object()
			is_toggled = success

func try_grab_object() -> bool:
	var camera = get_viewport().get_camera_3d()
	if !camera:
		return false
		
	var space_state = get_world_3d().direct_space_state
	var start = camera.global_position
	var end = start + -camera.global_transform.basis.z * detection_range
	
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [self]
	query.collision_mask = 1  # Adjust based on your collision layers
	
	var result = space_state.intersect_ray(query)
	# Check specifically for CarryableComponent
	if result and result.collider is RigidBody3D:
		var carryable = result.collider.get_node_or_null("CarryableComponent")
		if carryable and !carryable.is_disabled:
			lift_object(result.collider)
			return true
	return false

func lift_object(object: RigidBody3D):
	if currently_lifted_object:
		release_object()
		
	currently_lifted_object = object
	
	# We know the object has a CarryableComponent because of our check
	var carryable = object.get_node("CarryableComponent")
	carryable.is_disabled = true
	
	# Modify physics for better control
	currently_lifted_object.gravity_scale = 0
	currently_lifted_object.linear_damp = 5
	currently_lifted_object.angular_damp = 10
	currently_lifted_object.freeze = false
	
	# Lock rotation for stability
	currently_lifted_object.lock_rotation = true

func release_object():
	if currently_lifted_object and is_instance_valid(currently_lifted_object):
		# Re-enable CarryableComponent
		var carryable = currently_lifted_object.get_node_or_null("CarryableComponent")
		if carryable:
			carryable.is_disabled = false
		
		# Reset physics properties
		currently_lifted_object.gravity_scale = 1.0
		currently_lifted_object.linear_damp = 0
		currently_lifted_object.angular_damp = 0
		currently_lifted_object.lock_rotation = false
		
		# Apply slight downward velocity for better drop feel
		currently_lifted_object.linear_velocity = Vector3(0, -1, 0)
		
		currently_lifted_object = null

func setup_detection_area():
	detection_area = Area3D.new()
	add_child(detection_area)
	
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = detection_range
	collision_shape.shape = shape
	detection_area.add_child(collision_shape)
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func setup_materials():
	for mesh in [core_orb, inner_ring, outer_ring1, outer_ring2]:
		if mesh:
			var new_material = StandardMaterial3D.new()
			# Dark metallic base look
			new_material.metallic = 0.9
			new_material.roughness = 0.1
			new_material.emission_enabled = true
			
			# Very dark base color (deep blue-black)
			new_material.albedo_color = Color(0.02, 0.02, 0.05, 1.0)
			
			# Subtle blue-ish emission for idle state
			new_material.emission = Color(0.1, 0.1, 0.3, 1.0)
			new_material.emission_energy_multiplier = 0.1  # Very subtle when idle
			new_material.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
			mesh.material_override = new_material

func _process(delta: float):
	if !is_active:
		return
		
	var closest_distance = 999.0
	
	# Find closest paranormal box
	for body in detected_boxes:
		var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
		if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
			var distance = global_position.distance_to(body.global_position)
			closest_distance = min(closest_distance, distance)
	
	# Calculate intensity with more dramatic scaling at close range
	var target_intensity = 0.0
	if closest_distance < 999.0:
		target_intensity = pow(inverse_lerp(detection_range, 0, closest_distance), 2)
	
	# Smoothly update current intensity
	current_intensity = lerp(current_intensity, target_intensity, delta * 5.0)
	
	pulse_time += delta * pulse_frequency * (1.0 + current_intensity)
	update_ring_behavior(delta)
	update_detector_visuals()

func update_ring_behavior(delta: float):
	# Simplified rotation behavior
	var outer2_speed = lerp(base_rotation_speed, max_rotation_speed, current_intensity)
	var outer1_speed = lerp(base_rotation_speed, -max_rotation_speed * 1.2, current_intensity)
	var inner_speed = lerp(base_rotation_speed, max_rotation_speed * 1.5, current_intensity)
	
	# Update ring rotations
	if outer_ring2:
		ring_rotations.outer2.y += outer2_speed * delta
		outer_ring2.rotation.y = ring_rotations.outer2.y
		
	if outer_ring1:
		ring_rotations.outer1.x += outer1_speed * delta
		outer_ring1.rotation.x = ring_rotations.outer1.x
		
	if inner_ring:
		ring_rotations.inner.z += inner_speed * delta
		inner_ring.rotation.z = ring_rotations.inner.z

func update_detector_visuals():
	for mesh in [core_orb, inner_ring, outer_ring1, outer_ring2]:
		if mesh and mesh.material_override:
			var material = mesh.material_override as StandardMaterial3D
			if material:
				var emission_mult = 1.0
				if mesh == core_orb:
					emission_mult = 3.0  # Core glows much brighter
				elif mesh == inner_ring:
					emission_mult = 2.0  # Inner ring follows
				elif mesh == outer_ring1:
					emission_mult = 1.5  # Outer rings react last
				
				# Idle color is subtle blue, active is intense purple/pink
				var base_emission = Color(0.1, 0.1, 0.3, 1.0)  # Subtle blue
				var intense_emission = Color(1.0, 0.2, 2.0, 1.0)  # Bright purple/pink
				
				# Use exponential scaling for more dramatic close-range effect
				var intensity_scaled = pow(current_intensity, 3.0)  # More dramatic curve
				var current_emission = base_emission.lerp(intense_emission, intensity_scaled)
				
				# Scale up the energy multiplier more dramatically
				var base_energy = 0.1  # Very subtle when idle
				var max_energy = 5.0   # Much brighter at max
				var energy = lerp(base_energy, max_energy, pow(current_intensity, 2.0)) * emission_mult
				
				material.emission = current_emission
				material.emission_energy_multiplier = energy

func _on_body_entered(body: Node3D):
	var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
	if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
		detected_boxes.append(body)

func _on_body_exited(body: Node3D):
	detected_boxes.erase(body)

func equip(_player_interaction_component: PlayerInteractionComponent):
	animation_player.play(anim_equip)
	player_interaction_component = _player_interaction_component
	is_active = true

func unequip():
	animation_player.play(anim_unequip)
	is_active = false

#func action_primary(_passed_item_reference:InventoryItemPD, _is_released: bool):
#	pass

func reload():
	animation_player.play(anim_reload)
