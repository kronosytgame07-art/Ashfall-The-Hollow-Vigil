class_name BuildingFactory
extends RefCounted

const FOOTPRINTS := {
	"town_hall": Vector2i(3, 3),
	"gold_mine": Vector2i(2, 2),
	"barracks": Vector2i(2, 2),
	"forge": Vector2i(2, 2),
	"tower": Vector2i(2, 2),
	"wall": Vector2i(1, 1)
}

static func footprint(kind: String) -> Vector2i:
	return FOOTPRINTS.get(kind, Vector2i.ONE)

static func create(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	root.set_meta("building_kind", kind)
	root.set_meta("footprint", footprint(kind))
	match kind:
		"town_hall": _town_hall(root)
		"gold_mine": _gold_mine(root)
		"barracks": _barracks(root)
		"forge": _forge(root)
		"tower": _tower(root)
		"wall": _wall(root)
		_: _wall(root)
	return root

static func _material(color: Color, roughness := 0.82, emission := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 2.2
	return mat

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rotation_y := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation.y = rotation_y
	node.material_override = _material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node

static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, sides := 8) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

static func _roof(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(radius * 2.0, height, radius * 2.0)
	node.mesh = mesh
	node.position = pos
	node.rotation.y = PI * 0.25
	node.material_override = _material(color)
	parent.add_child(node)
	return node

static func _flame(parent: Node3D, pos: Vector3) -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.32
	orb.mesh = sphere
	orb.position = pos
	orb.material_override = _material(Color(1.0, 0.35, 0.05), 0.2, Color(1.0, 0.16, 0.01))
	parent.add_child(orb)
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color(1.0, 0.38, 0.12)
	light.light_energy = 1.8
	light.omni_range = 4.2
	parent.add_child(light)

static func _town_hall(root: Node3D) -> void:
	_box(root, Vector3(5.1, 0.5, 5.1), Vector3(0, 0.25, 0), Color("#201d20"))
	_box(root, Vector3(4.2, 3.1, 4.2), Vector3(0, 1.8, 0), Color("#403b42"))
	_box(root, Vector3(1.25, 2.4, 1.0), Vector3(0, 1.35, 2.25), Color("#21140f"))
	_roof(root, 3.15, 2.0, Vector3(0, 4.2, 0), Color("#351b18"))
	for x in [-2.0, 2.0]:
		for z in [-2.0, 2.0]:
			_cylinder(root, 0.55, 3.7, Vector3(x, 2.0, z), Color("#302d33"), 8)
			_roof(root, 0.8, 1.1, Vector3(x, 4.25, z), Color("#491f18"))
	_flame(root, Vector3(-2.0, 4.35, 2.0))
	_flame(root, Vector3(2.0, 4.35, 2.0))

static func _gold_mine(root: Node3D) -> void:
	_box(root, Vector3(3.5, 0.45, 3.5), Vector3(0, 0.22, 0), Color("#242126"))
	_cylinder(root, 1.45, 1.35, Vector3(0, 0.9, 0), Color("#41352b"), 10)
	for angle in range(0, 360, 45):
		var p := Vector3(cos(deg_to_rad(angle)), 0.65, sin(deg_to_rad(angle))) * 1.15
		_box(root, Vector3(0.3, 0.9, 0.3), p, Color("#9b6b22"))
	var crystal := _cylinder(root, 0.45, 1.8, Vector3(0, 1.9, 0), Color("#d49525"), 6)
	crystal.material_override = _material(Color("#be7b1d"), 0.3, Color("#8c3d08"))

static func _barracks(root: Node3D) -> void:
	_box(root, Vector3(3.6, 0.4, 3.6), Vector3(0, 0.2, 0), Color("#272329"))
	_box(root, Vector3(3.0, 2.1, 2.8), Vector3(0, 1.25, 0), Color("#4a3a31"))
	_roof(root, 2.25, 1.4, Vector3(0, 2.9, 0), Color("#51221c"))
	_box(root, Vector3(0.8, 1.5, 0.25), Vector3(0, 0.9, 1.53), Color("#1b110d"))
	_flame(root, Vector3(1.25, 1.55, 1.65))

static func _forge(root: Node3D) -> void:
	_box(root, Vector3(3.6, 0.4, 3.6), Vector3(0, 0.2, 0), Color("#211e22"))
	_box(root, Vector3(2.8, 1.8, 2.8), Vector3(0, 1.1, 0), Color("#3a3332"))
	_roof(root, 2.05, 1.2, Vector3(0, 2.45, 0), Color("#321918"))
	_cylinder(root, 0.38, 2.8, Vector3(0.9, 2.2, -0.55), Color("#252126"), 8)
	_flame(root, Vector3(-0.65, 1.05, 1.45))

static func _tower(root: Node3D) -> void:
	_box(root, Vector3(3.5, 0.45, 3.5), Vector3(0, 0.22, 0), Color("#252228"))
	_cylinder(root, 1.35, 4.6, Vector3(0, 2.5, 0), Color("#3d3940"), 10)
	_roof(root, 1.8, 1.7, Vector3(0, 5.45, 0), Color("#3d1c1b"))
	_flame(root, Vector3(0, 5.25, 1.1))

static func _wall(root: Node3D) -> void:
	_box(root, Vector3(1.8, 1.35, 1.8), Vector3(0, 0.68, 0), Color("#38343a"))
	for x in [-0.68, 0.0, 0.68]:
		_box(root, Vector3(0.42, 0.4, 0.42), Vector3(x, 1.55, 0), Color("#48434b"))
