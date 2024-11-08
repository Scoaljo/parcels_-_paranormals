extends Node3D
class_name MagicalScaleComponent

@export_group("Scale Properties")
@export var detection_height: float = 1.0  # How high above platform to check for objects
@export var weight_update_speed: float = 5.0  # How fast the display updates
@export var platform_hover_height: float = 0.1  # How much the platform floats
@export var normal_weight_color: Color = Color(0.5, 0.8, 1.0, 1.0)  # Magical blue
@export var paranormal_weight_color: Color = Color(0.8, 0.2, 1.0, 1.0)  # Mystical purple

var current_weight: float = 0.0
var displayed_weight: float = 0.0
var weighed_objects: Array[Node3D] = []
var is_paranormal_detected: bool = false

@onready var weight_label: Label3D = $WeightDisplay/Label3D
@onready var detection_area: Area3D = $DetectionArea
@onready var platform_mesh: MeshInstance3D = $Platform/MeshInstance3D

func _ready():
	# Connect area signals
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	# Initialize display
	update_display(0.0)
	setup_platform_hover()

func _process(delta):
	# Smoothly update displayed weight
	if displayed_weight != current_weight:
		displayed_weight = lerp(displayed_weight, current_weight, delta * weight_update_speed)
		update_display(displayed_weight)
	
	# Update platform hover effect
	var hover_offset = sin(Time.get_ticks_msec() / 1000.0) * 0.02
	platform_mesh.position.y = platform_hover_height + hover_offset

func _on_body_entered(body: Node3D):
	if body is RigidBody3D and not weighed_objects.has(body):
		weighed_objects.append(body)
		update_weight()
		
		# Check if the object is paranormal
		var paranormal_component = body.find_child("ParanormalBoxComponent", true)
		if paranormal_component and paranormal_component.is_paranormal:
			is_paranormal_detected = true

func _on_body_exited(body: Node3D):
	if weighed_objects.has(body):
		weighed_objects.erase(body)
		update_weight()
		
		# Reset paranormal detection if no objects remain
		if weighed_objects.is_empty():
			is_paranormal_detected = false

func update_weight():
	current_weight = 0.0
	for object in weighed_objects:
		if object is RigidBody3D:
			current_weight += object.mass

func update_display(weight: float):
	if weight_label:
		weight_label.text = "%.1f kg" % weight
		weight_label.modulate = paranormal_weight_color if is_paranormal_detected else normal_weight_color
		
		# Scale effect when weight changes
		var scale_factor = 1.0 + (0.1 * sin(Time.get_ticks_msec() / 200.0))
		weight_label.scale = Vector3.ONE * scale_factor

func setup_platform_hover():
	# Initial platform position
	if platform_mesh:
		platform_mesh.position.y = platform_hover_height
