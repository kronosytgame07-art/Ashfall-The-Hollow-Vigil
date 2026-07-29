class_name AshfallSoulsPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal damage_received(amount: float)
signal died

const GRAVITY := 24.0
const WALK_SPEED := 5.2
const SPRINT_SPEED := 7.4
const DODGE_SPEED := 12.5
const JUMP_VELOCITY := 8.8
const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0

var health := MAX_HEALTH
var stamina := MAX_STAMINA
var is_attacking := false
var is_dodging := false
var is_dead := false
var attack_clock := 0.0
var dodge_clock := 0.0
var invulnerable_clock := 0.0
var attack_serial := 0
var combo_step := 0
var combo_timeout := 0.0
var hit_reaction_clock := 0.0
var checkpoint := Vector3(0, 1.2, 10)
var race_name := "Humain"
var character_level := 1
var inventory: Array[Dictionary] = []
var equipment := {
	"weapon": {"name": "Épée de veille", "color": Color("#aeb3bb"), "power": 0},
	"helmet": {},
	"armor": {},
}

var camera_pivot: Node3D
var visual: Node3D
var weapon_pivot: Node3D
var weapon_grip: Node3D
var left_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var body_pivot: Node3D
var race_details: Node3D
var weapon_trail: MeshInstance3D
var weapon_model: Node3D
var equipment_visuals: Node3D
var back_shield: MeshInstance3D
var back_shield_emblem: MeshInstance3D
var base_cape: MeshInstance3D
var race_limb_details: Array[MeshInstance3D] = []
var _last_move := Vector3.FORWARD
var _mouse_sensitivity := 0.003

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_build_collision()
	_build_visual()
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * _mouse_sensitivity
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * _mouse_sensitivity,
			-0.58,
			0.42
		)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_instance_valid(camera_pivot):
		camera_pivot.global_position = global_position + Vector3(0, 1.38, 0)
	if is_dead:
		return
	invulnerable_clock = maxf(0.0, invulnerable_clock - delta)
	combo_timeout = maxf(0.0, combo_timeout - delta)
	hit_reaction_clock = maxf(0.0, hit_reaction_clock - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
		if Input.is_action_just_pressed("jump") and not is_attacking and not is_dodging:
			velocity.y = JUMP_VELOCITY

	if is_attacking:
		_update_attack(delta)
	elif is_dodging:
		_update_dodge(delta)
	else:
		_update_movement(delta)
		if Input.is_action_just_pressed("attack"):
			_begin_attack()
		elif Input.is_action_just_pressed("dodge") and stamina >= 24.0:
			_begin_dodge()

	stamina = minf(MAX_STAMINA, stamina + (12.0 if Input.is_action_pressed("sprint") else 21.0) * delta)
	stamina_changed.emit(stamina, MAX_STAMINA)
	move_and_slide()
	_animate(delta)

func _update_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -camera_pivot.global_basis.z
	var right := camera_pivot.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	var direction := (right.normalized() * input.x + forward.normalized() * -input.y).normalized()
	var sprinting := Input.is_action_pressed("sprint") and stamina > 0.0 and input.length() > 0.1
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting:
		stamina = maxf(0.0, stamina - 18.0 * delta)
	if direction.length_squared() > 0.01:
		_last_move = direction
		velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-14.0 * delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)

func _begin_attack() -> void:
	if stamina < 18.0:
		return
	stamina -= 18.0
	is_attacking = true
	attack_clock = 0.0
	attack_serial += 1
	combo_step = posmod(combo_step + 1, 3) if combo_timeout > 0.0 else 0
	combo_timeout = 0.95

func _update_attack(delta: float) -> void:
	attack_clock += delta
	velocity.x = move_toward(velocity.x, _last_move.x * 1.2, 18.0 * delta)
	velocity.z = move_toward(velocity.z, _last_move.z * 1.2, 18.0 * delta)
	var impact_start := 0.18 if combo_step == 1 else 0.22
	var impact_end := impact_start + 0.14
	if attack_clock >= impact_start and attack_clock < impact_end:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(enemy):
				continue
			var offset: Vector3 = enemy.global_position - global_position
			var facing := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
			if offset.length() < 2.35 and facing.dot(offset.normalized()) > 0.18:
				var weapon_power: float = float(equipment.get("weapon", {}).get("power", 0))
				var combo_damage: float = [31.0, 38.0, 52.0][combo_step] + weapon_power
				enemy.take_damage(combo_damage, attack_serial, facing)
	if attack_clock >= (0.72 if combo_step == 2 else 0.58):
		is_attacking = false

func _begin_dodge() -> void:
	stamina -= 24.0
	is_dodging = true
	dodge_clock = 0.0
	invulnerable_clock = 0.46
	if _last_move.length_squared() < 0.01:
		_last_move = Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func _update_dodge(delta: float) -> void:
	dodge_clock += delta
	var curve := 1.0 - smoothstep(0.0, 0.52, dodge_clock)
	velocity.x = _last_move.x * DODGE_SPEED * maxf(0.28, curve)
	velocity.z = _last_move.z * DODGE_SPEED * maxf(0.28, curve)
	if dodge_clock >= 0.52:
		is_dodging = false

