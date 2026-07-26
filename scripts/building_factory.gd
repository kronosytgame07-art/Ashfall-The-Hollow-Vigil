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

static func create(kind: String) -> Node3D:
	var model_path: String = MODEL_PATHS.get(kind, "")
	assert(not model_path.is_empty(), "No GLB registered for building: " + kind)
	var packed := load(model_path) as PackedScene
	assert(packed != null, "Unable to load building GLB: " + model_path)
	var imported := packed.instantiate() as Node3D
	assert(imported != null, "Building GLB root must be Node3D: " + model_path)
	imported.name = kind.to_pascal_case()
	imported.set_meta("building_kind", kind)
	imported.set_meta("footprint", footprint(kind))
	imported.set_meta("level", 1)
	imported.set_meta("stored", 0.0)
	imported.add_to_group("buildings")
	return imported
