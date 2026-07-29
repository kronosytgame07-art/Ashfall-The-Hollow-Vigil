class_name AshfallSoulsEnemy
extends CharacterBody3D

signal defeated(enemy: AshfallSoulsEnemy)

var health := 78.0
var move_speed := 2.4
var attack_damage := 17.0
var detection_range := 13.0
var attack_clock := 0.0
var hit_serial := -1
var dead := false
var visual: Node3D
var arm_pivot: Node3D
var weapon_grip: Node3D
var left_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var target: AshfallSoulsPlayer
var spawn_position := Vector3.ZERO
var enemy_level := 1
var enemy_name := "Déchu"
var level_label: Label3D
var health_label: Label3D
var archetype_details: Node3D
var weapon_parts: Node3D
var attack_has_landed := false
var hit_reaction_clock := 0.0
var knockback := Vector3.ZERO
var base_visual_scale := Vector3.ONE
var loot_items: Array[Dictionary] = []
var corpse_label: Label3D
var looted := false

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	spawn_position = global_position
	target = get_tree().get_first_node_in_group("player") as AshfallSoulsPlayer
	_build_collision()
	_build_visual()

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.4
	hit_reaction_clock = maxf(0.0, hit_reaction_clock - delta)
	knockback = knockback.move_toward(Vector3.ZERO, 9.0 * delta)
	if is_instance_valid(target) and not target.is_dead:
		var offset := target.global_position - global_position
		offset.y = 0.0
		if attack_clock > 0.0:
			attack_clock = maxf(0.0, attack_clock - delta)
			velocity.x = knockback.x
			velocity.z = knockback.z
			if attack_clock <= 0.58 and not attack_has_landed and offset.length() < 2.05:
				attack_has_landed = true
				target.take_damage(attack_damage)
		elif offset.length() <= detection_range:
			if offset.length() > 1.65:
				var direction := offset.normalized()
				velocity.x = move_toward(velocity.x, direction.x * move_speed, 9.0 * delta)
				velocity.z = move_toward(velocity.z, direction.z * move_speed, 9.0 * delta)
				rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-8.0 * delta))
			else:
				velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
				if attack_clock <= 0.0:
					attack_clock = 1.15
					attack_has_landed = false
		else:
			_return_to_spawn(delta)
	else:
		_return_to_spawn(delta)
	move_and_slide()
	_animate(delta)

func _return_to_spawn(delta: float) -> void:
	var offset := spawn_position - global_position
	offset.y = 0.0
	if offset.length() > 0.5:
		var direction := offset.normalized()
		velocity.x = move_toward(velocity.x, direction.x * move_speed * 0.65, 8.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed * 0.65, 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)

func take_damage(amount: float, serial: int, direction := Vector3.ZERO) -> void:
	if dead or serial == hit_serial:
		return
	hit_serial = serial
	health -= amount
	hit_reaction_clock = 0.32
	knockback = direction * 3.8
	visual.scale = Vector3(1.18, 0.8, 1.18)
	_spawn_damage_number(amount)
	_update_health_label()
	if health <= 0.0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		remove_from_group("enemy")
		add_to_group("corpse")
		add_to_group("lootable_corpse")
		loot_items = _generate_loot()
		defeated.emit(self)
		var tween := create_tween()
		tween.tween_property(visual, "rotation:z", 1.45, 0.42).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(visual, "position:y", 0.16, 0.42)
		if level_label:
			level_label.visible = false
		if health_label:
			health_label.visible = false
		_build_corpse_label()

func loot_all() -> Array:
	if not dead or looted:
		return []
	looted = true
	remove_from_group("lootable_corpse")
	if corpse_label:
		corpse_label.text = "DÉPOUILLÉ"
		corpse_label.modulate = Color("#615b58")
		var fade := create_tween()
		fade.tween_interval(1.4)
		fade.tween_property(corpse_label, "modulate:a", 0.0, 0.8)
	return loot_items.duplicate(true)

func _generate_loot() -> Array[Dictionary]:
	var seed_value := enemy_name.hash() + enemy_level * 7919
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var metal := Color("#8c929b")
	if "givre" in enemy_name.to_lower() or "boréal" in enemy_name.to_lower():
		metal = Color("#78aeca")
	elif "braise" in enemy_name.to_lower() or "magma" in enemy_name.to_lower():
		metal = Color("#b84a2d")
	var weapon_kind: String = ["Épée", "Hache", "Marteau"][posmod(enemy_level + enemy_name.length(), 3)]
	var drops: Array[Dictionary] = [{
		"name": "%s de %s" % [weapon_kind, enemy_name],
		"slot": "weapon",
		"power": 2 + enemy_level * 2,
		"color": metal,
	}]
	if rng.randf() < 0.68 or enemy_level >= 5:
		drops.append({
			"name": "Casque de %s" % enemy_name,
			"slot": "helmet",
			"power": 1 + enemy_level,
			"color": metal.darkened(0.16),
		})
	if rng.randf() < 0.52 or enemy_level >= 7:
		drops.append({
			"name": "Cuirasse de %s" % enemy_name,
			"slot": "armor",
			"power": 1 + enemy_level,
			"color": metal.darkened(0.28),
		})
	return drops

