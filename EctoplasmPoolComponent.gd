extends Area3D

@export_group("Force Properties")
@export var rejection_force: float = 35.0
@export var rejection_height: float = 2.0

@export_group("Visual Properties")
@export var base_color := Color(0.1, 0.2, 0.4, 0.3)  # Dark blue base
@export var active_color := Color(0.4, 0.2, 0.8, 0.4)  # Brighter purple when active
@export var pulse_speed := 1.2
@export var field_size := Vector3(3.0, 3.0, 3.0)

# Visual state tracking
var time_passed: float = 0.0
var active_repulsion: bool = false
var repelled_bodies: Array[Node3D] = []

@onready var field_mesh: MeshInstance3D = $FieldMesh

# Store info about interacting boxes
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
	# Setup core field material
	var field_material = StandardMaterial3D.new()
	field_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field_material.albedo_color = base_color
	field_material.emission_enabled = true
	field_material.emission = Color(base_color.r, base_color.g, base_color.b, 1.0)
	field_material.emission_energy_multiplier = 1.0
	field_material.metallic = 0.8
	field_material.roughness = 0.1
	
	if field_mesh:
		var cube = BoxMesh.new()
		cube.size = field_size
		field_mesh.mesh = cube
		field_mesh.material_override = field_material

func _process(delta):
	time_passed += delta
	update_visual_effects(delta)

func update_visual_effects(_delta):
	if field_mesh and field_mesh.material_override:
		var mat = field_mesh.material_override as StandardMaterial3D
		
		# Subtle pulsing effect
		var pulse = sin(time_passed * pulse_speed) * 0.5 + 0.5
		
		if active_repulsion:
			var current_color = base_color.lerp(active_color, pulse)
			mat.albedo_color = current_color
			mat.emission = Color(current_color.r, current_color.g, current_color.b, 1.0)
			mat.emission_energy_multiplier = lerp(1.0, 2.0, pulse)
		else:
			mat.albedo_color = base_color
			mat.emission = Color(base_color.r, base_color.g, base_color.b, 1.0)
			mat.emission_energy_multiplier = lerp(2.0, 5.0, pulse)

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
