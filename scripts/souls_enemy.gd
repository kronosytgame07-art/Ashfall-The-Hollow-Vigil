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
	var handle := _box(Vector3(0.12, 0.3, 0.12), Vector3(0, -0.08, 0), Color("#4a2d20"))
	visual.remove_child(handle)
	weapon_grip.add_child(handle)
	var guard := _box(Vector3(0.56, 0.12, 0.16), Vector3(0, -0.25, 0), Color("#714b2d"))
	visual.remove_child(guard)
	weapon_grip.add_child(guard)
	var blade := _box(Vector3(0.14, 1.25, 0.12), Vector3(0, -0.88, 0), Color("#7c7073"))
	visual.remove_child(blade)
	weapon_grip.add_child(blade)
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
	var lower_name := enemy_name.to_lower()
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
	if "déchu" in lower_name:
		# Chevalier déchu de la référence : armure noire, visière cyan, chaînes,
		# grand manteau en lambeaux et bouclier massif fixé dans le dos.
		_detail_box(Vector3(0.66, 0.24, 0.66), Vector3(0, 2.13, 0), Color("#292b2e"))
		_detail_box(Vector3(0.58, 0.22, 0.6), Vector3(0, 1.98, 0.01), Color("#17191c"))
		_detail_box(Vector3(0.5, 0.08, 0.04), Vector3(0, 2.01, 0.34), Color("#05090a"))
		for x in [-0.16, 0.16]:
			_detail_box(Vector3(0.11, 0.055, 0.025), Vector3(x, 2.02, 0.375), Color("#31d7df"), true)
		for y in [1.54, 1.36, 1.18]:
			_detail_box(Vector3(0.92, 0.13, 0.57), Vector3(0, y, 0.02), Color("#343436").darkened((1.54 - y) * 0.5))
		for side in [-1.0, 1.0]:
			for layer in range(4):
				var fallen_pauldron := _detail_box(Vector3(0.44 - layer * 0.035, 0.17, 0.68 - layer * 0.055), Vector3(side * 0.58, 1.7 - layer * 0.11, -0.01), Color("#444448").darkened(layer * 0.08))
				fallen_pauldron.rotation.z = -0.13 * side
		# Chaînes croisées simulées par des maillons métalliques courts.
		for link in range(7):
			var chain_x := -0.31 + link * 0.1
			var chain_y := 1.68 - link * 0.09
			var chain := _detail_box(Vector3(0.1, 0.055, 0.045), Vector3(chain_x, chain_y, 0.35), Color("#76634f"))
			chain.rotation.z = -0.68
			var chain_mirror := _detail_box(Vector3(0.1, 0.055, 0.045), Vector3(-chain_x, chain_y, 0.38), Color("#625343"))
			chain_mirror.rotation.z = 0.68
		_detail_box(Vector3(0.62, 0.92, 0.07), Vector3(0, 0.9, -0.32), Color("#151518"))
		for x in [-0.24, 0.0, 0.24]:
			var cape_strip := _detail_box(Vector3(0.2, 0.92 + abs(x), 0.065), Vector3(x, 0.52 - abs(x) * 0.12, -0.34), Color("#111216"))
			cape_strip.rotation.z = x * 0.18
		_detail_box(Vector3(0.92, 1.15, 0.12), Vector3(0, 1.08, -0.42), Color("#2b2929"))
		_detail_box(Vector3(0.62, 0.82, 0.08), Vector3(0, 1.08, -0.5), Color("#5b201d"))
		for x in [-0.26, 0.26]:
			for y in [0.42, 0.64]:
				_detail_box(Vector3(0.3, 0.18, 0.32), Vector3(x, y, 0.03), Color("#3d3d40"))
	elif "givre" in lower_name or "boréal" in lower_name:
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
