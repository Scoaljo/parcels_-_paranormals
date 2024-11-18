extends Node3D
class_name MagicalScaleComponent

@export_group("Scale Properties")
@export var platform_hover_height: float = 0.1
@export var energy_pulse_speed: float = 2.0
@export var max_corruption_intensity: float = 5.0
@export var base_glow_color := Color(0.1, 0.3, 0.8, 1.0)  # Subtle blue
@export var paranormal_glow_color := Color(0.8, 0.2, 1.0, 1.0)  # Intense purple

# Visual state tracking
var current_weight: float = 0.0
var displayed_weight: float = 0.0
var weighed_objects: Array[Node3D] = []
var corruption_intensity: float = 0.0
var time_passed: float = 0.0
var base_text: String = "0.0"
var glitch_chars: String = "!@#$%&*<>░▒▓█▀▄"
var is_paranormal_present: bool = false

# Node references
@onready var weight_label: Label3D = $WeightDisplay/Label3D
@onready var detection_area: Area3D = $DetectionArea
@onready var platform_mesh: MeshInstance3D = $Platform/MeshInstance3D
@onready var energy_ring: MeshInstance3D = $Platform/EnergyRing
@onready var rune_ring: MeshInstance3D = $Platform/RuneRing

func _ready():
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	setup_visual_elements()
	
func setup_visual_elements():
	# Platform material setup - much darker, more metallic
	var platform_material = StandardMaterial3D.new()
	platform_material.metallic = 1.0
	platform_material.roughness = 0.1
	platform_material.albedo_color = Color(0.02, 0.02, 0.05)  # Almost black
	platform_material.emission_enabled = false  # Remove direct emission
	
	if platform_mesh:
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 2.5
		cylinder.bottom_radius = 2.5
		cylinder.height = 0.1
		platform_mesh.mesh = cylinder
		platform_mesh.material_override = platform_material
		platform_mesh.position.y = 0.05  # Raised slightly to put rings underneath
	
	# Energy ring setup (cyan ring) - more intense glow
	var energy_material = StandardMaterial3D.new()
	energy_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	energy_material.albedo_color = Color(0.0, 0.8, 1.0, 0.8)
	energy_material.emission_enabled = true
	energy_material.emission = Color(0.0, 0.8, 1.0)
	energy_material.emission_energy_multiplier = 2.0  # Increased base energy
	
	if energy_ring:
		var torus = TorusMesh.new()
		torus.inner_radius = 2.45
		torus.outer_radius = 2.5
		torus.rings = 64
		torus.ring_segments = 32
		energy_ring.mesh = torus
		energy_ring.material_override = energy_material
		energy_ring.position.y = 0.0  # At base level
	
	# Rune ring setup (purple ring) - more intense glow
	var rune_material = StandardMaterial3D.new()
	rune_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rune_material.albedo_color = Color(0.5, 0.0, 1.0, 0.8)
	rune_material.emission_enabled = true
	rune_material.emission = Color(0.5, 0.0, 1.0)
	rune_material.emission_energy_multiplier = 1.8  # Increased base energy
	
	if rune_ring:
		var torus = TorusMesh.new()
		torus.inner_radius = 2.55
		torus.outer_radius = 2.6
		torus.rings = 64
		torus.ring_segments = 32
		rune_ring.mesh = torus
		rune_ring.material_override = rune_material
		rune_ring.position.y = 0.0  # At base level
	
	# Weight label setup
	if weight_label:
		weight_label.modulate = base_glow_color
		weight_label.outline_modulate = Color(0.1, 0.2, 0.3)
		weight_label.outline_size = 2
		weight_label.font_size = 32
		weight_label.text = "0.0 kg"

