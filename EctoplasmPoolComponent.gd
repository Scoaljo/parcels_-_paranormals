extends Area3D

@export var float_force: float = 25.0
@export var sink_force: float = 15.0
@export var glow_force_multiplier: float = 0.5

# Store all needed info when box enters
class BoxInfo:
	var should_sink: bool
	var force_multiplier: float
	
	func _init(sink: bool, multiplier: float = 1.0):
		should_sink = sink
		force_multiplier = multiplier

var _tracked_bodies: Dictionary = {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D):
	if body is RigidBody3D:
		body.gravity_scale = 0.0
		
		var paranormal = body.find_child("ParanormalBoxComponent", true)
		if paranormal:
			var multiplier = 1.0
			if paranormal.emits_aura:
				multiplier = glow_force_multiplier
				
			# Store all info we need at once
			_tracked_bodies[body] = BoxInfo.new(
				paranormal.is_paranormal and paranormal.ectoplasm_sink,
				multiplier
			)
		else:
			_tracked_bodies[body] = BoxInfo.new(false)

func _on_body_exited(body: Node3D):
	if body in _tracked_bodies:
		_tracked_bodies.erase(body)
		if body is RigidBody3D:
			body.gravity_scale = 1.0

func _physics_process(_delta):
	for body in _tracked_bodies:
		var info = _tracked_bodies[body]
		var force = (-sink_force if info.should_sink else float_force) * info.force_multiplier
		
		if !info.should_sink and body.global_position.y < global_position.y:
			force *= 2.0
			
		body.apply_central_force(Vector3.UP * force)
