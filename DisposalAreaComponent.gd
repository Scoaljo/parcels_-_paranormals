extends Node3D
class_name DisposalAreaComponent

signal package_disposed(package_type: String)

@export_group("Disposal Properties")
@export var effect_intensity: float = 3.0  # More intense than portal
@export var disposal_color: Color = Color(1.0, 0.2, 0.0, 1.0)  # Dangerous red
@export var disposal_sound: AudioStream
@export var rejection_sound: AudioStream

@onready var effect_mesh: MeshInstance3D = $EffectsMesh
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea

# Visual feedback colors
const COLOR_ACTIVE = Color(1.0, 0.1, 0.0, 1.0)  # Intense red for destruction
const COLOR_REJECT = Color(0.7, 0.7, 0.0, 1.0)  # Warning yellow for wrong package
const EFFECT_DURATION = 0.8  # Slightly faster than portal

func _ready():
	print("Starting disposal area setup...")
	
	if !effect_mesh:
		print("Effect mesh not found!")
		return
	
	# Create disposal effect mesh
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
	
	setup_disposal_effects()
	
	# Connect area signals
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func setup_disposal_effects():
	if !effect_mesh:
		print("No effect mesh in setup_disposal_effects!")
		return
	
	var material = ShaderMaterial.new()
	
	# Load the same shader (we'll modify parameters for different look)
	var shader = load("res://portal_effect.gdshader")
	if !shader:
		print("Failed to load shader!")
		return
	
	material.shader = shader
	
	# Set more intense parameters for disposal effect
	material.set_shader_parameter("portal_color", disposal_color)
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
		if paranormal_component.is_paranormal:
			handle_disposal(body, paranormal_component)
		else:
			reject_package(body)

func handle_disposal(package: RigidBody3D, paranormal_component: Node):
	# Emit signal with package type
	var properties = paranormal_component.get_package_properties()
	var package_type = "standard"
	if properties.aura:
		package_type = "glowing"
	elif properties.ectoplasm_sink:
		package_type = "sinking"
	elif properties.weight != 1.0:
		package_type = "weighted"
	
	package_disposed.emit(package_type)
	
	# Visual feedback
	show_disposal_feedback(true)
	
	# Play disposal sound
	if audio_player and disposal_sound:
		audio_player.stream = disposal_sound
		audio_player.play()
	
	# Handle the package
	var carryable = package.find_child("CarryableComponent", true)
	if carryable:
		carryable.leave()
	
	# Animate destruction
	var tween = create_tween()
	tween.set_parallel(true)
	
	# More dramatic disposal animation
	tween.tween_property(package, "scale", Vector3.ONE * 1.2, 0.2)  # Brief expansion
	tween.tween_property(package, "rotation", Vector3(randf() * 10, randf() * 10, randf() * 10), 0.3)  # Wild spin
	
	# Then shrink and sink
	tween.chain().tween_property(package, "scale", Vector3.ZERO, 0.3)
	tween.tween_property(package, "global_position", package.global_position - Vector3(0, 1, 0), 0.3)
	
	package.freeze = true
	tween.tween_callback(func(): package.queue_free()).set_delay(0.3)

func reject_package(package: RigidBody3D):
	# Visual feedback
	show_disposal_feedback(false)
	
	# Play rejection sound
	if audio_player and rejection_sound:
		audio_player.stream = rejection_sound
		audio_player.play()
	
	# Small repulsion effect
	if package is RigidBody3D:
		var direction = (package.global_position - global_position).normalized()
		package.apply_central_impulse(direction * 5.0)

func show_disposal_feedback(accepted: bool):
	if effect_mesh and effect_mesh.material_override:
		var feedback_color = COLOR_ACTIVE if accepted else COLOR_REJECT
		var material = effect_mesh.material_override
		
		var tween = create_tween()
		tween.tween_method(
			func(color): material.set_shader_parameter("portal_color", color),
			feedback_color,
			disposal_color,
			EFFECT_DURATION
		)

func _on_detection_area_body_exited(_body: Node3D):
	if effect_mesh and effect_mesh.material_override:
		effect_mesh.material_override.set_shader_parameter("hover_intensity", 0.0)
