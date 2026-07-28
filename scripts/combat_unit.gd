class_name AshfallCombatUnit
extends CharacterBody3D

enum UnitKind { WARRIOR, ARCHER, BRUTE, HERO }
enum Action { IDLE, MOVE, ATTACK }

@export var kind := UnitKind.WARRIOR
@export var move_speed := 2.25
@export var turn_speed := 11.0
@export_range(0.35, 0.7, 0.01) var camp_scale := 0.48

var action := Action.IDLE
var destination := Vector3.ZERO
var animation_time := 0.0
var facing_sector := 0
var _visual: Node3D
var _torso: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _weapon: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	add_to_group("moving_units")
	_build_collision()
	_build_model()
	destination = global_position

func move_to(world_position: Vector3) -> void:
	destination = world_position
	action = Action.MOVE

func attack() -> void:
	action = Action.ATTACK
	animation_time = 0.0

func _physics_process(delta: float) -> void:
	animation_time += delta
	if action == Action.MOVE:
		var offset := destination - global_position
		offset.y = 0.0
		if offset.length() < 0.2:
			action = Action.IDLE
			velocity = Vector3.ZERO
		else:
			var direction := offset.normalized()
			velocity.x = move_toward(velocity.x, direction.x * move_speed, delta * 9.0)
			velocity.z = move_toward(velocity.z, direction.z * move_speed, delta * 9.0)
			var target_yaw := atan2(velocity.x, velocity.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
			facing_sector = posmod(roundi((target_yaw / TAU) * 8.0), 8)
			move_and_slide()
	elif action == Action.ATTACK and animation_time > 0.78:
		action = Action.IDLE
	_animate()

func _animate() -> void:
	match action:
		Action.MOVE:
			var phase := animation_time * move_speed * 5.0
			var stride := sin(phase)
			_left_leg.rotation.x = stride * 0.58
			_right_leg.rotation.x = -stride * 0.58
			_left_arm.rotation.x = -stride * 0.42
			_right_arm.rotation.x = stride * 0.42
			_visual.position.y = -maxf(0.0, -cos(phase * 2.0)) * 0.045
			_torso.rotation.y = -stride * 0.025
		Action.ATTACK:
			var t := clampf(animation_time / 0.78, 0.0, 1.0)
			var windup := smoothstep(0.0, 0.32, t)
			var strike := smoothstep(0.32, 0.58, t)
			var recover := smoothstep(0.58, 1.0, t)
			_right_arm.rotation.x = lerpf(-0.4, -2.15, windup) + strike * 2.95 - recover * 0.4
			_weapon.rotation.z = -windup * 0.7 + strike * 1.15 - recover * 0.45
			_torso.rotation.y = -windup * 0.38 + strike * 0.72 - recover * 0.34
		Action.IDLE:
			var breathe := sin(animation_time * 2.1)
			_visual.position.y = breathe * 0.008
			_torso.rotation.y = breathe * 0.006
			_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, 0.16)
			_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, 0.16)
			_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.0, 0.16)
			_right_arm.rotation.x = lerpf(_right_arm.rotation.x, -0.25, 0.16)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = (0.38 if kind != UnitKind.BRUTE else 0.5) * camp_scale
	capsule.height = (2.2 if kind != UnitKind.BRUTE else 2.75) * camp_scale
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)

func _mat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = metallic
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, metallic)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = 10
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, metallic)
	parent.add_child(node)
	return node

