extends "res://scripts/game.gd"

# Direction visuelle finale du village. Ce script garde tout le gameplay du
# contrôleur principal et remplace uniquement la présentation du monde.

const READABLE_PALETTE := {
	"stone": Color(0.18, 0.175, 0.205),
	"stone_light": Color(0.29, 0.275, 0.31),
	"wood": Color(0.30, 0.145, 0.065),
	"wood_dark": Color(0.105, 0.052, 0.035),
	"iron": Color(0.14, 0.155, 0.18),
	"cloth": Color(0.30, 0.045, 0.075),
	"gold": Color(0.66, 0.34, 0.055),
	"bone": Color(0.58, 0.52, 0.42)
}

func _spawn_building_node(index: int) -> void:
	super._spawn_building_node(index)
	if building_nodes.has(index):
		_brighten_building(building_nodes[index])

func _brighten_building(building: Node3D) -> void:
	for child in building.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material == null:
				continue
			var key := material.resource_name.to_lower()
			if READABLE_PALETTE.has(key):
				material.albedo_color = READABLE_PALETTE[key]

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#100d16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9299aa")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("#211a29")
	env.fog_density = 0.0025
	world_environment.environment = env
	$World.add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-54, -32, 0)
	moon.light_color = Color("#d3d8e4")
	moon.light_energy = 1.35
	moon.shadow_enabled = true
	$World.add_child(moon)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32, 142, 0)
	fill.light_color = Color("#76566f")
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	$World.add_child(fill)

	var outer_ground := MeshInstance3D.new()
	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(78, 78)
	outer_ground.mesh = outer_plane
	outer_ground.material_override = _outer_terrain_material()
	$World.add_child(outer_ground)

	var village_ground := MeshInstance3D.new()
	var village_plane := PlaneMesh.new()
	village_plane.size = Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE)
	village_ground.mesh = village_plane
	village_ground.position.y = 0.015
	village_ground.material_override = _terrain_material()
	$World.add_child(village_ground)
	_add_ground_collision()

	var mountain_scene := load("res://models/environment/mountain_ring.glb") as PackedScene
	if mountain_scene:
		var mountains := mountain_scene.instantiate()
		_apply_mountain_material(mountains)
		$World.add_child(mountains)

	grid_root = _new_root("Grid")
	buildings_root = _new_root("Buildings")
	obstacles_root = _new_root("Obstacles")
	villagers_root = _new_root("Villagers")
	troops_root = _new_root("Troops")

func _apply_mountain_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh:
			for surface in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(surface)
				var material_name := source.resource_name.to_lower() if source else ""
				var material := StandardMaterial3D.new()
				material.roughness = 1.0
				if "soul" in material_name:
					material.albedo_color = Color("#5424a6")
					material.emission_enabled = true
					material.emission = Color("#5c22c4")
					material.emission_energy_multiplier = 2.4
				elif "wood" in material_name:
					material.albedo_color = Color("#160d0c")
				else:
					material.albedo_color = Color("#27242d")
				mesh.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_mountain_material(child)

func _build_grid() -> void:
	var line_mat := _material(Color(0.42, 0.35, 0.39, 0.075))
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(GRID_SIZE + 1):
		var offset := -BUILDABLE_HALF + i * TILE_SIZE
		_add_box(grid_root, Vector3(0, 0.012, offset), Vector3(GRID_SIZE * TILE_SIZE, 0.012, 0.022), line_mat)
		_add_box(grid_root, Vector3(offset, 0.012, 0), Vector3(0.022, 0.012, GRID_SIZE * TILE_SIZE), line_mat)

func _add_footprint_base(building: Node3D, fp: Vector2i) -> void:
	var base := _add_box(
		building,
		Vector3(0, 0.016, 0),
		Vector3(fp.x * TILE_SIZE * 0.82, 0.024, fp.y * TILE_SIZE * 0.82),
		_material(Color("#29252b"))
	)
	building.move_child(base, 0)

func _spawn_obstacle(cell: Vector2i) -> void:
	occupied[cell] = "obstacle"
	var root := Node3D.new()
	root.position = _cell_center(cell, Vector2i.ONE)
	obstacles_root.add_child(root)
	var kinds := ["corrupted_rocks", "dead_tree", "bones", "soul_crystals"]
	var scene := load("res://models/obstacles/%s.glb" % kinds[posmod(cell.x + cell.y, kinds.size())]) as PackedScene
	if scene:
		root.add_child(scene.instantiate())
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE * 0.92, 1.8, TILE_SIZE * 0.92)
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	root.add_child(body)

func _add_village_atmosphere() -> void:
	var patches := _new_root("AshAndEarthPatches")
	for i in range(18):
		var angle := float(i) * 2.399
		var radius := 6.0 + float((i * 7) % 16)
		var patch := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.38 + float(i % 4) * 0.19
		disc.bottom_radius = disc.top_radius * 1.16
		disc.height = 0.012
		disc.radial_segments = 12
		patch.mesh = disc
		patch.position = Vector3(cos(angle) * radius, 0.018, sin(angle) * radius)
		patch.scale.z = 0.55 + float(i % 3) * 0.13
		patch.rotation.y = angle
		patch.material_override = _material(Color("#44382f") if i % 4 == 0 else Color("#242127"))
		patches.add_child(patch)

	for index in building_nodes:
		var kind := str(state.buildings[int(index)].kind)
		if kind != "town_hall" and kind != "army_camp" and kind != "forge":
			continue
		var light := OmniLight3D.new()
		light.name = kind.to_pascal_case() + "WarmLight"
		light.position = building_nodes[index].global_position + Vector3(0, 2.0 if kind == "town_hall" else 1.15, 0)
		light.light_color = Color("#ff873c")
		light.light_energy = 2.5 if kind == "town_hall" else 1.7
		light.omni_range = 7.0 if kind == "town_hall" else 4.5
		light.shadow_enabled = true
		$World.add_child(light)