func _build_corpse_label() -> void:
	corpse_label = Label3D.new()
	corpse_label.text = "[ E ] FOUILLER"
	corpse_label.position = Vector3(0, 1.05, 0)
	corpse_label.font_size = 28
	corpse_label.outline_size = 8
	corpse_label.modulate = Color("#e1bc86")
	corpse_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	corpse_label.no_depth_test = true
	add_child(corpse_label)

func configure(level_: int, archetype: String) -> void:
	enemy_level = level_
	enemy_name = archetype
	health = 58.0 + enemy_level * 20.0
	attack_damage = 8.0 + enemy_level * 5.0
	move_speed = minf(3.5, 2.0 + enemy_level * 0.16)
	detection_range = 10.0 + enemy_level
	if level_label:
		level_label.text = "%s  •  NIV. %d" % [enemy_name.to_upper(), enemy_level]
		level_label.modulate = (
			Color("#d25145") if enemy_level >= 5
			else Color("#d6c7ae") if enemy_level <= 2
			else Color("#d1954f")
		)
	if enemy_level >= 5:
		base_visual_scale = Vector3.ONE * (1.16 + minf(0.12, enemy_level * 0.01))
		visual.scale = base_visual_scale
	_apply_archetype_details()
	_update_health_label()

func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.44
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.86
	add_child(collider)

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	archetype_details = Node3D.new()
	archetype_details.name = "ArchetypeDetails"
	visual.add_child(archetype_details)
	_box(Vector3(0.78, 0.88, 0.48), Vector3(0, 1.15, 0), Color("#242128"))
	_box(Vector3(0.54, 0.52, 0.54), Vector3(0, 1.88, 0), Color("#353039"))
	_box(Vector3(0.43, 0.08, 0.04), Vector3(0, 1.91, 0.29), Color("#080609"))
	_box(Vector3(0.07, 0.05, 0.025), Vector3(-0.12, 1.91, 0.32), Color("#b72524"), true)
	_box(Vector3(0.07, 0.05, 0.025), Vector3(0.12, 1.91, 0.32), Color("#b72524"), true)
	left_leg_pivot = Node3D.new()
	left_leg_pivot.position = Vector3(-0.26, 0.8, 0)
	visual.add_child(left_leg_pivot)
	var left_leg := _box(Vector3(0.18, 0.72, 0.18), Vector3(0, -0.36, 0), Color("#17151a"))
	visual.remove_child(left_leg)
	left_leg_pivot.add_child(left_leg)
	right_leg_pivot = Node3D.new()
	right_leg_pivot.position = Vector3(0.26, 0.8, 0)
	visual.add_child(right_leg_pivot)
	var right_leg := _box(Vector3(0.18, 0.72, 0.18), Vector3(0, -0.36, 0), Color("#17151a"))
	visual.remove_child(right_leg)
	right_leg_pivot.add_child(right_leg)
	left_arm_pivot = Node3D.new()
	left_arm_pivot.position = Vector3(-0.55, 1.5, 0)
	visual.add_child(left_arm_pivot)
	var left_arm := _box(Vector3(0.18, 0.74, 0.18), Vector3(0, -0.37, 0), Color("#2b2730"))
	visual.remove_child(left_arm)
	left_arm_pivot.add_child(left_arm)
	arm_pivot = Node3D.new()
	arm_pivot.position = Vector3(0.56, 1.5, 0)
	visual.add_child(arm_pivot)
	var right_arm := _box(Vector3(0.18, 0.7, 0.18), Vector3(0, -0.35, 0), Color("#2b2730"))
	visual.remove_child(right_arm)
	arm_pivot.add_child(right_arm)
	weapon_grip = Node3D.new()
	weapon_grip.position = Vector3(0, -0.7, 0)
	arm_pivot.add_child(weapon_grip)
	weapon_parts = Node3D.new()
	weapon_parts.name = "WeaponParts"
	weapon_grip.add_child(weapon_parts)
	# Layered armour, belt and joints make the silhouette readable as a fighter.
	_box(Vector3(0.88, 0.16, 0.52), Vector3(0, 1.5, 0), Color("#4b454e"))
	_box(Vector3(0.82, 0.14, 0.54), Vector3(0, 0.84, 0), Color("#5c3e29"))
	for x in [-0.27, 0.27]:
		_box(Vector3(0.22, 0.16, 0.24), Vector3(x, 0.78, 0), Color("#4b4650"))
		_box(Vector3(0.23, 0.18, 0.28), Vector3(x, 0.12, 0.04), Color("#37323b"))
	# L'arme est enfant de la paume et ne peut plus flotter ni changer de main.
	var hand := _box(Vector3(0.22, 0.18, 0.22), Vector3.ZERO, Color("#29262d"))
	visual.remove_child(hand)
	weapon_grip.add_child(hand)
	_build_sword_weapon()
	level_label = Label3D.new()
	level_label.text = "%s  •  NIV. %d" % [enemy_name.to_upper(), enemy_level]
	level_label.position = Vector3(0, 2.55, 0)
	level_label.font_size = 30
	level_label.outline_size = 8
	level_label.modulate = Color("#d6c7ae")
	level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_label.no_depth_test = true
	add_child(level_label)
	health_label = Label3D.new()
	health_label.position = Vector3(0, 2.3, 0)
	health_label.font_size = 24
	health_label.outline_size = 7
	health_label.modulate = Color("#9d3031")
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.no_depth_test = true
	add_child(health_label)

