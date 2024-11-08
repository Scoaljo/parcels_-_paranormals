extends Node3D
class_name GoodAreaComponent

signal package_processed(package_type: String)

@export_group("Good Area Properties")
@export var effect_intensity: float = 2.0  # Slightly less intense than disposal
@export var area_color: Color = Color(0.0, 0.7, 1.0, 1.0)  # Cool blue for safe/normal
@export var success_sound: AudioStream
@export var rejection_sound: AudioStream

@onready var effect_mesh: MeshInstance3D = $EffectsMesh
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea

# Visual feedback colors
const COLOR_ACTIVE = Color(0.0, 1.0, 0.5, 1.0)  # Positive green for correct sorting
const COLOR_REJECT = Color(1.0, 0.7, 0.0, 1.0)  # Warning orange for paranormal items
const EFFECT_DURATION = 0.8

func _ready():
	print("Starting good area setup...")
	
	if !effect_mesh:
		print("Effect mesh not found!")
		return
	
	# Create effect mesh
	var new_mesh = PlaneMesh.new()
	new_mesh.size = Vector2(2.0, 2.0)
	new_mesh.orientation = PlaneMesh.FACE_Y
	new_mesh.subdivide_width = 32
	new_mesh.subdivide_depth = 32
	effect_mesh.mesh = new_mesh
	
	# Position slightly above ground to prevent z-fighting
	effect_mesh.position.y = 0.05
	
	# Configure mesh properties
	effect_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect_mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect_mesh.visible = true
	
	setup_area_effects()
	
	# Connect area signals
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func setup_area_effects():
	if !effect_mesh:
		print("No effect mesh in setup_area_effects!")
		return
	
	var material = ShaderMaterial.new()
	
	# Load the same shader
	var shader = load("res://portal_effect.gdshader")
	if !shader:
		print("Failed to load shader!")
		return
	
	material.shader = shader
	
	# Set parameters for a more welcoming/safe look
	material.set_shader_parameter("portal_color", area_color)
	material.set_shader_parameter("effect_intensity", effect_intensity)
	material.set_shader_parameter("hover_intensity", 0.0)
	
	# Set mesh properties
	effect_mesh.material_override = material
	effect_mesh.material_override.resource_local_to_scene = true
	effect_mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect_mesh.extra_cull_margin = 16.0
	effect_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	effect_mesh.sorting_offset = 1.0
	
	print("Material setup complete")
	print("Material override assigned:", effect_mesh.material_override != null)
	print("Shader assigned:", effect_mesh.material_override.shader != null if effect_mesh.material_override else "No material")

func _on_body_entered(body: Node3D):
	if not body is RigidBody3D:
		return
	
	var paranormal_component = body.find_child("ParanormalBoxComponent", true)
	if paranormal_component:
		if !paranormal_component.is_paranormal:
			handle_good_package(body, paranormal_component)
		else:
			reject_package(body)

func handle_good_package(package: RigidBody3D, _paranormal_component: Node):
	# Emit signal for tracking
	package_processed.emit("normal")
	
	# Visual feedback
	show_feedback(true)
	
	# Play sound
	if audio_player and success_sound:
		audio_player.stream = success_sound
		audio_player.play()
	
	# Handle the package
	var carryable = package.find_child("CarryableComponent", true)
	if carryable:
		carryable.leave()
	
	# Animate package processing
	var tween = create_tween()
	tween.set_parallel(true)
	
	# More gentle animation for normal packages
	tween.tween_property(package, "scale", Vector3.ONE * 0.8, 0.3)  # Slight shrink
	tween.tween_property(package, "global_position", package.global_position - Vector3(0, 1, 0), 0.5)
	tween.tween_property(package, "rotation", Vector3(0, randf() * 2.0, 0), 0.3)  # Gentle spin
	
	package.freeze = true
	tween.tween_callback(func(): package.queue_free()).set_delay(0.5)

func reject_package(package: RigidBody3D):
	# Visual feedback
	show_feedback(false)
	
	# Play rejection sound
	if audio_player and rejection_sound:
		audio_player.stream = rejection_sound
		audio_player.play()
	
	# Gentle push away
	if package is RigidBody3D:
		var direction = (package.global_position - global_position).normalized()
		package.apply_central_impulse(direction * 3.0)  # Less forceful than disposal area

func show_feedback(accepted: bool):
	if effect_mesh and effect_mesh.material_override:
		var feedback_color = COLOR_ACTIVE if accepted else COLOR_REJECT
		var material = effect_mesh.material_override
		
		var tween = create_tween()
		tween.tween_method(
			func(color): material.set_shader_parameter("portal_color", color),
			feedback_color,
			area_color,
			EFFECT_DURATION
		)

func _on_detection_area_body_exited(_body: Node3D):
	if effect_mesh and effect_mesh.material_override:
		effect_mesh.material_override.set_shader_parameter("hover_intensity", 0.0)
