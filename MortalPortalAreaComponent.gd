extends Node3D
class_name MortalPortalComponent

signal package_processed(package_type: String)

@export_group("Portal Properties")
@export var idle_intensity: float = 1.0
@export var active_intensity: float = 2.5
@export var base_rotation_speed: float = 0.3
@export var success_sound: AudioStream
@export var rejection_sound: AudioStream

# Core color scheme
var portal_color := Color(0.0, 0.7, 1.0)  # Cool blue base color
const COLOR_ACCEPT := Color(0.0, 1.0, 0.5, 1.0)  # Success green
const COLOR_REJECT := Color(1.0, 0.7, 0.0, 1.0)  # Warning orange
const FEEDBACK_DURATION := 0.4

# Node references
@onready var base_ring: MeshInstance3D = $BasePortalCore/PortalRim
@onready var inner_ring: MeshInstance3D = $BasePortalCore/PortalRim/InnerRing
@onready var portal_core: MeshInstance3D = $BasePortalCore/PortalRim/PortalCenter
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea
@onready var portal_light: OmniLight3D = $BasePortalCore/PortalRim/PortalCenter/OmniLight3D

# State tracking
var time_passed: float = 0.0
var ring_rotations := {
	"base": 0.0,
	"inner": 0.0
}

# Material references
var base_material: StandardMaterial3D
var inner_material: StandardMaterial3D
var core_material: StandardMaterial3D

func _ready():
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
	setup_portal_materials()

func _process(delta):
	time_passed += delta
	update_portal_effects(delta)

func setup_portal_materials():
	print("Setting up materials...")
	
	# Base ring material
	if base_ring:
		base_material = StandardMaterial3D.new()
		base_material.metallic = 0.8
		base_material.roughness = 0.2
		base_material.emission_enabled = true
		base_material.emission = portal_color
		base_material.albedo_color = portal_color.darkened(0.5)
		base_material.emission_energy_multiplier = idle_intensity
		base_ring.set_surface_override_material(0, base_material)
	
	# Inner ring material
	if inner_ring:
		inner_material = StandardMaterial3D.new()
		inner_material.metallic = 0.8
		inner_material.roughness = 0.1
		inner_material.emission_enabled = true
		inner_material.emission = portal_color.lightened(0.2)
		inner_material.albedo_color = portal_color.darkened(0.3)
		inner_material.emission_energy_multiplier = idle_intensity * 1.5
		inner_ring.set_surface_override_material(0, inner_material)
	
	# Portal core material
	if portal_core:
		core_material = StandardMaterial3D.new()
		core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		core_material.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.5)
		core_material.emission_enabled = true
		core_material.emission = portal_color.lightened(0.3)
		core_material.emission_energy_multiplier = idle_intensity * 2.0
		portal_core.set_surface_override_material(0, core_material)

func update_portal_effects(delta: float):
	# Calculate pulse effect
	var pulse = (sin(time_passed * 2.0) * 0.3 + 0.7)
	
	# Update ring rotations
	ring_rotations.base += base_rotation_speed * delta
	ring_rotations.inner -= base_rotation_speed * 1.5 * delta
	
	# Update rotations
	if base_ring:
		base_ring.rotation_degrees.y = rad_to_deg(ring_rotations.base)
	if inner_ring:
		inner_ring.rotation_degrees.y = rad_to_deg(ring_rotations.inner)
	
	# Update material intensities
	if base_material:
		base_material.emission_energy_multiplier = idle_intensity * pulse
	if inner_material:
		inner_material.emission_energy_multiplier = idle_intensity * pulse * 1.5
	if core_material:
		core_material.emission_energy_multiplier = idle_intensity * pulse * 2.0

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
	package_processed.emit("mortal")
	show_feedback(true)
	
	if audio_player and success_sound:
		audio_player.stream = success_sound
		audio_player.play()
	
	var carryable = package.find_child("CarryableComponent", true)
	if carryable:
		carryable.leave()
	
	process_package(package)

func reject_paranormal_package(package: RigidBody3D):
	show_feedback(false)
	
	if audio_player and rejection_sound:
		audio_player.stream = rejection_sound
		audio_player.play()
	
	if package is RigidBody3D:
		var direction = (package.global_position - global_position).normalized()
		direction.y = abs(direction.y) * 2
		package.apply_central_impulse(direction * 8.0)

func show_feedback(accepted: bool):
	# Simply update colors
	update_portal_color(COLOR_ACCEPT if accepted else COLOR_REJECT)
	
	# Return to original color after duration
	await get_tree().create_timer(FEEDBACK_DURATION).timeout
	update_portal_color(portal_color)

func update_portal_color(new_color: Color):
	if base_material:
		base_material.emission = new_color
		base_material.albedo_color = new_color.darkened(0.5)
	
	if inner_material:
		inner_material.emission = new_color.lightened(0.2)
		inner_material.albedo_color = new_color.darkened(0.3)
	
	if core_material:
		core_material.emission = new_color.lightened(0.3)
		core_material.albedo_color = Color(new_color.r, new_color.g, new_color.b, 0.5)
	
	if portal_light:
		portal_light.light_color = new_color

func process_package(package: RigidBody3D):
	var tween = create_tween()
	tween.set_parallel(true)
	
	var target_pos = global_position + Vector3(0, 0.5, 0)
	tween.tween_property(package, "global_position", target_pos, 0.3)
	tween.tween_property(package, "rotation", Vector3(PI * 2, PI * 2, 0), 0.3)
	
	tween.chain().set_parallel(true)
	tween.tween_property(package, "scale", Vector3.ZERO, 0.2)
	tween.tween_property(package, "global_position", target_pos - Vector3(0, 0.5, 0), 0.2)
	
	package.freeze = true
	tween.tween_callback(func(): package.queue_free()).set_delay(0.2)
