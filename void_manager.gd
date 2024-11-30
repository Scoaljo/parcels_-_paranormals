extends Node3D
signal game_completed_with_stats(final_time: float, unsorted_penalty: float)

const SAFE_RADIUS := 20.0    # Center play area
const WARNING_RADIUS := 40.0  # First void zone
const DANGER_RADIUS := 60.0   # Second void zone
const NO_RETURN_RADIUS := 80.0  # Final zone before return

var player: Node3D
var environment: Environment
var initial_fog_density: float

# Game Configuration
const REQUIRED_SORTS := 10
const WRONG_SORT_PENALTY := 10.0  # seconds
const UNSORTED_BOX_PENALTY := 2.0  # seconds per box

# Game State
var game_time: float = 0.0
var correct_sorts: int = 0
var is_game_running: bool = false
var game_completed: bool = false

func _ready() -> void:
	# Get references
	player = get_node("/root/SortingFacility/CogitoPlayer")
	var world_env = get_node("/root/SortingFacility/WorldEnvironment")
	if world_env:
		environment = world_env.environment
		initial_fog_density = environment.fog_density
	
	# Connect to portal signals
	var mortal_portal = get_node("/root/SortingFacility/MortalPortalArea")
	var paranormal_portal = get_node("/root/SortingFacility/ParanormalPortalArea")
	
	print("Found mortal portal: ", mortal_portal != null)  # Debug
	print("Found paranormal portal: ", paranormal_portal != null)  # Debug
	
	if mortal_portal:
		mortal_portal.package_processed.connect(on_package_sorted)
		print("Connected to mortal portal signal")  # Debug
	if paranormal_portal:
		paranormal_portal.package_processed.connect(on_package_sorted)
		print("Connected to paranormal portal signal")  # Debug
	
	print("VoidManager initialized - Player and Environment found")

func _process(delta: float) -> void:
	if !player or !environment:
		return
	
	# Update game time if running
	if is_game_running and !game_completed:
		game_time += delta
	
	# Your existing void zone logic
	var distance = player.global_position.length()
	
	if distance <= SAFE_RADIUS:
		environment.fog_density = initial_fog_density
	elif distance <= WARNING_RADIUS:
		environment.fog_density = 0.1
	elif distance <= DANGER_RADIUS:
		environment.fog_density = 0.2
	elif distance <= NO_RETURN_RADIUS:
		environment.fog_density = 0.3
	else:
		trigger_return()

func trigger_return() -> void:
	if !player or !environment:
		return
	
	var safe_pos = player.global_position.normalized() * (SAFE_RADIUS - 5.0)
	player.global_position = safe_pos
	environment.fog_density = initial_fog_density

# Called when we get a package_processed signal from either portal
func on_package_sorted(package_type: String) -> void:
	if !is_game_running and !game_completed:
		start_game()
	
	print("Package sorted: ", package_type)  # Debug
	
	if package_type == "mortal":  # From mortal portal
		correct_sorts += 1
		print("Correct sorts: ", correct_sorts, "/", REQUIRED_SORTS)  # Debug
	elif package_type in ["standard", "glowing", "sinking", "weighted"]:  # From paranormal portal
		correct_sorts += 1
		print("Correct sorts: ", correct_sorts, "/", REQUIRED_SORTS)  # Debug
	else:  # Wrong sort
		game_time += WRONG_SORT_PENALTY
		print("Wrong sort! +", WRONG_SORT_PENALTY, " seconds")  # Debug
	
	print("Current time: ", format_time(game_time))  # Debug
	
	# Check for win condition
	if correct_sorts >= REQUIRED_SORTS:
		complete_game()

# Game state management
func start_game() -> void:
	is_game_running = true
	game_time = 0.0
	correct_sorts = 0
	print("Game Started!")

func complete_game() -> void:
	is_game_running = false
	game_completed = true
	
	# Add penalty for unsorted boxes
	var boxes = get_tree().get_nodes_in_group("packages")
	var unsorted_count = boxes.size()
	var unsorted_penalty = unsorted_count * UNSORTED_BOX_PENALTY
	game_time += unsorted_penalty
	
	emit_signal("game_completed_with_stats", game_time, unsorted_penalty)
	print("Game Complete! Final Time: ", format_time(game_time))

# Utility function to format time as "MM:SS.CC"
func format_time(time_in_seconds: float) -> String:
	var minutes := int(time_in_seconds / 60)
	var seconds := int(time_in_seconds) % 60
	var centiseconds := int((time_in_seconds - int(time_in_seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]
