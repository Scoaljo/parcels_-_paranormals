extends Area3D

@export_group("Force Properties")
@export var rejection_force: float = 35.0
@export var rejection_height: float = 2.0

@export_group("Visual Properties")
@export var idle_intensity: float = 1.0
@export var active_intensity: float = 2.0
@export var base_rotation_speed: float = 0.2
@export var field_size := Vector3(2.0, 2.0, 2.0)

# Core color scheme
var pool_color := Color(0.0, 0.4, 1.0)  # Bright blue base
const ACTIVE_COLOR := Color(0.2, 0.6, 1.0)  # Lighter blue when active

# Visual state tracking
var time_passed: float = 0.0
var active_repulsion: bool = false
var repelled_bodies: Array[Node3D] = []

# Node references
@onready var core_field: MeshInstance3D = $CoreField
@onready var outer_field: MeshInstance3D = $OuterField

# Material references
var core_material: StandardMaterial3D
var outer_material: StandardMaterial3D

class BoxInfo:
	var should_repel: bool
	func _init(repel: bool):
		should_repel = repel

var _tracked_bodies: Dictionary = {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	setup_visual_elements()

func setup_visual_elements():
	# Core field material
	core_material = StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = Color(pool_color.r, pool_color.g, pool_color.b, 0.4)  # Increased alpha
	core_material.emission_enabled = true
	core_material.emission = pool_color
	core_material.emission_energy_multiplier = idle_intensity
	core_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	
	# Outer field material
	outer_material = StandardMaterial3D.new()
	outer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_material.albedo_color = Color(pool_color.r, pool_color.g, pool_color.b, 0.2)  # More transparent
	outer_material.emission_enabled = true
	outer_material.emission = pool_color.lightened(0.2)
	outer_material.emission_energy_multiplier = idle_intensity * 0.5
	outer_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	
	if core_field:
		var core_mesh = BoxMesh.new()
		core_mesh.size = field_size
		core_field.mesh = core_mesh
		core_field.material_override = core_material
	
	if outer_field:
		var outer_mesh = BoxMesh.new()
		outer_mesh.size = field_size * 1.1  # Slightly larger
		outer_field.mesh = outer_mesh
		outer_field.material_override = outer_material

func _process(delta):
	time_passed += delta
	update_visual_effects(delta)

func update_visual_effects(delta: float):
	# Rotate fields in opposite directions
	if core_field:
		core_field.rotate_y(base_rotation_speed * delta)
	if outer_field:
		outer_field.rotate_y(-base_rotation_speed * 0.5 * delta)
	
	# Calculate pulse effect
	var pulse = (sin(time_passed * 2.0) * 0.3 + 0.7)
	
	if active_repulsion:
		update_material_intensity(core_material, ACTIVE_COLOR, pulse * active_intensity)
		update_material_intensity(outer_material, ACTIVE_COLOR.lightened(0.2), pulse * active_intensity * 0.5)
	else:
		update_material_intensity(core_material, pool_color, pulse * idle_intensity)
		update_material_intensity(outer_material, pool_color.lightened(0.2), pulse * idle_intensity * 0.5)

func update_material_intensity(material: StandardMaterial3D, color: Color, intensity: float):
	if material:
		material.emission = color
		material.albedo_color = Color(color.r, color.g, color.b, 0.3)
		material.emission_energy_multiplier = intensity

func _physics_process(_delta):
	active_repulsion = false
	
	for body in _tracked_bodies:
		var info = _tracked_bodies[body]
		if info.should_repel:
			active_repulsion = true
			
			# Calculate repulsion force
			var direction_to_center = global_position - body.global_position
			var distance = direction_to_center.length()
			
			# Stronger repulsion closer to center
			var repulsion_strength = rejection_force * (1.0 - min(distance / rejection_height, 1.0))
			
			# Add upward component to the force
			var repulsion = direction_to_center.normalized() * repulsion_strength
			repulsion.y = abs(repulsion.y)  # Always push upward
			
			body.apply_central_force(repulsion)

func _on_body_entered(body: Node3D):
	if body is RigidBody3D:
		var paranormal = body.find_child("ParanormalBoxComponent", true)
		if paranormal:
			# Only repel boxes with ectoplasm trait
			_tracked_bodies[body] = BoxInfo.new(
				paranormal.is_paranormal and paranormal.ectoplasm_sink
			)
			if paranormal.ectoplasm_sink:
				repelled_bodies.append(body)

func _on_body_exited(body: Node3D):
	if body in _tracked_bodies:
		_tracked_bodies.erase(body)
		repelled_bodies.erase(body)