func take_damage(amount: float) -> void:
	if is_dead or invulnerable_clock > 0.0:
		return
	health = maxf(0.0, health - amount)
	invulnerable_clock = 0.45
	hit_reaction_clock = 0.28
	damage_received.emit(amount)
	_spawn_damage_number(amount, Color("#e34b43"))
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		is_dead = true
		velocity = Vector3.ZERO
		died.emit()

func rest_at(position_: Vector3) -> void:
	checkpoint = position_
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	health_changed.emit(health, MAX_HEALTH)
	stamina_changed.emit(stamina, MAX_STAMINA)

func revive() -> void:
	global_position = checkpoint
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	is_dead = false
	visual.rotation = Vector3.ZERO
	health_changed.emit(health, MAX_HEALTH)

func configure_race(selected_race: String) -> void:
	race_name = selected_race
	for child in race_details.get_children():
		child.queue_free()
	for detail in race_limb_details:
		if is_instance_valid(detail):
			detail.queue_free()
	race_limb_details.clear()
	match selected_race:
		"Orque":
			visual.scale = Vector3(1.12, 1.08, 1.12)
			_tint_skin(Color("#52623a"))
			back_shield.visible = false
			back_shield_emblem.visible = false
			base_cape.visible = false
			_add_orc_details()
		"Gobelin":
			visual.scale = Vector3(0.78, 0.78, 0.78)
			_tint_skin(Color("#66733f"))
			back_shield.visible = false
			back_shield_emblem.visible = false
			base_cape.visible = false
			_add_goblin_details()
		"Nain":
			visual.scale = Vector3(1.08, 0.78, 1.08)
			_tint_skin(Color("#8a604a"))
			back_shield.visible = true
			back_shield_emblem.visible = true
			base_cape.visible = true
			_add_dwarf_details()
		_:
			visual.scale = Vector3.ONE
			_tint_skin(Color("#8d604b"))
			back_shield.visible = true
			back_shield_emblem.visible = true
			base_cape.visible = true
			_add_human_details()
	_rebuild_equipment_visuals()

func equip_loot(items: Array) -> void:
	for raw_item in items:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item.duplicate(true)
		inventory.append(item)
		var slot: String = item.get("slot", "")
		if slot in equipment:
			var current_power: int = equipment[slot].get("power", -1)
			if int(item.get("power", 0)) >= current_power:
				equipment[slot] = item
	_rebuild_equipment_visuals()

func equipment_summary() -> String:
	var parts: Array[String] = []
	for slot in ["weapon", "helmet", "armor"]:
		var item: Dictionary = equipment.get(slot, {})
		if not item.is_empty():
			parts.append(item.get("name", "Objet"))
	return "  •  ".join(parts)

func _tint_skin(color: Color) -> void:
	var face := visual.find_child("RaceSkin", true, false) as MeshInstance3D
	if face:
		var material := face.material_override as StandardMaterial3D
		if material:
			material.albedo_color = color

func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)

