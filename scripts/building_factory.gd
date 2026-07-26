class_name BuildingFactory
extends RefCounted

const FOOTPRINTS := {
	"town_hall": Vector2i(3, 3),
	"gold_mine": Vector2i(2, 2),
	"sawmill": Vector2i(2, 2),
	"barracks": Vector2i(2, 2),
	"army_camp": Vector2i(3, 3),
	"soul_altar": Vector2i(2, 2),
	"forge": Vector2i(2, 2),
	"tower": Vector2i(2, 2),
	"laboratory": Vector2i(2, 2),
	"spell_hall": Vector2i(2, 2),
	"builders_yard": Vector2i(2, 2),
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
		"sawmill": _sawmill(root)
		"barracks": _barracks(root)
		"army_camp": _army_camp(root)
		"soul_altar": _soul_altar(root)
		"forge": _forge(root)
		"tower": _tower(root)
		"laboratory": _laboratory(root)
		"spell_hall": _spell_hall(root)
		"builders_yard": _builders_yard(root)
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

static func _beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var midpoint := (a + b) * 0.5
	var length := a.distance_to(b)
	var beam := _box(parent, Vector3(width, width, length), midpoint, color)
	beam.look_at_from_position(midpoint, b, Vector3.UP)

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

static func _sawmill(root: Node3D) -> void:
	_box(root, Vector3(3.6, 0.35, 3.6), Vector3(0, 0.18, 0), Color("#292327"))
	_box(root, Vector3(2.8, 1.65, 2.6), Vector3(0, 1.0, 0), Color("#4a3022"))
	_roof(root, 2.1, 1.15, Vector3(0, 2.25, 0), Color("#34201b"))
	for z in [-1.2, -0.75, 0.85, 1.25]:
		var log := _cylinder(root, 0.23, 2.8, Vector3(-1.0, 0.42, z), Color("#5b371f"), 10)
		log.rotation.z = PI * 0.5
	var saw := _cylinder(root, 0.72, 0.08, Vector3(0.65, 1.02, 1.38), Color("#8a8588"), 16)
	saw.rotation.x = PI * 0.5

static func _barracks(root: Node3D) -> void:
	_box(root, Vector3(3.6, 0.4, 3.6), Vector3(0, 0.2, 0), Color("#272329"))
	_box(root, Vector3(3.0, 2.1, 2.8), Vector3(0, 1.25, 0), Color("#4a3a31"))
	_roof(root, 2.25, 1.4, Vector3(0, 2.9, 0), Color("#51221c"))
	_box(root, Vector3(0.8, 1.5, 0.25), Vector3(0, 0.9, 1.53), Color("#1b110d"))
	_flame(root, Vector3(1.25, 1.55, 1.65))

static func _army_camp(root: Node3D) -> void:
	_box(root, Vector3(5.2, 0.3, 5.2), Vector3(0, 0.15, 0), Color("#29252b"))
	for pos in [Vector3(-1.55, 0, -1.15), Vector3(1.4, 0, -1.1), Vector3(-1.1, 0, 1.45)]:
		var tent := MeshInstance3D.new()
		var tent_mesh := PrismMesh.new()
		tent_mesh.size = Vector3(1.55, 1.5, 1.9)
		tent.mesh = tent_mesh
		tent.position = pos + Vector3(0, 0.78, 0)
		tent.material_override = _material(Color("#54251f"))
		root.add_child(tent)
	_cylinder(root, 0.62, 0.18, Vector3(1.25, 0.16, 1.35), Color("#201914"), 12)
	_flame(root, Vector3(1.25, 0.48, 1.35))

static func _soul_altar(root: Node3D) -> void:
	_box(root, Vector3(3.5, 0.32, 3.5), Vector3(0, 0.16, 0), Color("#242129"))
	_cylinder(root, 1.25, 0.65, Vector3(0, 0.58, 0), Color("#40374a"), 8)
	_cylinder(root, 0.82, 1.15, Vector3(0, 1.38, 0), Color("#302a38"), 8)
	var soul := MeshInstance3D.new()
	var soul_mesh := SphereMesh.new()
	soul_mesh.radius = 0.42
	soul_mesh.height = 0.9
	soul.mesh = soul_mesh
	soul.position = Vector3(0, 2.35, 0)
	soul.material_override = _material(Color("#7965a6"), 0.2, Color("#4e2b92"))
	root.add_child(soul)
	var light := OmniLight3D.new()
	light.position = soul.position
	light.light_color = Color("#9978ef")
	light.light_energy = 2.4
	light.omni_range = 5.0
	root.add_child(light)

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

static func _laboratory(root: Node3D) -> void:
	_box(root, Vector3(3.6, 0.36, 3.6), Vector3(0, 0.18, 0), Color("#242129"))
	_cylinder(root, 1.4, 2.25, Vector3(0, 1.3, 0), Color("#34313c"), 10)
	_roof(root, 1.85, 1.1, Vector3(0, 2.8, 0), Color("#29203a"))
	for x in [-0.68, 0.68]:
		var vial := _cylinder(root, 0.26, 0.85, Vector3(x, 1.25, 1.35), Color("#5d5266"), 10)
		vial.material_override = _material(Color("#6b5b78"), 0.25, Color("#304fc4") if x < 0 else Color("#6d1a88"))

static func _spell_hall(root: Node3D) -> void:
	_box(root, Vector3(3.7, 0.35, 3.7), Vector3(0, 0.18, 0), Color("#242029"))
	for angle in range(0, 360, 60):
		var p := Vector3(cos(deg_to_rad(angle)), 0.8, sin(deg_to_rad(angle))) * 1.35
		_cylinder(root, 0.22, 1.45, p, Color("#43384f"), 6)
	_cylinder(root, 1.05, 0.65, Vector3(0, 0.58, 0), Color("#312a3a"), 12)
	var rune := _cylinder(root, 0.58, 0.08, Vector3(0, 1.02, 0), Color("#9c75df"), 16)
	rune.material_override = _material(Color("#9c75df"), 0.15, Color("#5d24b8"))

static func _builders_yard(root: Node3D) -> void:
	_box(root, Vector3(3.6, 0.3, 3.6), Vector3(0, 0.15, 0), Color("#2b2526"))
	for z in [-1.15, 1.15]:
		for x in [-1.15, 1.15]:
			_box(root, Vector3(0.22, 2.15, 0.22), Vector3(x, 1.15, z), Color("#59391f"))
	_beam(root, Vector3(-1.15, 2.15, -1.15), Vector3(1.15, 2.15, -1.15), 0.2, Color("#6d4524"))
	_beam(root, Vector3(-1.15, 2.15, 1.15), Vector3(1.15, 2.15, 1.15), 0.2, Color("#6d4524"))
	_beam(root, Vector3(-1.15, 2.15, -1.15), Vector3(-1.15, 2.15, 1.15), 0.2, Color("#6d4524"))
	_beam(root, Vector3(1.15, 2.15, -1.15), Vector3(1.15, 2.15, 1.15), 0.2, Color("#6d4524"))
	_box(root, Vector3(2.2, 0.35, 0.65), Vector3(0, 0.45, 0.7), Color("#4b3020"))

static func _wall(root: Node3D) -> void:
	_box(root, Vector3(1.8, 1.35, 1.8), Vector3(0, 0.68, 0), Color("#38343a"))
	for x in [-0.68, 0.0, 0.68]:
		_box(root, Vector3(0.42, 0.4, 0.42), Vector3(x, 1.55, 0), Color("#48434b"))
