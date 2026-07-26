extends SceneTree

const REQUIRED_BUILDINGS := [
	"town_hall", "gold_mine", "sawmill", "barracks", "army_camp",
	"soul_altar", "forge", "tower", "laboratory", "spell_hall",
	"builders_yard", "wall"
]

func _initialize() -> void:
	for kind in REQUIRED_BUILDINGS:
		var fp := BuildingFactory.footprint(kind)
		assert(fp.x > 0 and fp.y > 0, "Invalid footprint: " + kind)
	for sector in range(8):
		var angle := sector * TAU / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		assert(is_equal_approx(direction.length(), 1.0), "Invalid direction sector")
	print("Ashfall 3D validation: 12 buildings, 8 movement sectors, OK")
	quit()