func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "VoxelKnight"
	add_child(visual)
	race_details = Node3D.new()
	race_details.name = "RaceDetails"
	visual.add_child(race_details)
	body_pivot = Node3D.new()
	body_pivot.position.y = 1.18
	visual.add_child(body_pivot)
	_box(body_pivot, Vector3(0.82, 0.92, 0.46), Vector3.ZERO, Color("#252832"), 0.72)
	_box(body_pivot, Vector3(0.9, 0.14, 0.5), Vector3(0, 0.25, -0.02), Color("#616774"), 0.85)
	_box(body_pivot, Vector3(0.82, 0.08, 0.5), Vector3(0, -0.1, -0.02), Color("#515762"), 0.85)
	_box(visual, Vector3(0.54, 0.52, 0.54), Vector3(0, 1.94, 0), Color("#343843"), 0.75)
	var face := _box(visual, Vector3(0.38, 0.18, 0.05), Vector3(0, 1.83, 0.292), Color("#8d604b"))
	face.name = "RaceSkin"
	_box(visual, Vector3(0.61, 0.12, 0.62), Vector3(0, 2.16, 0), Color("#777d88"), 0.9)
	_box(visual, Vector3(0.44, 0.1, 0.06), Vector3(0, 1.96, 0.29), Color("#08090c"), 0.1)
	_box(visual, Vector3(0.07, 0.06, 0.03), Vector3(-0.13, 1.96, 0.325), Color("#d64d32"), 0.2, true)
	_box(visual, Vector3(0.07, 0.06, 0.03), Vector3(0.13, 1.96, 0.325), Color("#d64d32"), 0.2, true)
	# Membres articulés : chaque pièce tourne depuis une vraie épaule ou une vraie hanche.
	left_leg_pivot = Node3D.new()
	left_leg_pivot.position = Vector3(-0.27, 0.78, 0)
	visual.add_child(left_leg_pivot)
	_box(left_leg_pivot, Vector3(0.16, 0.76, 0.18), Vector3(0, -0.35, 0), Color("#1a1b21"), 0.6)
	right_leg_pivot = Node3D.new()
	right_leg_pivot.position = Vector3(0.27, 0.78, 0)
	visual.add_child(right_leg_pivot)
	_box(right_leg_pivot, Vector3(0.16, 0.76, 0.18), Vector3(0, -0.35, 0), Color("#1a1b21"), 0.6)
	left_arm_pivot = Node3D.new()
	left_arm_pivot.position = Vector3(-0.57, 1.5, 0)
	visual.add_child(left_arm_pivot)
	_box(left_arm_pivot, Vector3(0.18, 0.7, 0.18), Vector3(0, -0.35, 0), Color("#30343e"), 0.75)
	weapon_pivot = Node3D.new()
	weapon_pivot.position = Vector3(0.58, 1.5, 0)
	visual.add_child(weapon_pivot)
	_box(weapon_pivot, Vector3(0.18, 0.7, 0.18), Vector3(0, -0.35, 0), Color("#30343e"), 0.75)
	weapon_grip = Node3D.new()
	weapon_grip.name = "RightHandGrip"
	weapon_grip.position = Vector3(0, -0.69, 0)
	weapon_pivot.add_child(weapon_grip)
	_box(weapon_grip, Vector3(0.22, 0.18, 0.22), Vector3.ZERO, Color("#252832"), 0.72)
	weapon_model = Node3D.new()
	weapon_model.name = "EquippedWeapon"
	weapon_grip.add_child(weapon_model)
	equipment_visuals = Node3D.new()
	equipment_visuals.name = "VisibleEquipment"
	visual.add_child(equipment_visuals)
	back_shield = _box(
		visual,
		Vector3(0.62, 0.72, 0.12),
		Vector3(-0.58, 1.18, 0.02),
		Color("#393d46"),
		0.82
	)
	back_shield_emblem = _box(
		visual,
		Vector3(0.48, 0.58, 0.05),
		Vector3(-0.58, 1.18, 0.09),
		Color("#651c1f"),
		0.15
	)
	base_cape = _box(
		visual,
		Vector3(0.66, 1.08, 0.08),
		Vector3(0, 1.2, -0.29),
		Color("#351014"),
		0.0
	)
	base_cape.rotation.x = -0.08
	weapon_trail = _box(
		weapon_pivot,
		Vector3(0.42, 1.18, 0.025),
		Vector3(0.18, -0.9, 0),
		Color(0.75, 0.16, 0.08, 0.42),
		0.0,
		true
	)
	weapon_trail.visible = false
	_rebuild_equipment_visuals()

func _rebuild_equipment_visuals() -> void:
	if not is_instance_valid(equipment_visuals) or not is_instance_valid(weapon_model):
		return
	for child in equipment_visuals.get_children():
		child.queue_free()
	for child in weapon_model.get_children():
		child.queue_free()
	var weapon: Dictionary = equipment.get("weapon", {})
	var weapon_color: Color = weapon.get("color", Color("#aeb3bb"))
	var weapon_name: String = weapon.get("name", "Épée")
	var default_race_weapon := int(weapon.get("power", 0)) == 0
	# L'origine locale est la paume : poignée en main, lame sous la garde.
	if default_race_weapon and race_name == "Orque":
		_box(
			weapon_model,
			Vector3(0.15, 1.28, 0.15),
			Vector3(0, -0.5, 0),
			Color("#4c2e1d"),
			0.08
		)
		var orc_axe := _box(
			weapon_model,
			Vector3(0.72, 0.48, 0.16),
			Vector3(0.23, -1.04, 0),
			Color("#4e4a46"),
			0.88
		)
		orc_axe.name = "OrcWarAxe"
		_box(
			weapon_model,
			Vector3(0.18, 0.62, 0.17),
			Vector3(-0.18, -1.0, 0),
			Color("#2e2c2a"),
			0.9
		)
		_box(
			weapon_model,
			Vector3(0.52, 0.1, 0.18),
			Vector3(0.26, -1.27, 0),
			Color("#81776c"),
			0.9
		)
	elif default_race_weapon and race_name == "Gobelin":
		_box(
			weapon_model,
			Vector3(0.12, 1.12, 0.12),
			Vector3(0, -0.45, 0),
			Color("#4f301d"),
			0.05
		)
		var goblin_axe := _box(
			weapon_model,
			Vector3(0.58, 0.36, 0.13),
			Vector3(0.18, -0.92, 0),
			Color("#514d49"),
			0.84
		)
		goblin_axe.name = "GoblinHatchet"
		_box(
			weapon_model,
			Vector3(0.15, 0.5, 0.15),
			Vector3(-0.14, -0.89, 0),
			Color("#302e2c"),
			0.86
		)
		_box(
			weapon_model,
			Vector3(0.43, 0.08, 0.14),
			Vector3(0.21, -1.1, 0),
			Color("#82786d"),
			0.88
		)
	elif "hache" in weapon_name.to_lower():
		_box(weapon_model, Vector3(0.11, 1.18, 0.11), Vector3(0, -0.49, 0), Color("#5b3824"), 0.1)
		_box(weapon_model, Vector3(0.68, 0.4, 0.13), Vector3(0.22, -0.96, 0), weapon_color, 0.92)
		_box(weapon_model, Vector3(0.15, 0.58, 0.16), Vector3(-0.16, -0.91, 0), weapon_color.darkened(0.22), 0.9)
	elif "marteau" in weapon_name.to_lower():
		_box(weapon_model, Vector3(0.13, 1.12, 0.13), Vector3(0, -0.47, 0), Color("#583925"), 0.15)
		_box(weapon_model, Vector3(0.72, 0.38, 0.38), Vector3(0, -1.0, 0), weapon_color, 0.95)
	else:
		_box(weapon_model, Vector3(0.12, 0.3, 0.12), Vector3(0, -0.08, 0), Color("#4b2d20"), 0.2)
		_box(weapon_model, Vector3(0.58, 0.11, 0.16), Vector3(0, -0.25, 0), Color("#80603b"), 0.35)
		_box(weapon_model, Vector3(0.13, 1.22, 0.12), Vector3(0, -0.86, 0), weapon_color, 0.95)
		_box(weapon_model, Vector3(0.08, 0.24, 0.08), Vector3(0, -1.57, 0), weapon_color.lightened(0.08), 0.95)
	var helmet: Dictionary = equipment.get("helmet", {})
	if not helmet.is_empty():
		var helmet_color: Color = helmet.get("color", Color("#666b73"))
		_box(equipment_visuals, Vector3(0.66, 0.28, 0.66), Vector3(0, 2.18, 0), helmet_color, 0.86)
		_box(equipment_visuals, Vector3(0.72, 0.12, 0.54), Vector3(0, 2.02, 0.02), helmet_color.darkened(0.18), 0.82)
		for x in [-0.24, 0.24]:
			var horn := _box(equipment_visuals, Vector3(0.1, 0.46, 0.1), Vector3(x, 2.43, -0.05), Color("#aa9874"))
			horn.rotation.z = -0.42 * sign(x)
	var armor: Dictionary = equipment.get("armor", {})
	if not armor.is_empty():
		var armor_color: Color = armor.get("color", Color("#50545d"))
		_box(equipment_visuals, Vector3(0.92, 0.68, 0.52), Vector3(0, 1.25, 0), armor_color, 0.8)
		for x in [-0.54, 0.54]:
			_box(equipment_visuals, Vector3(0.38, 0.2, 0.62), Vector3(x, 1.57, 0), armor_color.lightened(0.08), 0.86)

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "OrbitInput"
	add_child(camera_pivot)
	camera_pivot.top_level = true
	camera_pivot.global_position = global_position + Vector3(0, 1.38, 0)
	camera_pivot.rotation_degrees = Vector3(-11, 0, 0)

