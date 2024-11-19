extends Node3D
class_name BasePortalAreaComponent

@export_group("Portal Properties")
@export var idle_intensity: float = 1.0
@export var active_intensity: float = 2.0
@export var base_rotation_speed: float = 0.5
@export var portal_color: Color
@export var success_sound: AudioStream
@export var rejection_sound: AudioStream

# Onready vars for all our visual elements
@onready var base_ring: MeshInstance3D = $BaseRing
@onready var inner_ring: MeshInstance3D = $InnerRing
@onready var portal_core: MeshInstance3D = $PortalCore
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea

# Visual state tracking
var current_intensity: float = 0.0
var target_intensity: float = 0.0
var time_passed: float = 0.0

func _ready():
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Set up materials with exported color
	setup_portal_materials()

func _process(delta):
	time_passed += delta
	
	# Smooth intensity transitions
	current_intensity = lerp(current_intensity, target_intensity, delta * 3.0)
	
	# Update visual effects
	update_portal_effects(delta)

func setup_portal_materials():
	# Base ring material
	var base_material = StandardMaterial3D.new()
	base_material.metallic = 0.8
	base_material.roughness = 0.2
	base_material.emission_enabled = true
	base_material.emission = portal_color
	base_material.albedo_color = portal_color.darkened(0.5)
	base_material.emission_energy_multiplier = idle_intensity
	base_ring.material_override = base_material
	
	# Inner ring material (brighter)
	var inner_material = StandardMaterial3D.new()
	inner_material.metallic = 0.8
	inner_material.roughness = 0.1
	inner_material.emission_enabled = true
	inner_material.emission = portal_color.lightened(0.2)
	inner_material.albedo_color = portal_color.darkened(0.3)
	inner_material.emission_energy_multiplier = idle_intensity * 1.5
	inner_ring.material_override = inner_material
	
	# Portal core material
	var core_material = StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.5)
	core_material.emission_enabled = true
	core_material.emission = portal_color.lightened(0.3)
	core_material.emission_energy_multiplier = idle_intensity * 2.0
	portal_core.material_override = core_material

func update_portal_effects(delta: float):
	# Calculate pulse effect
	var pulse = (sin(time_passed * 2.0) * 0.3 + 0.7)  # Oscillates between 0.4 and 1.0
	
	# Update ring rotations
	if base_ring:
		base_ring.rotate_y(base_rotation_speed * delta * (1.0 + current_intensity))
	if inner_ring:
		inner_ring.rotate_y(-base_rotation_speed * 1.5 * delta * (1.0 + current_intensity))
	
	# Update materials based on intensity
	update_material_intensity(base_ring.material_override, pulse, 1.0)
	update_material_intensity(inner_ring.material_override, pulse, 1.5)
	update_material_intensity(portal_core.material_override, pulse, 2.0)

func update_material_intensity(material: StandardMaterial3D, pulse: float, multiplier: float):
	if material:
		var intensity = lerp(idle_intensity, active_intensity, current_intensity) * multiplier
		material.emission_energy_multiplier = intensity * pulse

func process_package(package: RigidBody3D):
	# Start "sucking in" animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move towards portal center with spin
	var target_pos = global_position + Vector3(0, 0.5, 0)  # Slightly above portal
	tween.tween_property(package, "global_position", target_pos, 0.3)
	tween.tween_property(package, "rotation", Vector3(PI * 2, PI * 2, 0), 0.3)
	
	# Then shrink and fade into portal
	tween.chain().set_parallel(true)
	tween.tween_property(package, "scale", Vector3.ZERO, 0.2)
	tween.tween_property(package, "global_position", target_pos - Vector3(0, 0.5, 0), 0.2)
	
	package.freeze = true
	tween.tween_callback(func(): package.queue_free()).set_delay(0.2)

func reject_package(package: RigidBody3D):
	if package is RigidBody3D:
		var direction = (package.global_position - global_position).normalized()
		direction.y = abs(direction.y) * 2  # Add upward boost
		package.apply_central_impulse(direction * 8.0)

# Virtual functions to be implemented by child classes
func _on_body_entered(_body: Node3D):
	pass

func _on_detection_area_body_exited(_body: Node3D):
	target_intensity = 0.0