func _process(delta):
	time_passed += delta
	
	# Platform hover effect
	var hover_offset = sin(time_passed * 1.5) * 0.02
	platform_mesh.position.y = platform_hover_height + hover_offset
	
	# Update corruption effects
	if is_paranormal_present:
		corruption_intensity = min(corruption_intensity + delta * 2, 1.0)
	else:
		corruption_intensity = max(corruption_intensity - delta * 2, 0.0)
	
	update_visual_effects(delta)
	
	# Smoothly update displayed weight
	if displayed_weight != current_weight:
		displayed_weight = lerp(displayed_weight, current_weight, delta * 5.0)
		update_display(displayed_weight)

func update_visual_effects(delta):
	var pulse = (1.0 + sin(time_passed * energy_pulse_speed)) * 0.5
	var intense_pulse = (1.0 + sin(time_passed * energy_pulse_speed * 2)) * 0.5
	
	# Update energy ring effects
	if energy_ring and energy_ring.material_override:
		var mat = energy_ring.material_override as StandardMaterial3D
		if mat:
			var base_color = Color(0.0, 0.8, 1.0)  # Cyan
			var paranormal_color = Color(1.0, 0.2, 1.0)  # Pink
			mat.emission = base_color.lerp(paranormal_color, corruption_intensity)
			mat.emission_energy_multiplier = lerp(2.0, 5.0, corruption_intensity * pulse)  # Higher energy range
			mat.albedo_color.a = lerp(0.8, 0.9, intense_pulse * corruption_intensity)
		
		energy_ring.rotate_y(delta * (0.2 + corruption_intensity))
	
	# Update rune ring effects
	if rune_ring and rune_ring.material_override:
		var mat = rune_ring.material_override as StandardMaterial3D
		if mat:
			var base_color = Color(0.5, 0.0, 1.0)  # Purple
			var paranormal_color = Color(1.0, 0.2, 0.5)  # Pink-red
			mat.emission = base_color.lerp(paranormal_color, corruption_intensity)
			mat.emission_energy_multiplier = lerp(1.8, 4.5, corruption_intensity * intense_pulse)  # Higher energy range
			mat.albedo_color.a = lerp(0.8, 0.9, pulse * corruption_intensity)
		
		rune_ring.rotate_y(-delta * (0.15 + corruption_intensity * 1.5))

func update_display(weight: float):
	if not weight_label:
		return
		
	var display_text = "%.1f kg" % weight
	
	if corruption_intensity > 0:
		# Corrupt the text based on corruption intensity
		var corrupted_text = ""
		for i in display_text.length():
			if randf() < corruption_intensity * 0.3:
				corrupted_text += glitch_chars[randi() % glitch_chars.length()]
			else:
				corrupted_text += display_text[i]
		
		weight_label.text = corrupted_text
		weight_label.modulate = base_glow_color.lerp(paranormal_glow_color, corruption_intensity)
		
		# Glitch effect on text size
		var size_offset = sin(time_passed * 20.0) * corruption_intensity * 8.0
		weight_label.font_size = 32 + size_offset
	else:
		weight_label.text = display_text
		weight_label.modulate = base_glow_color
		weight_label.font_size = 32

func _on_body_entered(body: Node3D):
	if body is RigidBody3D and not weighed_objects.has(body):
		weighed_objects.append(body)
		
		# Check for paranormal component with special weight
		var paranormal_component = body.find_child("ParanormalBoxComponent", true)
		if paranormal_component and paranormal_component.is_paranormal:
			# Only corrupt if it has special weight
			if paranormal_component.paranormal_weight != 1.0:
				is_paranormal_present = true
		
		update_weight()

func _on_body_exited(body: Node3D):
	if weighed_objects.has(body):
		weighed_objects.erase(body)
		
		# Check if any remaining objects are paranormal with special weight
		is_paranormal_present = false
		for obj in weighed_objects:
			var paranormal_component = obj.find_child("ParanormalBoxComponent", true)
			if paranormal_component and paranormal_component.is_paranormal:
				# Only check for special weight
				if paranormal_component.paranormal_weight != 1.0:
					is_paranormal_present = true
					break
		
		update_weight()

func update_weight():
	current_weight = 0.0
	for object in weighed_objects:
		if object is RigidBody3D:
			current_weight += object.mass
