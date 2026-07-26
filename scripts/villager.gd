class_name AshfallVillager
extends Node3D

@export var walk_speed := 1.65
@export var roam_radius := 18.0

var target := Vector3.ZERO
var stride_phase := 0.0
var _rng := RandomNumberGenerator.new()
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var torso: Node3D

func _ready() -> void:
	_rng.randomize()
	_build_character()
	_pick_target()

func _process(delta: float) -> void:
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.45:
		_pick_target()
		return
	var direction := offset.normalized()
	global_position += direction * walk_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 7.0)
	stride_phase = fmod(stride_phase + delta * walk_speed * 4.9, TAU)
	_animate_walk()

func _pick_target() -> void:
	target = Vector3(
		_rng.randf_range(-roam_radius, roam_radius),
		0.0,
		_rng.randf_range(-roam_radius, roam_radius)
	)

func _animate_walk() -> void:
	var stride := sin(stride_phase)
	var compression := maxf(0.0, -cos(stride_phase * 2.0))
	left_leg.rotation.x = stride * 0.62
	right_leg.rotation.x = -stride * 0.62
	left_arm.rotation.x = -stride * 0.48
	right_arm.rotation.x = stride * 0.48
	torso.position.y = 1.72 - compression * 0.055
	torso.rotation.z = sin(stride_phase) * 0.025

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

func _part(parent: Node3D, name_: String, size: Vector3, position_: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position_
	mesh_node.material_override = _mat(color)
	parent.add_child(mesh_node)
	return mesh_node

func _limb(name_: String, x: float, y: float, arm := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = Vector3(x, y, 0)
	add_child(pivot)
	var size := Vector3(0.24, 0.88, 0.28) if arm else Vector3(0.34, 0.92, 0.42)
	var color := Color("#3a2921") if arm else Color("#242329")
	_part(pivot, "Mesh", size, Vector3(0, -size.y * 0.5, 0), color)
	if not arm:
		_part(pivot, "Boot", Vector3(0.4, 0.28, 0.62), Vector3(0, -1.0, 0.11), Color("#171316"))
	return pivot

func _build_character() -> void:
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 1.72, 0)
	add_child(torso)
	_part(torso, "Body", Vector3(1.05, 1.15, 0.62), Vector3.ZERO, Color("#39271f"))
	_part(torso, "Belt", Vector3(1.14, 0.16, 0.69), Vector3(0, -0.42, 0), Color("#171316"))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.36
	head_mesh.height = 0.7
	head.mesh = head_mesh
	head.position = Vector3(0, 0.85, 0)
	head.material_override = _mat(Color("#9c6546"))
	torso.add_child(head)
	var hood := MeshInstance3D.new()
	var hood_mesh := SphereMesh.new()
	hood_mesh.radius = 0.49
	hood_mesh.height = 0.8
	hood.mesh = hood_mesh
	hood.position = Vector3(0, 0.92, -0.06)
	hood.scale = Vector3(1.0, 1.08, 0.88)
	hood.material_override = _mat(Color("#2b201e"))
	torso.add_child(hood)
	left_leg = _limb("LeftLeg", -0.28, 1.15)
	right_leg = _limb("RightLeg", 0.28, 1.15)
	left_arm = _limb("LeftArm", -0.68, 2.12, true)
	right_arm = _limb("RightArm", 0.68, 2.12, true)
