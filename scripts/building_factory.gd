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

const MODEL_PATHS := {
	"town_hall": "res://models/buildings/town_hall.glb",
	"gold_mine": "res://models/buildings/gold_mine.glb",
	"sawmill": "res://models/buildings/sawmill.glb",
	"barracks": "res://models/buildings/barracks.glb",
	"army_camp": "res://models/buildings/army_camp.glb",
	"soul_altar": "res://models/buildings/soul_altar.glb",
	"forge": "res://models/buildings/forge.glb",
	"tower": "res://models/buildings/tower.glb",
	"laboratory": "res://models/buildings/laboratory.glb",
	"spell_hall": "res://models/buildings/spell_hall.glb",
	"builders_yard": "res://models/buildings/builders_yard.glb",
	"wall": "res://models/buildings/wall.glb"
}

const ART_PALETTE := {
	"basalt": Color(0.075, 0.07, 0.085),
	"stone": Color(0.105, 0.10, 0.12),
	"stone2": Color(0.16, 0.15, 0.17),
	"stone_light": Color(0.19, 0.18, 0.20),
	"wood": Color(0.19, 0.085, 0.038),
	"wood_dark": Color(0.055, 0.027, 0.02),
	"iron": Color(0.085, 0.095, 0.11),
	"cloth": Color(0.17, 0.025, 0.045),
	"roof": Color(0.16, 0.045, 0.028),
	"gold": Color(0.52, 0.23, 0.035),
	"ember": Color(1.0, 0.065, 0.003),
	"soul": Color(0.28, 0.025, 0.65),
	"bone": Color(0.46, 0.41, 0.33)
}

const DEFINITIONS := {
	"town_hall": {"label": "Hôtel de ville", "cost": {"wood": 0, "gold": 0}, "build_time": 0, "max_level": 10},
	"gold_mine": {"label": "Mine d'or", "cost": {"wood": 180, "gold": 80}, "build_time": 12, "max_level": 10, "produces": "gold", "rate": 18, "capacity": 360},
	"sawmill": {"label": "Scierie", "cost": {"wood": 80, "gold": 160}, "build_time": 12, "max_level": 10, "produces": "wood", "rate": 18, "capacity": 360},
	"barracks": {"label": "Caserne", "cost": {"wood": 240, "gold": 180}, "build_time": 18, "max_level": 8},
	"army_camp": {"label": "Camp militaire", "cost": {"wood": 260, "gold": 220}, "build_time": 20, "max_level": 8},
	"soul_altar": {"label": "Autel des âmes", "cost": {"wood": 220, "gold": 320}, "build_time": 24, "max_level": 8, "produces": "souls", "rate": 5, "capacity": 100},
	"forge": {"label": "Forge", "cost": {"wood": 300, "gold": 380}, "build_time": 28, "max_level": 8},
	"tower": {"label": "Tour de défense", "cost": {"wood": 260, "gold": 420}, "build_time": 26, "max_level": 10},
	"laboratory": {"label": "Laboratoire", "cost": {"wood": 440, "gold": 520}, "build_time": 36, "max_level": 8},
	"spell_hall": {"label": "Sanctuaire des sorts", "cost": {"wood": 460, "gold": 560, "souls": 40}, "build_time": 40, "max_level": 8},
	"builders_yard": {"label": "Chantier", "cost": {"wood": 320, "gold": 280}, "build_time": 20, "max_level": 5},
	"wall": {"label": "Mur", "cost": {"wood": 35, "gold": 20}, "build_time": 3, "max_level": 10}
}

static func footprint(kind: String) -> Vector2i:
	return FOOTPRINTS.get(kind, Vector2i.ONE)

static func definition(kind: String) -> Dictionary:
	return DEFINITIONS.get(kind, {}).duplicate(true)

static func label(kind: String) -> String:
	return definition(kind).get("label", kind.replace("_", " ").capitalize())