func _animate(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var moving := planar_speed > 0.25 and attack_clock <= 0.0
	var stride := sin(time * (7.0 + move_speed)) * minf(0.62, planar_speed * 0.18) if moving else 0.0
	visual.scale = visual.scale.lerp(base_visual_scale, 0.12)
	visual.position.y = abs(sin(time * (7.0 + move_speed))) * (0.026 if moving else 0.0)
	if hit_reaction_clock > 0.0:
		visual.rotation.z = sin(hit_reaction_clock * 30.0) * 0.17
	elif attack_clock > 0.72:
		# Armé derrière l'épaule, lame toujours tenue dans la main.
		arm_pivot.rotation.x = lerpf(arm_pivot.rotation.x, 1.95, 0.2)
		arm_pivot.rotation.z = lerpf(arm_pivot.rotation.z, -0.35, 0.18)
		left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, -0.45, 0.16)
		visual.rotation.x = lerpf(visual.rotation.x, -0.12, 0.12)
	elif attack_clock > 0.35:
		# Le tranchant traverse vers l'avant, dans le même sens que les dégâts.
		arm_pivot.rotation.x = lerpf(arm_pivot.rotation.x, -1.15, 0.36)
		arm_pivot.rotation.z = lerpf(arm_pivot.rotation.z, 0.28, 0.3)
		left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, 0.35, 0.22)
	else:
		arm_pivot.rotation.x = lerpf(arm_pivot.rotation.x, -stride * 0.7, 10.0 * delta)
		arm_pivot.rotation.z = lerpf(arm_pivot.rotation.z, 0.0, 10.0 * delta)
		left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, stride * 0.7, 10.0 * delta)
		left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, -stride, 12.0 * delta)
		right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, stride, 12.0 * delta)
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, 10.0 * delta)
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, 10.0 * delta)


