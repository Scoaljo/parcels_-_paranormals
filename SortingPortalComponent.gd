extends Node3D
class_name SortingPortalComponent

signal package_sorted(correct: bool)

@export_group("Portal Properties")
@export var is_paranormal_portal: bool = false
@export var effect_intensity: float = 2.0  # Increased default intensity
@export var portal_color: Color = Color(0.0, 0.5, 1.0, 1.0)  # Brighter blue for normal
@export var correct_sort_sound: AudioStream
@export var incorrect_sort_sound: AudioStream

@onready var effect_mesh: MeshInstance3D = $EffectsMesh
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea

# Visual feedback colors
const COLOR_CORRECT = Color(0.0, 1.0, 0.0, 1.0)  # Brighter green
const COLOR_INCORRECT = Color(1.0, 0.0, 0.0, 1.0)  # Brighter red
const EFFECT_DURATION = 1.0

func _ready():
	print("Starting portal setup...")
	
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
	
	setup_portal_effects()
	
	# Connect area signals
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func setup_portal_effects():
	if !effect_mesh:
		print("No effect mesh in setup_portal_effects!")
		return
	
	var material = ShaderMaterial.new()
	
	var shader = load("res://portal_effect.gdshader")
	if !shader:
		print("Failed to load shader!")
		return
	
	material.shader = shader
	print("Shader loaded and assigned to material")
	
	# Set initial parameters with stronger values and higher alpha
	var base_color = Color(0.0, 0.7, 1.0, 0.8)  # Added higher alpha
	if is_paranormal_portal:
		base_color = Color(0.8, 0.2, 1.0, 0.8)  # Added higher alpha
	
	# Configure material parameters
	material.set_shader_parameter("portal_color", base_color)
	material.set_shader_parameter("effect_intensity", 3.0)  # Increased intensity
	material.set_shader_parameter("hover_intensity", 0.0)
	
	print("Shader parameters set:")
	print("- Color:", base_color)
	print("- Intensity:", 3.0)
	
	# Set mesh properties
	effect_mesh.material_override = material
	effect_mesh.material_override.resource_local_to_scene = true
	effect_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect_mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Ensure proper render order
	effect_mesh.position.y = 0.06  # Slightly higher than base mesh
	effect_mesh.sorting_offset = 0.1
	effect_mesh.extra_cull_margin = 16.0
	effect_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	
	print("\nEffect mesh properties:")
	print("- Position Y:", effect_mesh.position.y)
	print("- Material override valid:", effect_mesh.material_override != null)
	print("- Shader assigned:", effect_mesh.material_override.shader != null)

func _process(_delta):
	if !Engine.is_editor_hint():  # Only in game, not editor
		if effect_mesh:
			if !effect_mesh.visible:
				print("WARNING: Effect mesh invisible!")
				print("- Position:", effect_mesh.position)
				print("- Scale:", effect_mesh.scale)
			if !effect_mesh.material_override:
				print("WARNING: No material override!")
			if effect_mesh.material_override and !effect_mesh.material_override.shader:
				print("WARNING: No shader in material!")
				print("- Material type:", effect_mesh.material_override.get_class())


func _on_body_entered(body: Node3D):
	if not body is RigidBody3D:
		return
		
	var paranormal_component = body.find_child("ParanormalBoxComponent", true)
	if paranormal_component:
		var is_correct = paranormal_component.is_paranormal == is_paranormal_portal
		handle_package_sorting(body, is_correct)
		
		# Add hover effect
		if effect_mesh and effect_mesh.material_override:
			effect_mesh.material_override.set_shader_parameter("hover_intensity", 0.3)

func handle_package_sorting(package: RigidBody3D, correct: bool):
	# Emit signal for scoring
	package_sorted.emit(correct)
	
	# Visual feedback
	show_sorting_feedback(correct)
	
	# Play sound
	if audio_player and (correct_sort_sound if correct else incorrect_sort_sound):
		audio_player.stream = correct_sort_sound if correct else incorrect_sort_sound
		audio_player.play()
	
	# Handle the package
	var carryable = package.find_child("CarryableComponent", true)
	if carryable:
		carryable.leave()  # Stop carrying if being carried
	
	# Animate disposal
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move down and fade out
	var target_pos = package.global_position - Vector3(0, 2, 0)
	tween.tween_property(package, "global_position", target_pos, 0.5)
	tween.tween_property(package, "scale", Vector3.ZERO, 0.5)
	
	# Disable physics while animating
	package.freeze = true
	
	# Queue for deletion after animation
	tween.tween_callback(func(): package.queue_free()).set_delay(0.5)

func show_sorting_feedback(correct: bool):
	if effect_mesh and effect_mesh.material_override:
		var feedback_color = COLOR_CORRECT if correct else COLOR_INCORRECT
		var material = effect_mesh.material_override
		
		# Flash effect
		var tween = create_tween()
		tween.tween_method(
			func(color): material.set_shader_parameter("portal_color", color),
			feedback_color,
			portal_color,
			EFFECT_DURATION
		)

func _on_detection_area_body_exited(body: Node3D):
	if effect_mesh and effect_mesh.material_override:
		effect_mesh.material_override.set_shader_parameter("hover_intensity", 0.0)

func is_paranormal() -> bool:
	return is_paranormal_portal
