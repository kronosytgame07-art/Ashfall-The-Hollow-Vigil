class_name BuildingFactory
extends RefCounted

static var _shared_surface_shader: Shader

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
	"darkwood": Color(0.065, 0.032, 0.022),
	"iron": Color(0.085, 0.095, 0.11),
	"cloth": Color(0.17, 0.025, 0.045),
	"roof": Color(0.16, 0.045, 0.028),
	"gold": Color(0.52, 0.23, 0.035),
	"ember": Color(1.0, 0.065, 0.003),
	"soul": Color(0.28, 0.025, 0.65),
	"bone": Color(0.46, 0.41, 0.33),
	"earth": Color(0.105, 0.085, 0.095),
	"moss": Color(0.12, 0.19, 0.11),
	"crystal": Color(0.31, 0.07, 0.62)
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
			if material_name == "cloth":
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
			mesh_instance.set_surface_override_material(
				surface,
				make_textured_material(material_name, ART_PALETTE[material_name])
			)

	# Les anciennes fondations formaient de gros colliers de pierres blanches.
	# On les conserve comme ancrage au sol, mais elles deviennent discrètes.
	for foundation in building.find_children("FoundationStone_*", "Node3D", true, false):
		var stone := foundation as Node3D
		if stone:
			stone.scale *= Vector3(0.88, 0.42, 0.88)
			stone.position.y *= 0.58

static func make_textured_material(material_name: String, color: Color) -> ShaderMaterial:
	if _shared_surface_shader == null:
		_shared_surface_shader = Shader.new()
		_shared_surface_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color;
uniform vec3 glow_color = vec3(0.0);
uniform float texture_scale = 1.0;
uniform float detail_strength = 0.28;
uniform float roughness_amount = 0.86;
uniform float metallic_amount = 0.0;
uniform int pattern = 0;

varying vec3 world_position;
varying vec3 object_position;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(cell);
	float n100 = hash3(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(cell + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

void vertex() {
	object_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_position * texture_scale;
	float broad = value_noise(p * 0.55);
	float fine = value_noise(p * 3.7);
	float texture_value = broad * 0.68 + fine * 0.32;

	if (pattern == 1) {
		// Veines longues et nœuds pour les surfaces en bois.
		float grain = sin((object_position.y * 7.0 + broad * 2.8) * 3.2);
		float rings = sin((length(object_position.xz) + fine * 0.18) * 16.0);
		texture_value = grain * 0.32 + rings * 0.12 + broad * 0.56;
		texture_value = texture_value * 0.5 + 0.5;
	} else if (pattern == 2) {
		// Pierre poreuse, tachetée et légèrement veinée.
		float pores = smoothstep(0.72, 0.92, fine);
		float veins = 1.0 - smoothstep(0.02, 0.15, abs(sin((p.x + p.z) * 1.7 + broad * 5.0)));
		texture_value = broad * 0.72 + fine * 0.2 - pores * 0.18 + veins * 0.1;
	} else if (pattern == 3) {
		// Métal martelé avec de fines rayures verticales.
		float scratches = pow(abs(sin((object_position.y + fine * 0.08) * 58.0)), 18.0);
		texture_value = broad * 0.72 + fine * 0.2 + scratches * 0.18;
	} else if (pattern == 4) {
		// Cendre, terre brûlée et petites zones charbonneuses.
		float ash = value_noise(p * 7.5);
		texture_value = broad * 0.58 + fine * 0.24 + ash * 0.18;
	} else if (pattern == 5) {
		// Tuiles et tissus usés : variation fine, bords plus sombres.
		texture_value = broad * 0.5 + fine * 0.5;
	}

	float shade = clamp(0.72 + texture_value * detail_strength * 1.55, 0.54, 1.22);
	ALBEDO = base_color.rgb * shade;
	ROUGHNESS = clamp(roughness_amount + (fine - 0.5) * 0.16, 0.28, 1.0);
	METALLIC = metallic_amount;
	EMISSION = glow_color * (0.72 + fine * 0.55);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _shared_surface_shader
	var readable_color := color.lightened(0.16)
	material.set_shader_parameter("base_color", readable_color)
	material.set_shader_parameter("texture_scale", _texture_scale_for(material_name))
	material.set_shader_parameter("detail_strength", 0.42 if material_name in ["stone", "stone2", "basalt", "earth"] else 0.34)
	material.set_shader_parameter("roughness_amount", 0.48 if material_name == "iron" else 0.43 if material_name == "gold" else 0.9)
	material.set_shader_parameter("metallic_amount", 0.74 if material_name == "iron" else 0.4 if material_name == "gold" else 0.0)
	material.set_shader_parameter("pattern", _texture_pattern_for(material_name))
	if material_name == "ember":
		material.set_shader_parameter("glow_color", Vector3(1.0, 0.035, 0.002) * 4.2)
	elif material_name in ["soul", "crystal"]:
		material.set_shader_parameter("glow_color", Vector3(0.25, 0.025, 0.68) * 3.0)
	return material

static func _texture_pattern_for(material_name: String) -> int:
	if material_name in ["wood", "darkwood"]:
		return 1
	if material_name in ["stone", "stone2", "stone_light", "basalt", "moss", "bone"]:
		return 2
	if material_name in ["iron", "gold"]:
		return 3
	if material_name in ["earth"]:
		return 4
	if material_name in ["roof", "cloth"]:
		return 5
	return 0

static func _texture_scale_for(material_name: String) -> float:
	if material_name in ["wood", "darkwood"]:
		return 1.35
	if material_name in ["stone", "stone2", "stone_light", "basalt"]:
		return 0.92
	if material_name in ["iron", "gold"]:
		return 1.8
	if material_name in ["earth", "moss"]:
		return 0.7
	return 1.15

static func apply_level_visual(building: Node3D, level: int) -> void:
	building.set_meta("level", level)
	for upgrade_level in range(2, 11):
		var group := building.find_child("UpgradeLevel%d" % upgrade_level, true, false) as Node3D
		if group:
			group.visible = upgrade_level <= level
	var growth := 1.0 + minf(0.09, maxi(0, level - 1) * 0.01)
	building.scale = Vector3(growth, 1.0 + minf(0.13, maxi(0, level - 1) * 0.014), growth)
