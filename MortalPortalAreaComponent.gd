extends Node3D
class_name MortalPortalAreaComponent

signal package_processed(package_type: String)

@export_group("Portal Properties")
@export var idle_intensity: float = 1.0
@export var active_intensity: float = 2.5
@export var base_rotation_speed: float = 0.3
@export var success_sound: AudioStream
@export var rejection_sound: AudioStream

# Cool blue color scheme
var portal_color := Color(0.0, 0.7, 1.0)  # Cool blue base color
const COLOR_ACCEPT := Color(0.0, 1.0, 0.5, 1.0)  # Bright green for success
const COLOR_REJECT := Color(1.0, 0.7, 0.0, 1.0)  # Warning orange
const FEEDBACK_DURATION := 0.4

# Node references
@onready var base_ring: MeshInstance3D = $BaseRing
@onready var inner_ring: MeshInstance3D = $InnerRing
@onready var portal_core: MeshInstance3D = $PortalCore
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea

# State tracking
var time_passed: float = 0.0
var current_feedback_tween: Tween
var ring_rotations := {
	"base": 0.0,
	"inner": 0.0
}

func _ready():
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
	setup_portal_materials()

func _process(delta):
	time_passed += delta
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
	var pulse = (sin(time_passed * 2.0) * 0.3 + 0.7)
	
	# Update ring rotations
	ring_rotations.base += base_rotation_speed * delta
	ring_rotations.inner -= base_rotation_speed * 1.5 * delta
	
	if base_ring:
		base_ring.rotation_degrees.y = rad_to_deg(ring_rotations.base)
	if inner_ring:
		inner_ring.rotation_degrees.y = rad_to_deg(ring_rotations.inner)
	
	# Update material intensities
	update_material_intensity(base_ring.material_override, pulse, 1.0)
	update_material_intensity(inner_ring.material_override, pulse, 1.5)
	update_material_intensity(portal_core.material_override, pulse, 2.0)

func update_material_intensity(material: StandardMaterial3D, pulse: float, multiplier: float):
	if material:
		material.emission_energy_multiplier = idle_intensity * pulse * multiplier

func _on_body_entered(body: Node3D):
	if not body is RigidBody3D:
		return
		
	var paranormal_component = body.find_child("ParanormalBoxComponent", true)
	if paranormal_component:
		if !paranormal_component.is_paranormal:
			handle_mortal_package(body)
		else:
			reject_paranormal_package(body)

func handle_mortal_package(package: RigidBody3D):
	# Emit signal for tracking
	package_processed.emit("mortal")
	
	# Visual feedback
	show_feedback(true)
	
	# Play success sound
	if audio_player and success_sound:
		audio_player.stream = success_sound
		audio_player.play()
	
	# Release from player if being carried
	var carryable = package.find_child("CarryableComponent", true)
	if carryable:
		carryable.leave()
	
	# Process the package
	process_package(package)

func process_package(package: RigidBody3D):
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move towards portal center with spin
	var target_pos = global_position + Vector3(0, 0.5, 0)
	tween.tween_property(package, "global_position", target_pos, 0.3)
	tween.tween_property(package, "rotation", Vector3(PI * 2, PI * 2, 0), 0.3)
	
	# Then shrink and fade into portal
	tween.chain().set_parallel(true)
	tween.tween_property(package, "scale", Vector3.ZERO, 0.2)
	tween.tween_property(package, "global_position", target_pos - Vector3(0, 0.5, 0), 0.2)
	
	package.freeze = true
	tween.tween_callback(func(): package.queue_free()).set_delay(0.2)

func reject_paranormal_package(package: RigidBody3D):
	# Visual feedback
	show_feedback(false)
	
	# Play rejection sound
	if audio_player and rejection_sound:
		audio_player.stream = rejection_sound
		audio_player.play()
	
	# Reject the package
	if package is RigidBody3D:
		var direction = (package.global_position - global_position).normalized()
		direction.y = abs(direction.y) * 2  # Add upward boost
		package.apply_central_impulse(direction * 8.0)

func show_feedback(accepted: bool):
	# Cancel any ongoing feedback
	if current_feedback_tween and current_feedback_tween.is_valid():
		current_feedback_tween.kill()
	
	# Choose feedback color and apply
	var feedback_color = COLOR_ACCEPT if accepted else COLOR_REJECT
	update_portal_color(feedback_color)
	
	# Return to original color after duration
	current_feedback_tween = create_tween()
	current_feedback_tween.tween_callback(
		func(): update_portal_color(portal_color)
	).set_delay(FEEDBACK_DURATION)

func update_portal_color(new_color: Color):
	if base_ring and base_ring.material_override:
		var mat = base_ring.material_override as StandardMaterial3D
		mat.emission = new_color
		mat.albedo_color = new_color.darkened(0.5)
	
	if inner_ring and inner_ring.material_override:
		var mat = inner_ring.material_override as StandardMaterial3D
		mat.emission = new_color.lightened(0.2)
		mat.albedo_color = new_color.darkened(0.3)
	
	if portal_core and portal_core.material_override:
		var mat = portal_core.material_override as StandardMaterial3D
		mat.emission = new_color.lightened(0.3)
		mat.albedo_color = Color(new_color.r, new_color.g, new_color.b, 0.5)