func _animate(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var time := Time.get_ticks_msec() * 0.001
	var moving := planar_speed > 0.35 and is_on_floor()
	var stride_speed := 13.0 if planar_speed > WALK_SPEED + 0.5 else 9.0
	var stride := sin(time * stride_speed) * minf(0.72, planar_speed * 0.1) if moving else 0.0
	if is_dead:
		visual.rotation.z = lerpf(visual.rotation.z, 1.42, 4.0 * delta)
	elif is_dodging:
		visual.rotation.x = -sin(dodge_clock / 0.52 * PI) * 0.62
		left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, -0.45, 0.25)
		right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, 0.45, 0.25)
	elif is_attacking:
		var duration := 0.72 if combo_step == 2 else 0.58
		var phase := clampf(attack_clock / duration, 0.0, 1.0)
		# Le bras arme d'abord derrière le personnage puis traverse vers l'avant.
		# L'épée reste enfant de la paume pendant tout le mouvement.
		if combo_step == 1:
			weapon_pivot.rotation.x = lerpf(1.75, -1.05, smoothstep(0.08, 0.68, phase))
			weapon_pivot.rotation.z = lerpf(-1.0, 0.85, smoothstep(0.16, 0.7, phase))
		elif combo_step == 2:
			weapon_pivot.rotation.x = lerpf(2.45, -1.25, smoothstep(0.12, 0.72, phase))
			weapon_pivot.rotation.z = -0.12
		else:
			weapon_pivot.rotation.x = lerpf(1.55, -1.0, smoothstep(0.1, 0.64, phase))
			weapon_pivot.rotation.z = lerpf(0.72, -0.58, smoothstep(0.18, 0.68, phase))
		left_arm_pivot.rotation.x = lerpf(-0.45, 0.35, phase)
		left_arm_pivot.rotation.z = lerpf(-0.18, 0.22, phase)
		body_pivot.rotation.y = sin(phase * PI) * (0.58 if combo_step == 1 else 0.42)
		weapon_trail.visible = phase > 0.3 and phase < 0.76
	elif hit_reaction_clock > 0.0:
		visual.rotation.x = sin(hit_reaction_clock * 24.0) * 0.16
		body_pivot.rotation.z = sin(hit_reaction_clock * 31.0) * 0.12
	else:
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, 9.0 * delta)
		weapon_pivot.rotation.x = lerpf(weapon_pivot.rotation.x, -stride * 0.7, 10.0 * delta)
		weapon_pivot.rotation.z = lerpf(weapon_pivot.rotation.z, 0.0, 10.0 * delta)
		left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, stride * 0.7, 10.0 * delta)
		left_arm_pivot.rotation.z = lerpf(left_arm_pivot.rotation.z, 0.0, 10.0 * delta)
		left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, -stride, 12.0 * delta)
		right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, stride, 12.0 * delta)
		body_pivot.rotation.y = lerpf(body_pivot.rotation.y, 0.0, 10.0 * delta)
		body_pivot.rotation.z = lerpf(body_pivot.rotation.z, 0.0, 10.0 * delta)
		weapon_trail.visible = false
		visual.position.y = abs(sin(time * stride_speed)) * (0.035 if moving else 0.0) + sin(time * 2.0) * 0.008


