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

var camera_pivot: Node3D
var camera: Camera3D
var visual: Node3D
var weapon_pivot: Node3D
var body_pivot: Node3D
var race_details: Node3D
var weapon_trail: MeshInstance3D
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
	if is_dead:
		return
	invulnerable_clock = maxf(0.0, invulnerable_clock - delta)
	combo_timeout = maxf(0.0, combo_timeout - delta)
	hit_reaction_clock = maxf(0.0, hit_reaction_clock - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

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
				var combo_damage := [31.0, 38.0, 52.0][combo_step]
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
	match selected_race:
		"Orque":
			visual.scale = Vector3(1.12, 1.08, 1.12)
			_tint_skin(Color("#52623a"))
			_add_orc_details()
		"Gobelin":
			visual.scale = Vector3(0.78, 0.78, 0.78)
			_tint_skin(Color("#66733f"))
			_add_goblin_details()
		"Nain":
			visual.scale = Vector3(1.08, 0.78, 1.08)
			_tint_skin(Color("#8a604a"))
			_add_dwarf_details()
		_:
			visual.scale = Vector3.ONE
			_tint_skin(Color("#8d604b"))
			_add_human_details()

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
	_box(visual, Vector3(0.16, 0.76, 0.18), Vector3(-0.27, 0.43, 0), Color("#1a1b21"), 0.6)
	_box(visual, Vector3(0.16, 0.76, 0.18), Vector3(0.27, 0.43, 0), Color("#1a1b21"), 0.6)
	_box(visual, Vector3(0.18, 0.7, 0.18), Vector3(-0.57, 1.15, 0), Color("#30343e"), 0.75)
	weapon_pivot = Node3D.new()
	weapon_pivot.position = Vector3(0.58, 1.45, 0)
	visual.add_child(weapon_pivot)
	_box(weapon_pivot, Vector3(0.16, 0.72, 0.16), Vector3(0, -0.3, 0), Color("#30343e"), 0.75)
	_box(weapon_pivot, Vector3(0.1, 1.28, 0.12), Vector3(0, -0.92, 0), Color("#aeb3bb"), 0.95)
	_box(weapon_pivot, Vector3(0.52, 0.1, 0.12), Vector3(0, -0.36, 0), Color("#6e4b2e"), 0.2)
	_box(visual, Vector3(0.62, 0.72, 0.12), Vector3(-0.58, 1.18, 0.02), Color("#393d46"), 0.82)
	_box(visual, Vector3(0.48, 0.58, 0.05), Vector3(-0.58, 1.18, 0.09), Color("#651c1f"), 0.15)
	var cape := _box(visual, Vector3(0.66, 1.08, 0.08), Vector3(0, 1.2, -0.29), Color("#351014"), 0.0)
	cape.rotation.x = -0.08
	weapon_trail = _box(
		weapon_pivot,
		Vector3(0.42, 1.18, 0.025),
		Vector3(0.18, -0.9, 0),
		Color(0.75, 0.16, 0.08, 0.42),
		0.0,
		true
	)
	weapon_trail.visible = false

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraRig"
	camera_pivot.position = Vector3(0, 1.55, 0)
	camera_pivot.rotation_degrees = Vector3(-14, 180, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0.75, 1.2, 5.3)
	camera.fov = 62.0
	camera.current = true
	camera_pivot.add_child(camera)

func _animate(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var time := Time.get_ticks_msec() * 0.001
	if is_dead:
		visual.rotation.z = lerpf(visual.rotation.z, 1.42, 4.0 * delta)
	elif is_dodging:
		visual.rotation.x = -sin(dodge_clock / 0.52 * PI) * 0.62
	elif is_attacking:
		var duration := 0.72 if combo_step == 2 else 0.58
		var phase := clampf(attack_clock / duration, 0.0, 1.0)
		if combo_step == 1:
			weapon_pivot.rotation.z = lerpf(-1.9, 1.15, smoothstep(0.1, 0.62, phase))
			weapon_pivot.rotation.x = -0.5
		elif combo_step == 2:
			weapon_pivot.rotation.x = lerpf(-2.65, 1.8, smoothstep(0.18, 0.68, phase))
		else:
			weapon_pivot.rotation.x = lerpf(-1.3, 1.65, smoothstep(0.15, 0.55, phase))
		body_pivot.rotation.y = sin(phase * PI) * (0.52 if combo_step == 1 else 0.38)
		weapon_trail.visible = phase > 0.28 and phase < 0.72
	elif hit_reaction_clock > 0.0:
		visual.rotation.x = sin(hit_reaction_clock * 24.0) * 0.16
		body_pivot.rotation.z = sin(hit_reaction_clock * 31.0) * 0.12
	else:
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, 9.0 * delta)
		weapon_pivot.rotation.x = lerpf(weapon_pivot.rotation.x, 0.0, 10.0 * delta)
		weapon_pivot.rotation.z = lerpf(weapon_pivot.rotation.z, 0.0, 10.0 * delta)
		body_pivot.rotation.y = lerpf(body_pivot.rotation.y, 0.0, 10.0 * delta)
		body_pivot.rotation.z = lerpf(body_pivot.rotation.z, 0.0, 10.0 * delta)
		weapon_trail.visible = false
		visual.position.y = sin(time * (9.0 if planar_speed > 0.5 else 2.0)) * (0.045 if planar_speed > 0.5 else 0.012)

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
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.8
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_human_details() -> void:
	_box(race_details, Vector3(0.12, 0.72, 0.12), Vector3(0, 2.55, -0.08), Color("#49171b"))
	_box(race_details, Vector3(0.32, 0.13, 0.58), Vector3(-0.53, 1.56, 0), Color("#777d88"), 0.9)
	_box(race_details, Vector3(0.32, 0.13, 0.58), Vector3(0.53, 1.56, 0), Color("#777d88"), 0.9)
	for x in [-0.28, 0.28]:
		_box(race_details, Vector3(0.08, 0.28, 0.06), Vector3(x, 1.2, 0.28), Color("#a98b56"), 0.55)

func _add_orc_details() -> void:
	for x in [-0.16, 0.16]:
		var tusk := _box(race_details, Vector3(0.09, 0.28, 0.1), Vector3(x, 1.77, 0.39), Color("#d0c39b"))
		tusk.rotation.z = -0.2 * sign(x)
	for x in [-0.62, 0.62]:
		_box(race_details, Vector3(0.42, 0.24, 0.68), Vector3(x, 1.54, 0), Color("#3e3b3d"), 0.7)
		for spike in range(2):
			var horn := _box(race_details, Vector3(0.1, 0.38, 0.1), Vector3(x, 1.78, -0.14 + spike * 0.28), Color("#8e836c"))
			horn.rotation.z = -0.38 * sign(x)
	_box(race_details, Vector3(0.58, 0.12, 0.05), Vector3(0, 1.84, 0.34), Color("#2a1513"))

func _add_goblin_details() -> void:
	for x in [-0.43, 0.43]:
		var ear := _box(race_details, Vector3(0.48, 0.12, 0.24), Vector3(x, 1.9, 0), Color("#66733f"))
		ear.rotation.z = 0.22 * sign(x)
	var hood := _box(race_details, Vector3(0.72, 0.18, 0.68), Vector3(0, 2.14, -0.03), Color("#241a28"))
	hood.rotation.z = 0.06
	for x in [-0.42, 0.42]:
		var knife := _box(race_details, Vector3(0.08, 0.62, 0.1), Vector3(x, 0.92, -0.32), Color("#99919a"), 0.82)
		knife.rotation.z = 0.45 * sign(x)

func _add_dwarf_details() -> void:
	for y in range(4):
		_box(race_details, Vector3(0.48 - y * 0.06, 0.17, 0.18), Vector3(0, 1.67 - y * 0.15, 0.34), Color("#6b3523"))
	for x in [-0.34, 0.34]:
		var horn := _box(race_details, Vector3(0.12, 0.55, 0.12), Vector3(x, 2.23, 0), Color("#b9a47b"))
		horn.rotation.z = -0.55 * sign(x)
	_box(race_details, Vector3(0.92, 0.25, 0.58), Vector3(0, 1.42, 0), Color("#4d5058"), 0.88)
	for x in [-0.32, 0.0, 0.32]:
		_box(race_details, Vector3(0.1, 0.42, 0.08), Vector3(x, 1.38, 0.32), Color("#b17b38"), 0.48)

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
