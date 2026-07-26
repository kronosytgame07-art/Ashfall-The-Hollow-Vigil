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

static func footprint(kind: String) -> Vector2i:
	return FOOTPRINTS.get(kind, Vector2i.ONE)

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
	return imported