func _box(
	parent: Node3D,
	size: Vector3,
	position_: Vector3,
	color: Color,
	metallic := 0.0,
	emissive := false
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = metallic
	material.emission_enabled = true
	material.emission = color * 0.24
	material.emission_energy_multiplier = 0.55
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.8
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _race_limb_box(
	parent: Node3D,
	size: Vector3,
	position_: Vector3,
	color: Color,
	metallic := 0.0,
	emissive := false
) -> MeshInstance3D:
	var detail := _box(parent, size, position_, color, metallic, emissive)
	race_limb_details.append(detail)
	return detail


func _add_human_details() -> void:
	var iron := Color("#373b43")
	var iron_edge := Color("#606570")
	var dark_iron := Color("#1c1f25")
	var cloth := Color("#4a171d")
	var leather := Color("#4b3023")
	# Casque fermé à visière, nuque protégée et fente lumineuse.
	_box(race_details, Vector3(0.64, 0.2, 0.64), Vector3(0, 2.23, 0), iron, 0.88)
	_box(race_details, Vector3(0.58, 0.18, 0.61), Vector3(0, 2.08, 0.015), dark_iron, 0.9)
	_box(race_details, Vector3(0.52, 0.075, 0.045), Vector3(0, 2.105, 0.335), Color("#050608"), 0.2)
	_box(race_details, Vector3(0.38, 0.045, 0.025), Vector3(0, 2.105, 0.372), Color("#dc7132"), 0.1, true)
	_box(race_details, Vector3(0.13, 0.25, 0.13), Vector3(0, 2.39, -0.04), iron_edge, 0.9)
	# Plastron à plusieurs plaques, col, ceinture et tabard déchiré.
	_box(race_details, Vector3(0.88, 0.28, 0.54), Vector3(0, 1.52, 0), iron, 0.9)
	_box(race_details, Vector3(0.68, 0.3, 0.09), Vector3(0, 1.55, 0.31), iron_edge, 0.92)
	_box(race_details, Vector3(0.46, 0.22, 0.07), Vector3(0, 1.72, 0.33), dark_iron, 0.9)
	for y in [1.32, 1.18, 1.04]:
		_box(race_details, Vector3(0.84, 0.09, 0.57), Vector3(0, y, 0), iron.darkened((1.32 - y) * 0.7), 0.88)
	_box(race_details, Vector3(0.94, 0.14, 0.58), Vector3(0, 0.94, 0), leather, 0.15)
	_box(race_details, Vector3(0.22, 0.2, 0.08), Vector3(0, 0.94, 0.34), iron_edge, 0.9)
	_box(race_details, Vector3(0.48, 0.78, 0.055), Vector3(0, 0.67, 0.32), cloth)
	for x in [-0.19, 0.0, 0.19]:
		var rag := _box(race_details, Vector3(0.17, 0.3 + abs(x), 0.06), Vector3(x, 0.22 + abs(x) * 0.15, 0.32), cloth.darkened(abs(x) * 0.3))
		rag.rotation.z = x * 0.24
	# Épaulières surdimensionnées et segmentées, comme la référence.
	for x in [-0.61, 0.61]:
		for layer in range(3):
			var shoulder := _box(
				race_details,
				Vector3(0.42 - layer * 0.035, 0.2, 0.66 - layer * 0.06),
				Vector3(x, 1.68 - layer * 0.14, -0.015),
				iron_edge.darkened(layer * 0.1),
				0.9
			)
			shoulder.rotation.z = -0.13 * sign(x)
		_box(race_details, Vector3(0.25, 0.28, 0.26), Vector3(x, 1.27, 0), dark_iron, 0.88)
		_box(race_details, Vector3(0.29, 0.18, 0.3), Vector3(x, 1.09, 0), iron_edge, 0.9)
		_box(race_details, Vector3(0.25, 0.28, 0.26), Vector3(x, 0.91, 0), iron, 0.9)
	# Grèves, genouillères et bottes en plaques.
	for x in [-0.28, 0.28]:
		_box(race_details, Vector3(0.28, 0.2, 0.3), Vector3(x, 0.72, 0.025), iron_edge, 0.9)
		_box(race_details, Vector3(0.25, 0.35, 0.25), Vector3(x, 0.48, 0), iron, 0.9)
		_box(race_details, Vector3(0.31, 0.2, 0.42), Vector3(x, 0.17, 0.1), dark_iron, 0.88)
	# Rivets visibles sans saturer le rendu Web.
	for x in [-0.36, 0.36]:
		for y in [1.41, 1.61]:
			_box(race_details, Vector3(0.055, 0.055, 0.035), Vector3(x, y, 0.35), Color("#8c755b"), 0.7)

func _add_orc_details() -> void:
	var skin := Color("#66733f")
	var skin_shadow := Color("#49552f")
	var rust := Color("#51453f")
	var rust_edge := Color("#74665b")
	var leather := Color("#513521")
	# Tête massive : arcade, nez, mâchoire, oreilles, défenses et crête.
	var orc_head := _box(
		race_details,
		Vector3(0.68, 0.2, 0.58),
		Vector3(0, 2.04, 0),
		skin,
		0.0
	)
	orc_head.name = "OrcHead"
	_box(race_details, Vector3(0.5, 0.2, 0.18), Vector3(0, 1.83, 0.3), skin_shadow)
	_box(race_details, Vector3(0.2, 0.2, 0.18), Vector3(0, 1.98, 0.35), skin_shadow)
	for brow_x in [-0.16, 0.16]:
		_box(
			race_details,
			Vector3(0.28, 0.06, 0.05),
			Vector3(brow_x, 2.12, 0.38),
			Color("#30351f")
		)
	_box(race_details, Vector3(0.06, 0.045, 0.025), Vector3(-0.055, 1.95, 0.455), Color("#241d17"))
	_box(race_details, Vector3(0.06, 0.045, 0.025), Vector3(0.055, 1.95, 0.455), Color("#241d17"))
	for x in [-0.47, 0.47]:
		var ear := _box(race_details, Vector3(0.3, 0.13, 0.21), Vector3(x, 2.0, 0), skin)
		ear.rotation.z = 0.18 * sign(x)
	for x in [-0.18, 0.18]:
		var tusk := _box(race_details, Vector3(0.1, 0.3, 0.1), Vector3(x, 1.78, 0.42), Color("#d0c39b"))
		tusk.rotation.z = -0.18 * sign(x)
		tusk.name = "OrcTusk"
		_box(race_details, Vector3(0.1, 0.07, 0.035), Vector3(x, 2.04, 0.39), Color("#d78737"), 0.0, true)
	for z in [-0.16, 0.0, 0.16]:
		_box(race_details, Vector3(0.14, 0.32 + abs(z), 0.16), Vector3(0, 2.3, z), Color("#171619"))
	# Torse très large, harnais croisé clouté et ceinture à poches.
	_box(race_details, Vector3(1.04, 0.72, 0.58), Vector3(0, 1.36, 0), skin_shadow)
	for x in [-0.24, 0.24]:
		var strap := _box(race_details, Vector3(0.13, 0.94, 0.07), Vector3(x, 1.45, 0.34), leather, 0.05)
		strap.rotation.z = 0.5 * sign(x)
		for y in [1.18, 1.46, 1.72]:
			_box(race_details, Vector3(0.065, 0.065, 0.035), Vector3(x + (y - 1.45) * sign(x) * 0.46, y, 0.39), Color("#8b765d"), 0.75)
	var harness_buckle := _box(
		race_details,
		Vector3(0.22, 0.22, 0.08),
		Vector3(0, 1.43, 0.38),
		rust_edge,
		0.82
	)
	harness_buckle.name = "OrcHarness"
	_box(race_details, Vector3(1.08, 0.16, 0.62), Vector3(0, 0.91, 0), leather, 0.05)
	_box(race_details, Vector3(0.26, 0.23, 0.1), Vector3(0, 0.91, 0.39), rust_edge, 0.8)
	for x in [-0.42, 0.42]:
		_box(race_details, Vector3(0.3, 0.36, 0.18), Vector3(x, 0.72, 0.3), Color("#76502b"))
	# Armure d'épaule rouillée à couches, gros avant-bras et phalanges.
	for x in [-0.66, 0.66]:
		for layer in range(3):
			var shoulder := _box(race_details, Vector3(0.48 - layer * 0.04, 0.2, 0.7 - layer * 0.07), Vector3(x, 1.65 - layer * 0.13, 0), rust_edge.darkened(layer * 0.1), 0.72)
			shoulder.rotation.z = -0.14 * sign(x)
			shoulder.name = "OrcShoulderPlate"
		var arm_parent := left_arm_pivot if x < 0.0 else weapon_pivot
		_race_limb_box(arm_parent, Vector3(0.3, 0.32, 0.3), Vector3(0, -0.32, 0), skin, 0.0)
		_race_limb_box(arm_parent, Vector3(0.34, 0.28, 0.34), Vector3(0, -0.56, 0), rust, 0.62)
		for finger in range(3):
			_race_limb_box(arm_parent, Vector3(0.08, 0.2, 0.1), Vector3((finger - 1) * 0.08, -0.77, 0.04), skin_shadow)
	# Lanières de cuisses, pagne et lourdes bottes.
	_box(race_details, Vector3(0.54, 0.55, 0.07), Vector3(0, 0.55, 0.33), Color("#664322"))
	for x in [-0.29, 0.29]:
		var leg_parent := left_leg_pivot if x < 0.0 else right_leg_pivot
		_race_limb_box(leg_parent, Vector3(0.27, 0.13, 0.28), Vector3(0, -0.22, 0), leather)
		_race_limb_box(leg_parent, Vector3(0.31, 0.32, 0.3), Vector3(0, -0.4, 0), rust, 0.55)
		_race_limb_box(leg_parent, Vector3(0.4, 0.2, 0.48), Vector3(0, -0.66, 0.11), Color("#33251c"), 0.2)

func _add_goblin_details() -> void:
	var skin := Color("#6f7d38")
	var skin_shadow := Color("#4d5927")
	var leather := Color("#4a2f1d")
	var dark_leather := Color("#2c2018")
	var scrap_iron := Color("#625c58")
	var cloth := Color("#755129")
	# Tête anguleuse : crâne, longues oreilles, arcade, nez et mâchoire à défenses.
	var goblin_head := _box(
		race_details,
		Vector3(0.62, 0.42, 0.54),
		Vector3(0, 2.0, 0),
		skin
	)
	goblin_head.name = "GoblinHead"
	for x in [-0.49, 0.49]:
		var ear := _box(race_details, Vector3(0.48, 0.12, 0.23), Vector3(x, 2.04, -0.01), skin)
		ear.rotation.z = 0.2 * sign(x)
		ear.name = "GoblinEar"
		_box(race_details, Vector3(0.2, 0.075, 0.16), Vector3(x * 0.99, 2.03, 0.025), Color("#98704d"))
	_box(race_details, Vector3(0.52, 0.1, 0.12), Vector3(0, 2.08, 0.3), skin_shadow)
	_box(race_details, Vector3(0.17, 0.28, 0.18), Vector3(0, 1.93, 0.38), Color("#99704b"))
	_box(race_details, Vector3(0.07, 0.045, 0.025), Vector3(-0.045, 1.91, 0.475), Color("#36271b"))
	_box(race_details, Vector3(0.07, 0.045, 0.025), Vector3(0.045, 1.91, 0.475), Color("#36271b"))
	var cheek_scar := _box(race_details, Vector3(0.04, 0.22, 0.025), Vector3(0.25, 1.88, 0.4), Color("#9b6841"))
	cheek_scar.rotation.z = 0.48
	_box(race_details, Vector3(0.45, 0.17, 0.18), Vector3(0, 1.78, 0.3), skin_shadow)
	for x in [-0.17, 0.17]:
		_box(race_details, Vector3(0.075, 0.06, 0.035), Vector3(x, 2.02, 0.39), Color("#f0bd2e"), 0.0, true)
		var tusk := _box(race_details, Vector3(0.075, 0.22, 0.075), Vector3(x, 1.72, 0.41), Color("#d5c8a2"))
		tusk.rotation.z = -0.16 * sign(x)
	# Torse maigre, bandoulière cloutée et épaulière asymétrique en fer récupéré.
	_box(race_details, Vector3(0.72, 0.62, 0.46), Vector3(0, 1.38, 0), skin_shadow)
	var strap := _box(race_details, Vector3(0.13, 0.96, 0.07), Vector3(-0.13, 1.48, 0.3), leather, 0.05)
	strap.rotation.z = -0.55
	for y in [1.18, 1.44, 1.7]:
		_box(race_details, Vector3(0.06, 0.06, 0.035), Vector3(-0.13 + (y - 1.48) * 0.48, y, 0.35), scrap_iron, 0.72)
	for layer in range(3):
		var shoulder := _box(race_details, Vector3(0.35 - layer * 0.035, 0.16, 0.54 - layer * 0.05), Vector3(0.47, 1.65 - layer * 0.11, 0), scrap_iron.darkened(layer * 0.1), 0.64)
		shoulder.rotation.z = -0.15
		shoulder.name = "GoblinScrapShoulder"
	for x in [-0.45, 0.45]:
		var arm_parent := left_arm_pivot if x < 0.0 else weapon_pivot
		_race_limb_box(arm_parent, Vector3(0.22, 0.3, 0.22), Vector3(0, -0.32, 0), skin)
		for band in range(3):
			_race_limb_box(arm_parent, Vector3(0.25, 0.075, 0.25), Vector3(0, -0.49 - band * 0.08, 0), dark_leather)
		for finger in range(3):
			_race_limb_box(arm_parent, Vector3(0.055, 0.16, 0.07), Vector3((finger - 1) * 0.055, -0.75, 0.04), skin_shadow)
	# Ceinture, boucle, sacoches, pagne déchiré et bottes carrées.
	_box(race_details, Vector3(0.82, 0.13, 0.5), Vector3(0, 0.88, 0), dark_leather)
	_box(race_details, Vector3(0.21, 0.19, 0.08), Vector3(0, 0.88, 0.31), scrap_iron, 0.74)
	for x in [-0.34, 0.34]:
		_box(race_details, Vector3(0.24, 0.3, 0.14), Vector3(x, 0.73, 0.25), leather)
	_box(race_details, Vector3(0.42, 0.54, 0.06), Vector3(0, 0.55, 0.29), cloth)
	for x in [-0.28, 0.28]:
		var leg_parent := left_leg_pivot if x < 0.0 else right_leg_pivot
		_race_limb_box(leg_parent, Vector3(0.22, 0.12, 0.24), Vector3(0, -0.26, 0), leather)
		_race_limb_box(leg_parent, Vector3(0.24, 0.29, 0.25), Vector3(0, -0.45, 0), dark_leather)
		_race_limb_box(leg_parent, Vector3(0.36, 0.18, 0.43), Vector3(0, -0.67, 0.1), Color("#33271d"), 0.15)


func _add_dwarf_details() -> void:
	var beard := Color("#9b4e28")
	var beard_light := Color("#bd7133")
	var iron := Color("#3d4148")
	var iron_edge := Color("#676b72")
	var leather := Color("#4a2d1e")
	var cloth := Color("#4b171c")
	var gold := Color("#a87932")
	# Casque bas et lourd, composé de plaques et d'un frontal riveté.
	_box(race_details, Vector3(0.72, 0.23, 0.7), Vector3(0, 2.2, 0), iron, 0.9)
	_box(race_details, Vector3(0.64, 0.17, 0.68), Vector3(0, 2.06, 0.01), iron.darkened(0.15), 0.92)
	_box(race_details, Vector3(0.15, 0.37, 0.12), Vector3(0, 2.24, 0.32), iron_edge, 0.9)
	_box(race_details, Vector3(0.1, 0.1, 0.05), Vector3(0, 2.28, 0.4), gold, 0.72)
	for x in [-0.27, 0.27]:
		_box(race_details, Vector3(0.065, 0.065, 0.035), Vector3(x, 2.09, 0.38), gold, 0.72)
	# Visage trapu et barbe rousse volumineuse en mèches tressées.
	_box(race_details, Vector3(0.2, 0.18, 0.18), Vector3(0, 1.91, 0.39), Color("#a96f52"))
	_box(race_details, Vector3(0.56, 0.17, 0.16), Vector3(0, 1.78, 0.31), beard.darkened(0.12))
	for row in range(4):
		var row_y := 1.68 - row * 0.14
		var width := 0.54 - row * 0.07
		_box(race_details, Vector3(width, 0.18, 0.17), Vector3(0, row_y, 0.34), beard.lightened(row * 0.025))
	for x in [-0.24, 0.0, 0.24]:
		for segment in range(3):
			_box(race_details, Vector3(0.12, 0.18, 0.12), Vector3(x, 1.37 - segment * 0.14, 0.36), beard_light.darkened(segment * 0.07))
		_box(race_details, Vector3(0.15, 0.1, 0.13), Vector3(x, 1.08, 0.36), gold, 0.68)
		_box(race_details, Vector3(0.11, 0.19, 0.11), Vector3(x, 0.94, 0.36), beard)
	# Plastron sombre, épaulières étagées et tunique bordeaux.
	_box(race_details, Vector3(1.02, 0.68, 0.58), Vector3(0, 1.38, 0), cloth)
	for y in [1.55, 1.39, 1.23]:
		_box(race_details, Vector3(0.9, 0.12, 0.6), Vector3(0, y, 0), iron.darkened((1.55 - y) * 0.35), 0.9)
	_box(race_details, Vector3(0.56, 0.54, 0.07), Vector3(0, 1.35, 0.34), cloth.darkened(0.15))
	for x in [-0.58, 0.58]:
		for layer in range(3):
			var shoulder := _box(race_details, Vector3(0.42 - layer * 0.04, 0.19, 0.64 - layer * 0.055), Vector3(x, 1.69 - layer * 0.12, 0), iron_edge.darkened(layer * 0.1), 0.92)
			shoulder.rotation.z = -0.12 * sign(x)
		_box(race_details, Vector3(0.28, 0.31, 0.28), Vector3(x, 1.21, 0), cloth.darkened(0.12))
		for band in range(3):
			_box(race_details, Vector3(0.31, 0.09, 0.3), Vector3(x, 1.02 - band * 0.09, 0), iron.darkened(band * 0.08), 0.88)
	# Ceinture de cuir, boucle dorée, tabard et lourdes bottes de forge.
	_box(race_details, Vector3(1.0, 0.16, 0.62), Vector3(0, 0.88, 0), leather, 0.08)
	_box(race_details, Vector3(0.28, 0.25, 0.09), Vector3(0, 0.88, 0.39), gold, 0.78)
	for x in [-0.39, 0.39]:
		_box(race_details, Vector3(0.27, 0.31, 0.15), Vector3(x, 0.73, 0.29), leather)
	_box(race_details, Vector3(0.5, 0.55, 0.06), Vector3(0, 0.55, 0.34), cloth)
	for x in [-0.3, 0.3]:
		_box(race_details, Vector3(0.31, 0.2, 0.32), Vector3(x, 0.55, 0), iron_edge, 0.9)
		_box(race_details, Vector3(0.3, 0.31, 0.3), Vector3(x, 0.35, 0), iron, 0.9)
		_box(race_details, Vector3(0.43, 0.2, 0.5), Vector3(x, 0.12, 0.12), Color("#30241c"), 0.2)


func _spawn_damage_number(amount: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = "-%d" % roundi(amount)
	label.position = Vector3(randf_range(-0.25, 0.25), 2.5, 0)
	label.font_size = 42
	label.outline_size = 9
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", 3.35, 0.72)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.72)
	tween.tween_callback(label.queue_free)
