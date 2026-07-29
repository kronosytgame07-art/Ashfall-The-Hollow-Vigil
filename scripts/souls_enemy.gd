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
	_animate()

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
		defeated.emit(self)
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector3(0.1, 0.1, 0.1), 0.32)
		tween.parallel().tween_property(visual, "position:y", -0.8, 0.32)
		tween.tween_callback(queue_free)

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
	_box(Vector3(0.18, 0.72, 0.18), Vector3(-0.26, 0.45, 0), Color("#17151a"))
	_box(Vector3(0.18, 0.72, 0.18), Vector3(0.26, 0.45, 0), Color("#17151a"))
	_box(Vector3(0.18, 0.74, 0.18), Vector3(-0.55, 1.15, 0), Color("#2b2730"))
	arm_pivot = Node3D.new()
	arm_pivot.position = Vector3(0.56, 1.48, 0)
	visual.add_child(arm_pivot)
	_box(Vector3(0.18, 0.7, 0.18), Vector3(0.56, 1.15, 0), Color("#2b2730"))
	var blade := _box(Vector3(0.13, 1.15, 0.12), Vector3(0, -0.55, 0), Color("#7c7073"))
	visual.remove_child(blade)
	arm_pivot.add_child(blade)
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

func _animate() -> void:
	var time := Time.get_ticks_msec() * 0.001
	visual.scale = visual.scale.lerp(base_visual_scale, 0.12)
	visual.position.y = sin(time * 2.4 + global_position.x) * 0.016
	if hit_reaction_clock > 0.0:
		visual.rotation.z = sin(hit_reaction_clock * 30.0) * 0.17
	elif attack_clock > 0.72:
		# Visible wind-up: the player can read and dodge the blow.
		arm_pivot.rotation.x = lerpf(arm_pivot.rotation.x, -2.25, 0.18)
		visual.rotation.x = lerpf(visual.rotation.x, -0.12, 0.12)
	elif attack_clock > 0.35:
		arm_pivot.rotation.x = lerpf(arm_pivot.rotation.x, 1.35, 0.34)
	else:
		arm_pivot.rotation.x = lerpf(arm_pivot.rotation.x, 0.15, 0.12)
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, 0.12)
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, 0.12)

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
		for x in [-0.5, 0.5]:
			_detail_box(Vector3(0.34, 0.2, 0.62), Vector3(x, 1.48, 0), Color("#4a4149"))
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
