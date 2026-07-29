extends SceneTree

const REQUIRED_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"sprint", "dodge", "jump", "attack", "interact",
]
const ACTIVE_SCRIPTS := [
	"res://scripts/souls_world.gd",
	"res://scripts/souls_player.gd",
	"res://scripts/souls_enemy.gd",
]

func _initialize() -> void:
	for script_path in ACTIVE_SCRIPTS:
		if not ResourceLoader.exists(script_path):
			_fail("Missing active controller: " + script_path)
			return
		var script := load(script_path) as Script
		if script == null or not script.can_instantiate():
			_fail("Active controller cannot instantiate: " + script_path)
			return
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			_fail("Remappable action is missing: " + action)
			return
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		_fail("The action-RPG main scene cannot load")
		return
	var instance := main_scene.instantiate()
	if instance.get_script().resource_path != "res://scripts/souls_world.gd":
		instance.free()
		_fail("The main scene does not launch the Souls-like world")
		return
	instance.free()
	print("Ashfall static validation: active scene, controllers and inputs OK")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