func _pivot_limb(parent: Node3D, name_: String, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = pos
	parent.add_child(pivot)
	_box(pivot, size, Vector3(0, -size.y * 0.5, 0), color)
	return pivot

func _build_model() -> void:
	var scale_factor := 1.22 if kind == UnitKind.BRUTE else 1.0
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * scale_factor * camp_scale
	add_child(_visual)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.55, 0)
	_visual.add_child(_torso)
	var armor := Color("#4b4d55")
	if kind == UnitKind.HERO:
		armor = Color("#6a5960")
	elif kind == UnitKind.ARCHER:
		armor = Color("#3d4939")
	elif kind == UnitKind.BRUTE:
		armor = Color("#51413a")
	_box(_torso, Vector3(0.9, 1.0, 0.55), Vector3.ZERO, armor, 0.5)
	_box(_torso, Vector3(1.02, 0.16, 0.65), Vector3(0, -0.39, 0), Color("#241918"))
	# Armure dark fantasy lisible même lorsque plusieurs troupes entourent un feu.
	for y in [-0.24, 0.0, 0.24]:
		_box(_torso, Vector3(0.96, 0.08, 0.64), Vector3(0, y, -0.03), Color("#70727b"), 0.72)
	_box(_torso, Vector3(0.18, 0.92, 0.64), Vector3(0, 0.02, -0.04), Color("#242127"), 0.45)
	_box(_torso, Vector3(0.34, 0.18, 0.72), Vector3(-0.53, 0.28, 0), armor, 0.62)
	_box(_torso, Vector3(0.34, 0.18, 0.72), Vector3(0.53, 0.28, 0), armor, 0.62)
	var cape_color := Color("#3a1015") if kind != UnitKind.ARCHER else Color("#182419")
	var cape := _box(_torso, Vector3(0.72, 0.94, 0.08), Vector3(0, -0.02, 0.35), cape_color)
	cape.rotation.x = -0.08
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.31
	head_mesh.height = 0.62
	head.mesh = head_mesh
	head.position = Vector3(0, 0.78, 0)
	head.material_override = _mat(Color("#8f5d42"))
	_torso.add_child(head)
	var helmet := _cylinder(_torso, 0.37, 0.34, Vector3(0, 0.93, 0), Color("#34363d"), 0.78)
	helmet.scale.z = 0.9
	_box(_torso, Vector3(0.72, 0.09, 0.55), Vector3(0, 0.84, -0.08), Color("#202126"), 0.8)
	_box(_torso, Vector3(0.06, 0.34, 0.08), Vector3(0, 1.23, 0), Color("#711820"), 0.2)
	_left_leg = _pivot_limb(_visual, "LeftLeg", Vector3(-0.23, 1.08, 0), Vector3(0.3, 0.9, 0.35), Color("#26272c"))
	_right_leg = _pivot_limb(_visual, "RightLeg", Vector3(0.23, 1.08, 0), Vector3(0.3, 0.9, 0.35), Color("#26272c"))
	_left_arm = _pivot_limb(_visual, "LeftArm", Vector3(-0.57, 1.93, 0), Vector3(0.22, 0.82, 0.25), armor)
	_right_arm = _pivot_limb(_visual, "RightArm", Vector3(0.57, 1.93, 0), Vector3(0.22, 0.82, 0.25), armor)
	_weapon = Node3D.new()
	_weapon.position = Vector3(0, -0.78, 0)
	_right_arm.add_child(_weapon)
	if kind == UnitKind.ARCHER:
		for side in [-1.0, 1.0]:
			var bow_arm := _box(_weapon, Vector3(0.08, 0.76, 0.09), Vector3(side * 0.12, -0.35 + side * 0.3, 0), Color("#6f4827"))
			bow_arm.rotation.z = side * 0.3
		_box(_weapon, Vector3(0.025, 1.45, 0.025), Vector3(0, -0.35, 0), Color("#b6aa8b"))
		_box(_torso, Vector3(0.24, 1.1, 0.24), Vector3(0.43, 0.02, 0.33), Color("#38271d"))
	else:
		_box(_weapon, Vector3(0.1, 1.15, 0.1), Vector3(0, -0.42, 0), Color("#50301d"))
		var blade_size := Vector3(0.22, 0.82, 0.08) if kind != UnitKind.BRUTE else Vector3(0.58, 0.65, 0.2)
		_box(_weapon, blade_size, Vector3(0, -1.25, 0), Color("#8c9099"), 0.8)
		_box(_weapon, Vector3(0.55, 0.09, 0.13), Vector3(0, -0.88, 0), Color("#8b5d27"), 0.55)
	if kind == UnitKind.WARRIOR or kind == UnitKind.HERO:
		var shield := _cylinder(_left_arm, 0.48, 0.12, Vector3(0, -0.58, -0.3), Color("#342f36"), 0.72)
		shield.rotation_degrees.x = 90
		_cylinder(shield, 0.12, 0.08, Vector3.ZERO, Color("#9c6530"), 0.85)
	elif kind == UnitKind.BRUTE:
		for x in [-0.32, 0.32]:
			var horn := _cylinder(_torso, 0.08, 0.58, Vector3(x, 1.22, 0), Color("#9b8c70"))
			horn.rotation_degrees.z = x * 42.0