func _box(size: Vector3, position_: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = color * 0.18
	material.emission_energy_multiplier = 0.42
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.2
	instance.material_override = material
	visual.add_child(instance)
	return instance

func _apply_archetype_details() -> void:
	for child in archetype_details.get_children():
		child.queue_free()
	for child in weapon_parts.get_children():
		child.queue_free()
	weapon_parts.position = Vector3.ZERO
	weapon_parts.rotation = Vector3.ZERO
	var lower_name := enemy_name.to_lower()
	if "errant" in lower_name:
		_build_errant_details()
		_build_errant_staff()
		return
	if "pilleur" in lower_name or "pillard" in lower_name:
		_build_hollow_raider_details()
		_build_hollow_raider_scythe()
		return
	if "déchu" in lower_name:
		_build_fallen_details()
		_build_fallen_greatsword()
		return
	_build_sword_weapon()
	# Silhouette commune lisible : plaques superposées, protections articulées,
	# tabard abîmé et petits rivets. Les variantes ajoutent ensuite leur identité.
	for x in [-0.52, 0.52]:
		for layer in range(3):
			var pauldron := _detail_box(
				Vector3(0.38 - layer * 0.035, 0.18, 0.62 - layer * 0.055),
				Vector3(x, 1.61 - layer * 0.12, 0),
				Color("#5b5358").darkened(layer * 0.09)
			)
			pauldron.rotation.z = -0.12 * sign(x)
		_detail_box(Vector3(0.23, 0.2, 0.27), Vector3(x, 1.03, 0), Color("#51494f"))
		for finger in range(3):
			_detail_box(Vector3(0.055, 0.16, 0.075), Vector3(x + (finger - 1) * 0.055, 0.75, 0.04), Color("#29262d"))
	for y in [1.39, 1.2, 1.02]:
		_detail_box(Vector3(0.82, 0.1, 0.53), Vector3(0, y, 0.01), Color("#4d464e").darkened((1.39 - y) * 0.45))
	_detail_box(Vector3(0.42, 0.58, 0.055), Vector3(0, 0.72, 0.3), Color("#47171b"))
	for x in [-0.17, 0.0, 0.17]:
		var torn_cloth := _detail_box(Vector3(0.15, 0.24 + abs(x), 0.06), Vector3(x, 0.37, 0.3), Color("#3a1115"))
		torn_cloth.rotation.z = x * 0.25
	for x in [-0.27, 0.27]:
		_detail_box(Vector3(0.28, 0.18, 0.31), Vector3(x, 0.7, 0.02), Color("#585159"))
		_detail_box(Vector3(0.27, 0.28, 0.27), Vector3(x, 0.42, 0), Color("#302d34"))
		_detail_box(Vector3(0.34, 0.18, 0.42), Vector3(x, 0.15, 0.1), Color("#211f24"))
	for x in [-0.27, 0.27]:
		for y in [1.22, 1.47]:
			_detail_box(Vector3(0.05, 0.05, 0.035), Vector3(x, y, 0.31), Color("#8b765e"))
	if "givre" in lower_name or "boréal" in lower_name:
		for x in [-0.42, 0.0, 0.42]:
			var crystal := _detail_box(Vector3(0.16, 0.72, 0.16), Vector3(x, 2.18 + abs(x), -0.16), Color("#82b8ce"), true)
			crystal.rotation.z = x * 0.72
		_detail_box(Vector3(0.98, 0.22, 0.58), Vector3(0, 1.48, 0), Color("#566b78"))
	elif "braise" in lower_name or "magma" in lower_name:
		for y in [0.88, 1.2, 1.52]:
			_detail_box(Vector3(0.9, 0.1, 0.54), Vector3(0, y, 0.02), Color("#c53b1c"), true)
		for x in [-0.48, 0.48]:
			var spike := _detail_box(Vector3(0.18, 0.74, 0.18), Vector3(x, 1.7, 0), Color("#351510"))
			spike.rotation.z = -0.48 * sign(x)
	elif "pilleur" in lower_name:
		_detail_box(Vector3(0.76, 0.2, 0.68), Vector3(0, 2.12, -0.03), Color("#1b161d"))
		for x in [-0.4, 0.4]:
			var dagger := _detail_box(Vector3(0.08, 0.58, 0.1), Vector3(x, 0.92, -0.3), Color("#756f78"))
			dagger.rotation.z = 0.45 * sign(x)
	elif enemy_level >= 2:
		_detail_box(Vector3(0.48, 0.62, 0.08), Vector3(0, 1.12, -0.31), Color("#42161b"))

func _build_fallen_details() -> void:
	var black_iron := Color("#202225")
	var plate := Color("#36383b")
	var plate_edge := Color("#555355")
	var rust := Color("#59443a")
	var leather := Color("#422a20")
	var chain_color := Color("#766452")
	var cloth := Color("#4a171b")
	var cyan := Color("#2bd3dc")

	base_visual_scale = Vector3.ONE * 1.08
	visual.scale = base_visual_scale

	# Heaume intégral à cimier, visière cyan et grille verticale.
	var helmet_crown := _detail_box(
		Vector3(0.72, 0.25, 0.7),
		Vector3(0, 2.18, -0.01),
		plate
	)
	helmet_crown.name = "FallenHelmet"
	_detail_box(Vector3(0.65, 0.25, 0.64), Vector3(0, 2.01, 0), black_iron)
	_detail_box(Vector3(0.54, 0.09, 0.045), Vector3(0, 2.07, 0.35), Color("#04090a"))
	for eye_x in [-0.16, 0.16]:
		var fallen_eye := _detail_box(
			Vector3(0.11, 0.055, 0.025),
			Vector3(eye_x, 2.08, 0.39),
			cyan,
			true
		)
		fallen_eye.name = "FallenCyanEye"
	for grille_x in [-0.2, -0.1, 0.0, 0.1, 0.2]:
		_detail_box(
			Vector3(0.06, 0.25, 0.045),
			Vector3(grille_x, 1.88, 0.37),
			plate_edge
		)
	for crest_y in [2.36, 2.51, 2.64]:
		var crest_height: float = 0.18 + (crest_y - 2.36) * 0.35
		_detail_box(
			Vector3(0.18, crest_height, 0.2),
			Vector3(0, crest_y, -0.04),
			black_iron
		)

	# Plastron noir superposé, col lourd et tabard bordeaux déchiré.
	_detail_box(Vector3(0.95, 0.25, 0.6), Vector3(0, 1.58, 0), plate)
	_detail_box(Vector3(0.72, 0.18, 0.12), Vector3(0, 1.68, 0.31), plate_edge)
	for chest_y in [1.45, 1.28, 1.11]:
		_detail_box(
			Vector3(0.9, 0.14, 0.59),
			Vector3(0, chest_y, 0),
			black_iron.lightened((1.45 - chest_y) * 0.11)
		)
	_detail_box(Vector3(0.48, 0.83, 0.07), Vector3(0, 0.78, 0.34), cloth)
	for tabard_x in [-0.18, 0.0, 0.18]:
		var tabard_strip := _detail_box(
			Vector3(0.16, 0.43 + abs(tabard_x), 0.075),
			Vector3(tabard_x, 0.36, 0.35),
			cloth.darkened(abs(tabard_x) * 0.38)
		)
		tabard_strip.rotation.z = tabard_x * 0.22

	# Épaulières massives et protections articulées.
	for side in [-1.0, 1.0]:
		for layer in range(4):
			var fallen_plate := _detail_box(
				Vector3(
					0.48 - layer * 0.04,
					0.19,
					0.72 - layer * 0.055
				),
				Vector3(side * 0.62, 1.75 - layer * 0.12, -0.01),
				plate_edge.darkened(layer * 0.09)
			)
			fallen_plate.rotation.z = -0.14 * side
			fallen_plate.name = "FallenShoulderPlate"
		for arm_y in [1.26, 1.08, 0.9]:
			_detail_box(
				Vector3(0.28, 0.16, 0.32),
				Vector3(side * 0.56, arm_y, 0.01),
				plate.darkened((1.26 - arm_y) * 0.25)
			)
	for leg_x in [-0.27, 0.27]:
		_detail_box(Vector3(0.3, 0.2, 0.34), Vector3(leg_x, 0.7, 0.02), plate_edge)
		_detail_box(Vector3(0.29, 0.3, 0.3), Vector3(leg_x, 0.45, 0), plate)
		_detail_box(Vector3(0.4, 0.22, 0.48), Vector3(leg_x, 0.14, 0.11), black_iron)

	# Harnais de cuir et doubles chaînes croisées sur le torse.
	for strap_side in [-1.0, 1.0]:
		var harness := _detail_box(
			Vector3(0.13, 1.02, 0.07),
			Vector3(strap_side * 0.2, 1.4, 0.34),
			leather
		)
		harness.rotation.z = 0.54 * strap_side
	for link in range(8):
		var link_x := -0.35 + link * 0.1
		var link_y := 1.72 - link * 0.09
		var chain_left := _detail_box(
			Vector3(0.1, 0.06, 0.045),
			Vector3(link_x, link_y, 0.4),
			chain_color
		)
		chain_left.rotation.z = -0.68
		chain_left.name = "FallenChestChain"
		var chain_right := _detail_box(
			Vector3(0.1, 0.06, 0.045),
			Vector3(-link_x, link_y, 0.42),
			chain_color.darkened(0.08)
		)
		chain_right.rotation.z = 0.68

	# Grand manteau en lambeaux et pavois porté dans le dos.
	for cape_x in [-0.32, -0.16, 0.0, 0.16, 0.32]:
		var cape_length: float = 1.0 + abs(cape_x) * 0.6
		var cape_strip := _detail_box(
			Vector3(0.17, cape_length, 0.07),
			Vector3(cape_x, 0.68 - abs(cape_x) * 0.1, -0.36),
			Color("#111215").lightened(abs(cape_x) * 0.05)
		)
		cape_strip.rotation.z = cape_x * 0.2
	var back_shield := _detail_box(
		Vector3(0.98, 1.22, 0.14),
		Vector3(0, 1.16, -0.48),
		plate
	)
	back_shield.name = "FallenBackShield"
	_detail_box(Vector3(0.76, 0.96, 0.07), Vector3(0, 1.16, -0.57), cloth.darkened(0.12))
	_detail_box(Vector3(0.18, 0.86, 0.05), Vector3(0, 1.16, -0.62), plate_edge)
	_detail_box(Vector3(0.65, 0.16, 0.05), Vector3(0, 1.16, -0.625), plate_edge)
	for shield_x in [-0.32, 0.32]:
		for shield_y in [0.76, 1.54]:
			_detail_box(
				Vector3(0.07, 0.07, 0.04),
				Vector3(shield_x, shield_y, -0.65),
				rust
			)

func _build_fallen_greatsword() -> void:
	weapon_parts.position.y = 0.08
	weapon_parts.rotation.z = 1.05
	var handle := _weapon_box(
		Vector3(0.15, 0.48, 0.15),
		Vector3(0, -0.08, 0),
		Color("#3d271c")
	)
	handle.name = "FallenGreatswordHandle"
	_weapon_box(Vector3(0.76, 0.15, 0.2), Vector3(0, -0.29, 0), Color("#5b4c42"))
	_weapon_box(Vector3(0.2, 0.18, 0.2), Vector3(0, 0.18, 0), Color("#51453d"))
	var blade := _weapon_box(
		Vector3(0.3, 1.38, 0.15),
		Vector3(0, -0.98, 0),
		Color("#555557")
	)
	blade.name = "FallenGreatsword"
	_weapon_box(Vector3(0.16, 1.16, 0.17), Vector3(0, -0.94, 0), Color("#343538"))
	var tip := _weapon_box(
		Vector3(0.25, 0.34, 0.14),
		Vector3(0, -1.75, 0),
		Color("#656569")
	)
	tip.rotation.z = 0.12

func _build_sword_weapon() -> void:
	var handle := _weapon_box(
		Vector3(0.12, 0.3, 0.12),
		Vector3(0, -0.08, 0),
		Color("#4a2d20")
	)
	handle.name = "EnemySwordHandle"
	var guard := _weapon_box(
		Vector3(0.56, 0.12, 0.16),
		Vector3(0, -0.25, 0),
		Color("#714b2d")
	)
	guard.name = "EnemySwordGuard"
	var blade := _weapon_box(
		Vector3(0.14, 1.25, 0.12),
		Vector3(0, -0.88, 0),
		Color("#7c7073")
	)
	blade.name = "EnemySwordBlade"

func _build_errant_details() -> void:
	var cloth_dark := Color("#211f1d")
	var cloth_mid := Color("#36322e")
	var cloth_light := Color("#49433c")
	var leather := Color("#4a3426")
	var rope := Color("#806342")
	var ember := Color("#f2a536")

	# La silhouette reprend la référence : visage noyé dans l'ombre, capuche
	# épaisse, pèlerine en couches et longue robe usée.
	var face_void := _detail_box(
		Vector3(0.5, 0.38, 0.055),
		Vector3(0, 1.9, 0.355),
		Color("#050505")
	)
	face_void.name = "ErrantFaceVoid"
	for eye_x in [-0.11, 0.11]:
		var eye := _detail_box(
			Vector3(0.075, 0.065, 0.025),
			Vector3(eye_x, 1.93, 0.395),
			ember,
			true
		)
		eye.name = "ErrantEmberEye"
	var hood_top := _detail_box(
		Vector3(0.72, 0.22, 0.66),
		Vector3(0, 2.15, -0.01),
		cloth_light
	)
	hood_top.name = "ErrantHood"
	_detail_box(Vector3(0.68, 0.14, 0.12), Vector3(0, 2.08, 0.31), cloth_mid)
	for hood_side in [-1.0, 1.0]:
		var hood_cheek := _detail_box(
			Vector3(0.18, 0.56, 0.62),
			Vector3(hood_side * 0.31, 1.93, -0.01),
			cloth_mid.darkened(0.04)
		)
		hood_cheek.rotation.z = -0.08 * hood_side
		_detail_box(
			Vector3(0.2, 0.48, 0.4),
			Vector3(hood_side * 0.42, 1.72, -0.1),
			cloth_dark
		)
	for mantle_layer in range(4):
		var mantle := _detail_box(
			Vector3(
				1.02 - mantle_layer * 0.055,
				0.17,
				0.68 - mantle_layer * 0.04
			),
			Vector3(0, 1.64 - mantle_layer * 0.12, -0.01),
			cloth_light.darkened(mantle_layer * 0.07)
		)
		mantle.name = "ErrantMantle"
	# Le manteau couvre l'ancienne cuirasse générique et se termine en pans
	# irréguliers, comme sur la vue de dos et la vue de face.
	for robe_y in [1.22, 1.03, 0.84]:
		_detail_box(
			Vector3(0.82, 0.22, 0.56),
			Vector3(0, robe_y, 0),
			cloth_mid.darkened((1.22 - robe_y) * 0.18)
		)
	_detail_box(Vector3(0.66, 0.72, 0.08), Vector3(0, 0.73, 0.31), cloth_dark)
	_detail_box(Vector3(0.66, 0.82, 0.08), Vector3(0, 0.82, -0.31), cloth_dark)
	for strip_index in range(5):
		var strip_x := -0.28 + strip_index * 0.14
		var strip_length := 0.34 + float((strip_index + 1) % 3) * 0.09
		var robe_strip := _detail_box(
			Vector3(0.13, strip_length, 0.09),
			Vector3(strip_x, 0.35 - strip_length * 0.08, 0.3),
			cloth_dark.darkened(float(strip_index % 2) * 0.08)
		)
		robe_strip.rotation.z = strip_x * 0.18
	for belt_x in [-0.3, -0.15, 0.0, 0.15, 0.3]:
		var rope_segment := _detail_box(
			Vector3(0.16, 0.09, 0.08),
			Vector3(belt_x, 0.91 + abs(belt_x) * 0.05, 0.34),
			rope
		)
		rope_segment.rotation.z = belt_x * 0.25
	_detail_box(Vector3(0.13, 0.26, 0.1), Vector3(0.1, 0.76, 0.35), rope)
	_detail_box(Vector3(0.38, 0.42, 0.18), Vector3(-0.48, 0.93, -0.18), leather)
	_detail_box(Vector3(0.32, 0.1, 0.2), Vector3(-0.48, 1.12, -0.14), leather.lightened(0.08))
	for arm_x in [-0.55, 0.55]:
		for wrap_y in [1.18, 1.06, 0.94]:
			_detail_box(
				Vector3(0.24, 0.09, 0.27),
				Vector3(arm_x, wrap_y, 0.02),
				Color("#776f63").darkened((1.18 - wrap_y) * 0.4)
			)
	for boot_x in [-0.27, 0.27]:
		_detail_box(Vector3(0.34, 0.2, 0.44), Vector3(boot_x, 0.14, 0.1), Color("#2b211a"))

func _build_errant_staff() -> void:
	var wood := Color("#382619")
	var iron := Color("#393735")
	var ember := Color("#f2a536")
	var staff := _weapon_box(
		Vector3(0.12, 2.55, 0.12),
		Vector3(0, 0.18, 0),
		wood
	)
	staff.name = "ErrantStaff"
	_weapon_box(Vector3(0.14, 0.42, 0.14), Vector3(0.02, 1.33, 0), wood.lightened(0.08))
	var crook_top := _weapon_box(
		Vector3(0.42, 0.12, 0.12),
		Vector3(0.14, 1.53, 0),
		wood
	)
	crook_top.rotation.z = 0.08
	_weapon_box(Vector3(0.12, 0.4, 0.12), Vector3(0.34, 1.36, 0), wood.darkened(0.08))
	for chain_y in [1.12, 1.0]:
		_weapon_box(Vector3(0.07, 0.12, 0.07), Vector3(0.34, chain_y, 0), iron)
	_weapon_box(Vector3(0.48, 0.1, 0.38), Vector3(0.34, 0.89, 0), iron)
	_weapon_box(Vector3(0.48, 0.1, 0.38), Vector3(0.34, 0.38, 0), iron)
	for cage_x in [0.14, 0.54]:
		_weapon_box(Vector3(0.065, 0.5, 0.065), Vector3(cage_x, 0.64, 0), iron)
	for cage_z in [-0.16, 0.16]:
		_weapon_box(Vector3(0.065, 0.5, 0.065), Vector3(0.34, 0.64, cage_z), iron)
	var lantern_core := _weapon_box(
		Vector3(0.25, 0.32, 0.22),
		Vector3(0.34, 0.64, 0),
		ember,
		true
	)
	lantern_core.name = "ErrantLanternLight"
	_weapon_box(Vector3(0.26, 0.12, 0.22), Vector3(0.34, 0.27, 0), iron)

func _build_hollow_raider_details() -> void:
	var iron_dark := Color("#302a27")
	var iron_mid := Color("#51453d")
	var iron_light := Color("#6a584a")
	var leather := Color("#4a3020")
	var bone := Color("#c9b995")
	var bone_shadow := Color("#887a60")
	var teal := Color("#173d3d")

	# Masque crâne, capuche courte et mâchoire dentée.
	_detail_box(Vector3(0.68, 0.26, 0.62), Vector3(0, 2.13, -0.02), iron_dark)
	_detail_box(Vector3(0.62, 0.24, 0.6), Vector3(0, 1.98, -0.01), Color("#171513"))
	var skull := _detail_box(
		Vector3(0.56, 0.34, 0.1),
		Vector3(0, 1.99, 0.35),
		bone
	)
	skull.name = "HollowRaiderSkullMask"
	_detail_box(Vector3(0.48, 0.12, 0.12), Vector3(0, 2.15, 0.33), bone.lightened(0.06))
	for socket_x in [-0.14, 0.14]:
		_detail_box(
			Vector3(0.14, 0.12, 0.035),
			Vector3(socket_x, 2.02, 0.415),
			Color("#080706")
		)
	_detail_box(Vector3(0.08, 0.13, 0.035), Vector3(0, 1.9, 0.415), Color("#17120e"))
	_detail_box(Vector3(0.4, 0.2, 0.1), Vector3(0, 1.77, 0.35), bone_shadow)
	for tooth_x in [-0.15, -0.05, 0.05, 0.15]:
		_detail_box(Vector3(0.07, 0.18, 0.08), Vector3(tooth_x, 1.71, 0.4), bone)
	# Cuirasse de plaques brunes, épaulières dissymétriques et tabard bleu-vert.
	for chest_y in [1.48, 1.31, 1.14]:
		_detail_box(
			Vector3(0.86, 0.15, 0.56),
			Vector3(0, chest_y, 0.01),
			iron_mid.darkened((1.48 - chest_y) * 0.28)
		)
	_detail_box(Vector3(0.22, 0.76, 0.07), Vector3(-0.17, 1.34, 0.32), leather)
	for strap_index in range(6):
		var strap_x := -0.31 + strap_index * 0.12
		var strap_y := 1.67 - strap_index * 0.13
		var strap := _detail_box(
			Vector3(0.17, 0.08, 0.055),
			Vector3(strap_x, strap_y, 0.35),
			leather.lightened(0.08)
		)
		strap.rotation.z = -0.78
	for shoulder_side in [-1.0, 1.0]:
		for plate_layer in range(4):
			var shoulder_plate := _detail_box(
				Vector3(
					0.42 - plate_layer * 0.035,
					0.18,
					0.68 - plate_layer * 0.055
				),
				Vector3(
					shoulder_side * 0.57,
					1.69 - plate_layer * 0.11,
					-0.01
				),
				iron_light.darkened(plate_layer * 0.09)
			)
			shoulder_plate.rotation.z = -0.14 * shoulder_side
		if shoulder_side < 0.0:
			for spike_index in range(3):
				var shoulder_spike := _detail_box(
					Vector3(0.12, 0.42 - spike_index * 0.07, 0.12),
					Vector3(-0.66 - spike_index * 0.08, 1.82 - spike_index * 0.1, -0.05),
					iron_mid
				)
				shoulder_spike.rotation.z = 0.58 + spike_index * 0.08
	for arm_x in [-0.55, 0.55]:
		for plate_y in [1.2, 1.04, 0.88]:
			_detail_box(
				Vector3(0.25, 0.13, 0.3),
				Vector3(arm_x, plate_y, 0.01),
				iron_mid.darkened((1.2 - plate_y) * 0.3)
			)
	_detail_box(Vector3(0.5, 0.58, 0.07), Vector3(0, 0.72, 0.32), teal)
	for tabard_x in [-0.18, 0.0, 0.18]:
		var tabard := _detail_box(
			Vector3(0.16, 0.46 + abs(tabard_x), 0.07),
			Vector3(tabard_x, 0.4, 0.33),
			teal.darkened(abs(tabard_x) * 0.3)
		)
		tabard.rotation.z = tabard_x * 0.3
	_detail_box(Vector3(0.88, 0.14, 0.6), Vector3(0, 0.84, 0), leather)
	for pouch_x in [-0.47, 0.47]:
		_detail_box(Vector3(0.3, 0.34, 0.22), Vector3(pouch_x, 0.76, -0.03), leather)
		_detail_box(
			Vector3(0.28, 0.09, 0.24),
			Vector3(pouch_x, 0.91, -0.01),
			leather.lightened(0.1)
		)
	# Paquetage visible de profil et de dos : sac, rouleau, sangles et fiole.
	var pack := _detail_box(
		Vector3(0.78, 0.92, 0.28),
		Vector3(0, 1.23, -0.46),
		leather.darkened(0.08)
	)
	pack.name = "HollowRaiderPack"
	_detail_box(Vector3(0.88, 0.28, 0.34), Vector3(0, 1.78, -0.45), teal.darkened(0.05))
	for pack_x in [-0.28, 0.28]:
		_detail_box(Vector3(0.1, 1.03, 0.06), Vector3(pack_x, 1.29, -0.63), iron_mid)
	_detail_box(Vector3(0.22, 0.44, 0.2), Vector3(0.52, 1.04, -0.4), Color("#1e5352"))
	_detail_box(Vector3(0.12, 0.12, 0.12), Vector3(0.52, 1.32, -0.4), iron_light)
	for boot_x in [-0.27, 0.27]:
		_detail_box(Vector3(0.36, 0.22, 0.46), Vector3(boot_x, 0.14, 0.1), iron_dark)

func _build_hollow_raider_scythe() -> void:
	var wood := Color("#342116")
	var iron := Color("#302c29")
	var iron_edge := Color("#49433d")
	var shaft := _weapon_box(
		Vector3(0.13, 2.65, 0.13),
		Vector3(0, 0.15, 0),
		wood
	)
	shaft.name = "HollowRaiderScytheShaft"
	for grip_y in [-0.35, -0.2, 0.88]:
		_weapon_box(Vector3(0.17, 0.13, 0.17), Vector3(0, grip_y, 0), Color("#6b5033"))
	var blade_root := _weapon_box(
		Vector3(0.16, 0.46, 0.15),
		Vector3(0.1, 1.34, 0),
		iron
	)
	blade_root.rotation.z = 0.2
	for blade_index in range(4):
		var blade_piece := _weapon_box(
			Vector3(0.15, 0.5 - blade_index * 0.055, 0.13),
			Vector3(
				0.24 + blade_index * 0.15,
				1.5 + blade_index * 0.12,
				0
			),
			iron_edge.lightened(blade_index * 0.035)
		)
		blade_piece.rotation.z = 0.42 + blade_index * 0.17
		blade_piece.name = "HollowRaiderScytheBlade"
	_weapon_box(Vector3(0.1, 0.24, 0.1), Vector3(0.76, 1.85, 0), iron_edge)
	for chain_y in [0.72, 0.58, 0.44]:
		var chain_link := _weapon_box(
			Vector3(0.1, 0.07, 0.055),
			Vector3(0.12, chain_y, 0),
			iron
		)
		chain_link.rotation.z = chain_y * 0.3

func _weapon_box(size: Vector3, position_: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.4
	instance.material_override = material
	weapon_parts.add_child(instance)
	return instance

func _detail_box(size: Vector3, position_: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.5
	instance.material_override = material
	archetype_details.add_child(instance)
	return instance

func _spawn_damage_number(amount: float) -> void:
	var label := Label3D.new()
	label.text = "%d" % roundi(amount)
	label.position = Vector3(randf_range(-0.3, 0.3), 2.6, 0)
	label.font_size = 44
	label.outline_size = 9
	label.modulate = Color("#f1c68f")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", 3.45, 0.68)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.68)
	tween.tween_callback(label.queue_free)

func _update_health_label() -> void:
	if health_label:
		health_label.text = "PV %d" % maxi(0, roundi(health))
