extends CogitoWieldable

@export_group("Detector Settings")
@export var detection_range : float = 20.0
@export var rotation_speed_inner := 8.0
@export var rotation_speed_outer1 := 12.0
@export var rotation_speed_outer2 := 10.0

# State tracking
var is_active := true  # Now always active when equipped
var detection_area: Area3D
var detected_boxes: Array[Node] = []

# Material properties
var base_emission = 0.2
var max_emission = 2.0
var current_emission = base_emission

# Get mesh nodes
@onready var detector_mesh = $DetectorMesh
@onready var core_orb = $DetectorMesh/CoreOrb
@onready var inner_ring = $DetectorMesh/InnerRing
@onready var outer_ring1 = $DetectorMesh/OuterRing1
@onready var outer_ring2 = $DetectorMesh/OuterRing2

func _ready():
	if wieldable_mesh:
		wieldable_mesh.hide()
	setup_detection_area()
	start_ring_animations()
	print("Detector initialized")

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

func start_ring_animations():
	# Continuous rotations that won't stop
	if inner_ring:
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(inner_ring, "rotation", Vector3(0, TAU, 0), rotation_speed_inner).from(Vector3.ZERO)
	
	if outer_ring1:
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(outer_ring1, "rotation", Vector3(TAU, 0, 0), rotation_speed_outer1).from(Vector3.ZERO)
	
	if outer_ring2:
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(outer_ring2, "rotation", Vector3(0, 0, TAU), rotation_speed_outer2).from(Vector3.ZERO)

func _process(_delta):
	if is_active:
		update_detected_boxes()

func update_detected_boxes():
	var closest_distance = 999.0
	
	for body in detected_boxes:
		var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
		if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
			var distance = global_position.distance_to(body.global_position)
			closest_distance = min(closest_distance, distance)
			paranormal_component.update_flashlight_interaction(self, true)  # Keep this for visual feedback
	
	# Update detector visuals based on closest paranormal box
	if closest_distance < 999.0:
		var intensity = inverse_lerp(detection_range, 0, closest_distance)
		update_detector_intensity(intensity)
	else:
		update_detector_intensity(0.0)

func update_detector_intensity(intensity: float):
	for mesh in [core_orb, inner_ring, outer_ring1, outer_ring2]:
		if mesh and mesh.get_surface_override_material(0):
			var material = mesh.get_surface_override_material(0) as StandardMaterial3D
			if material:
				var target_energy = lerp(base_emission, max_emission, intensity)
				if mesh == core_orb:
					material.emission_energy_multiplier = target_energy * 1.2
				elif mesh == inner_ring:
					material.emission_energy_multiplier = target_energy * 1.0
				else:
					material.emission_energy_multiplier = target_energy * 0.8

func _on_body_entered(body: Node3D):
	var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
	if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
		detected_boxes.append(body)

func _on_body_exited(body: Node3D):
	var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
	if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
		detected_boxes.erase(body)
		paranormal_component.update_flashlight_interaction(self, false)

func equip(_player_interaction_component: PlayerInteractionComponent):
	animation_player.play(anim_equip)
	player_interaction_component = _player_interaction_component
	is_active = true
	start_ring_animations()

func unequip():
	animation_player.play(anim_unequip)
	is_active = false

# These need to remain for COGITO framework compatibility
func action_primary(_passed_item_reference:InventoryItemPD, _is_released: bool):
	pass  # No longer needed but keep for compatibility

func reload():
	animation_player.play(anim_reload)
