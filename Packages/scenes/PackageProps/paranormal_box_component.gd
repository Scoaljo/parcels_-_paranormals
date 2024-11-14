extends Node

class_name ParanormalBoxComponent

@export_group("Paranormal Properties")
@export var is_paranormal: bool = false:
	set(value):
		print("\nSetting paranormal state: ", value)
		is_paranormal = value
		if !is_paranormal:
			paranormal_weight = 1.0
			emits_aura = false
			ectoplasm_sink = false
			print("Reset to normal box properties")
			
@export var paranormal_weight: float = 1.0
@export var emits_aura: bool = false
@export var ectoplasm_sink: bool = false

var parent_object: Node3D

func _ready():
	parent_object = get_parent()
	validate_paranormal_state()
	print_box_properties()
	
	if is_paranormal:
		apply_weight()

func print_box_properties():
	print("\n=== Box Properties ===")
	print("Is Paranormal: ", is_paranormal)
	if is_paranormal:
		print("- Weight: ", paranormal_weight)
		print("- Glowing: ", emits_aura)
		print("- Ectoplasm Sink: ", ectoplasm_sink)
		if paranormal_weight != 1.0:
			print("  * Has special weight")
		if emits_aura:
			print("  * Has aura")
		if ectoplasm_sink:
			print("  * Will sink in ectoplasm")
	else:
		print("* Normal box, no special properties")
	print("=====================")

func apply_weight():
	var rigid_body = parent_object as RigidBody3D
	if rigid_body and paranormal_weight > 0:
		rigid_body.mass = paranormal_weight

func validate_paranormal_state() -> bool:
	print("\nValidating paranormal state...")
	if is_paranormal:
		# Count active properties
		var active_properties = 0
		if paranormal_weight != 1.0:
			active_properties += 1
		if emits_aura:
			active_properties += 1
		if ectoplasm_sink:
			active_properties += 1
			
		if active_properties == 0:
			push_warning("Paranormal package has no special properties!")
			print("Warning: Paranormal box has no properties!")
			return false
		elif active_properties > 1:
			push_warning("Paranormal package has too many properties!")
			print("Warning: Paranormal box has ", active_properties, " properties!")
			return false
	else:
		if paranormal_weight != 1.0 or emits_aura or ectoplasm_sink:
			reset_to_normal()
			push_warning("Normal package cannot have special properties!")
			print("Warning: Normal box had special properties - reset!")
			return false
	return true

func reset_to_normal() -> void:
	print("\nResetting box to normal state")
	paranormal_weight = 1.0
	emits_aura = false
	ectoplasm_sink = false

func randomize_properties() -> void:
	print("\nRandomizing properties...")
	if !is_paranormal:
		print("Box is not paranormal, skipping randomization")
		return
	
	reset_to_normal()
	
	var rand = randi() % 3
	print("Chose random property type: ", rand)
	match rand:
		0:  # Heavy box
			paranormal_weight = randf_range(2.0, 5.0)
			print("Created heavy box with weight: ", paranormal_weight)
		1:  # Glowing box
			emits_aura = true
			print("Created glowing box")
		2:  # Ectoplasm-interacting box
			ectoplasm_sink = true
			print("Created ectoplasm-sinking box")

func is_package_paranormal() -> bool:
	return is_paranormal

func get_package_properties() -> Dictionary:
	return {
		"is_paranormal": is_paranormal,
		"weight": paranormal_weight,
		"aura": emits_aura,
		"ectoplasm_sink": ectoplasm_sink
	}
