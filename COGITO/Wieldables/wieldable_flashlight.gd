extends CogitoWieldable

@export_group("Flashlight Settings")
@export var is_on : bool
@export var drain_rate : float = 1
@onready var spot_light_3d = $SpotLight3D
@export var detection_range : float = 20.0
@export var detection_angle : float = 90.0

@export_group("Audio")
@export var switch_sound : AudioStream
@export var sound_reload : AudioStream

var detection_area: Area3D
var detected_boxes: Array[Node] = []
var trigger_has_been_pressed : bool = false

func _ready():
	if wieldable_mesh:
		wieldable_mesh.hide()
	setup_detection_area()
	if is_on:
		spot_light_3d.show()
	else:
		spot_light_3d.hide()
	print("Flashlight initialized")

func setup_detection_area():
	detection_area = Area3D.new()
	add_child(detection_area)
	
	var collision_shape = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.height = detection_range
	shape.radius = detection_range / 2  # Simplified for testing
	collision_shape.shape = shape
	collision_shape.rotation.x = deg_to_rad(90)
	detection_area.add_child(collision_shape)
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	print("Detection area set up")

func _process(delta):
	if is_on:
		player_interaction_component.equipped_wieldable_item.subtract(delta * drain_rate)
		if player_interaction_component.equipped_wieldable_item.charge_current == 0:
			turn_off()
		update_detected_boxes()

func update_detected_boxes():
	for body in detected_boxes:
		var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
		if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
			# For now, just make boxes glow if they're in range and flashlight is on
			paranormal_component.update_flashlight_interaction(self, is_on)
			print("Box in range, light is on: ", is_on)

func _on_body_entered(body: Node3D):
	var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
	if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
		print("Paranormal box entered area")
		detected_boxes.append(body)
		update_detected_boxes()

func _on_body_exited(body: Node3D):
	var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
	if paranormal_component and paranormal_component.is_paranormal and paranormal_component.emits_aura:
		print("Paranormal box left area")
		detected_boxes.erase(body)
		paranormal_component.update_flashlight_interaction(self, false)

func turn_off():
	is_on = false
	audio_stream_player_3d.stream = switch_sound
	audio_stream_player_3d.play()
	spot_light_3d.hide()
	
	for body in detected_boxes:
		var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
		if paranormal_component:
			paranormal_component.update_flashlight_interaction(self, false)

func toggle_on_off():
	audio_stream_player_3d.stream = switch_sound
	audio_stream_player_3d.play()
	
	if is_on:
		turn_off()
	elif player_interaction_component.equipped_wieldable_item.charge_current == 0:
		player_interaction_component.send_hint(null, player_interaction_component.equipped_wieldable_item.name + " is out of battery.")
	else:
		is_on = true
		spot_light_3d.show()
		for body in detected_boxes:
			var paranormal_component = body.get_node_or_null("ParanormalBoxComponent")
			if paranormal_component:
				paranormal_component.update_flashlight_interaction(self, true)

# Other functions remain the same
func action_primary(_passed_item_reference:InventoryItemPD, _is_released: bool):
	if _is_released:
		return
	animation_player.play(anim_action_primary)
	toggle_on_off()

func equip(_player_interaction_component: PlayerInteractionComponent):
	animation_player.play(anim_equip)
	player_interaction_component = _player_interaction_component

func unequip():
	animation_player.play(anim_unequip)
	if is_on:
		turn_off()

func reload():
	animation_player.play(anim_reload)
	audio_stream_player_3d.stream = sound_reload
	audio_stream_player_3d.play()