static func cost(kind: String, level := 1) -> Dictionary:
	var base: Dictionary = definition(kind).get("cost", {})
	var multiplier := pow(1.65, maxi(0, level - 1))
	var result := {}
	for resource in base:
		result[resource] = ceili(float(base[resource]) * multiplier)
	return result

static func build_time(kind: String, level := 1) -> int:
	return ceili(float(definition(kind).get("build_time", 5)) * pow(1.45, maxi(0, level - 1)))

static func create(kind: String, level := 1) -> Node3D:
	var model_path: String = MODEL_PATHS.get(kind, "")
	assert(not model_path.is_empty(), "No GLB registered for building: " + kind)
	var packed := load(model_path) as PackedScene
	assert(packed != null, "Unable to load building GLB: " + model_path)
	var imported := packed.instantiate() as Node3D
	assert(imported != null, "Building GLB root must be Node3D: " + model_path)
	imported.name = kind.to_pascal_case()
	imported.set_meta("building_kind", kind)
	imported.set_meta("footprint", footprint(kind))
	imported.set_meta("level", level)
	imported.set_meta("stored", 0.0)
	imported.add_to_group("buildings")
	apply_art_direction(imported)
	apply_level_visual(imported, level)
	return imported

static func apply_art_direction(building: Node3D) -> void:
	# Une palette partagée lie visuellement tous les bâtiments, tout en laissant
	# les silhouettes et accessoires fonctionnels propres à chaque modèle.
	for child in building.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var material_name := source.resource_name.to_lower()
			if not ART_PALETTE.has(material_name):
				continue
			var material := source.duplicate() as StandardMaterial3D
			if material == null:
				continue
			material.albedo_color = ART_PALETTE[material_name]
			material.roughness = 0.48 if material_name == "iron" else 0.42 if material_name == "gold" else 0.86
			material.metallic = 0.72 if material_name == "iron" else 0.38 if material_name == "gold" else 0.0
			if material_name == "ember":
				material.emission_enabled = true
				material.emission = Color(1.0, 0.035, 0.002)
				material.emission_energy_multiplier = 4.5
			elif material_name == "soul":
				material.emission_enabled = true
				material.emission = Color(0.22, 0.015, 0.58)
				material.emission_energy_multiplier = 3.5
			elif material_name == "cloth":
				var cloth_shader := Shader.new()
				cloth_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(0.30, 0.045, 0.075, 1.0);
void vertex() {
	float anchored = smoothstep(0.0, 0.7, abs(VERTEX.x));
	float gust = sin(TIME * 2.2 + VERTEX.y * 3.6 + VERTEX.x * 2.1);
	float flutter = sin(TIME * 5.1 + VERTEX.y * 7.0) * 0.35;
	VERTEX.z += (gust + flutter) * 0.055 * anchored;
}
void fragment() {
	ALBEDO = cloth_color.rgb;
	ROUGHNESS = 0.86;
}
"""
				var animated_cloth := ShaderMaterial.new()
				animated_cloth.shader = cloth_shader
				animated_cloth.set_shader_parameter("cloth_color", Color(0.30, 0.045, 0.075, 1.0))
				mesh_instance.set_surface_override_material(surface, animated_cloth)
				continue
			mesh_instance.set_surface_override_material(surface, material)

	# Les anciennes fondations formaient de gros colliers de pierres blanches.
	# On les conserve comme ancrage au sol, mais elles deviennent discrètes.
	for foundation in building.find_children("FoundationStone_*", "Node3D", true, false):
		var stone := foundation as Node3D
		if stone:
			stone.scale *= Vector3(0.88, 0.42, 0.88)
			stone.position.y *= 0.58

static func apply_level_visual(building: Node3D, level: int) -> void:
	building.set_meta("level", level)
	for upgrade_level in range(2, 11):
		var group := building.find_child("UpgradeLevel%d" % upgrade_level, true, false) as Node3D
		if group:
			group.visible = upgrade_level <= level
	var growth := 1.0 + minf(0.09, maxi(0, level - 1) * 0.01)
	building.scale = Vector3(growth, 1.0 + minf(0.13, maxi(0, level - 1) * 0.014), growth)
