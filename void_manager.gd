extends Node3D

const SAFE_RADIUS := 20.0    # Center play area
const WARNING_RADIUS := 40.0  # First void zone
const DANGER_RADIUS := 60.0   # Second void zone
const NO_RETURN_RADIUS := 80.0  # Final zone before return

var player: Node3D
var environment: Environment
var initial_fog_density: float

func _ready() -> void:
	# Get references
	player = get_node("/root/SortingFacility/CogitoPlayer")
	var world_env = get_node("/root/SortingFacility/WorldEnvironment")
	if world_env:
		environment = world_env.environment
		initial_fog_density = environment.fog_density
	
	print("VoidManager initialized - Player and Environment found")

func _process(_delta: float) -> void:
	if !player or !environment:
		return
		
	var distance = player.global_position.length()
	
	if distance <= SAFE_RADIUS:
		# Safe zone
		environment.fog_density = initial_fog_density
	elif distance <= WARNING_RADIUS:
		# Warning zone
		environment.fog_density = 0.1
	elif distance <= DANGER_RADIUS:
		# Danger zone
		environment.fog_density = 0.2
	elif distance <= NO_RETURN_RADIUS:
		# Final warning zone
		environment.fog_density = 0.3
	else:
		# Beyond point of no return
		trigger_return()

func trigger_return() -> void:
	if !player or !environment:
		return
	
	var safe_pos = player.global_position.normalized() * (SAFE_RADIUS - 5.0)
	player.global_position = safe_pos
	environment.fog_density = initial_fog_density
