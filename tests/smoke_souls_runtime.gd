extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if not _require(packed != null, "Main scene failed to load"):
		return
	var game := packed.instantiate()
	get_root().add_child(game)
	for frame in range(8):
		await process_frame

	if not _require(game.world_ready, "Staged world boot did not complete"):
		return
	if not _require(is_instance_valid(game.play_button) and not game.play_button.disabled, "Play button was not unlocked"):
		return
	if not _require(is_instance_valid(game.player), "Runtime did not create a player"):
		return
	if not _require(is_instance_valid(game.follow_camera), "Runtime did not create the world camera"):
		return
	if not _require(
		get_root().get_viewport().get_camera_3d() == game.follow_camera,
		"World follow camera is not the active viewport camera"
	):
		return
	var cameras := game.find_children("*", "Camera3D", true, false)
	if not _require(cameras.size() == 1, "Runtime must contain exactly one Camera3D"):
		return
	if not _require(
		game.find_child("ContinuousWorldFloor", true, false) != null,
		"Continuous collision floor is missing"
	):
		return
	if not _require(
		game.find_child("VisibleFallbackGround", true, false) != null,
		"Web fallback ground is missing"
	):
		return
	var meshes := game.find_children("*", "MeshInstance3D", true, false)
	if not _require(meshes.size() >= 80, "World geometry count is unexpectedly low: %d" % meshes.size()):
		return
	var target: Vector3 = game.player.global_position + Vector3(0, 1.15, 0)
	var camera_forward: Vector3 = -game.follow_camera.global_basis.z.normalized()
	var target_direction: Vector3 = game.follow_camera.global_position.direction_to(target)
	if not _require(
		camera_forward.dot(target_direction) > 0.995,
		"Camera is not looking at the player: dot=%f" % camera_forward.dot(target_direction)
	):
		return
	if not _require(
		game.follow_camera.is_position_in_frustum(target),
		"Player target is outside the active camera frustum"
	):
		return

	game.game_started = true
	game.player.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.invulnerable_clock = 30.0
	for frame in range(120):
		await physics_frame
	if not _require(game.player.global_position.y > -0.2, "Player fell below the world"):
		return
	if not _require(game.player.is_on_floor(), "Player did not settle on the continuous world floor"):
		return
	if not _require(not game.player.is_dead, "Player died during idle runtime smoke test"):
		return
	if not _require(game.player.health == game.player.MAX_HEALTH, "Player lost health while idle"):
		return
	if not _require(
		is_instance_valid(game.player.left_arm_pivot)
		and is_instance_valid(game.player.left_leg_pivot)
		and is_instance_valid(game.player.right_leg_pivot),
		"Player articulated limb pivots are missing"
	):
		return
	if not _require(
		game.player.weapon_model.get_parent() == game.player.weapon_grip,
		"Equipped weapon is not anchored to the right hand grip"
	):
		return
	var first_enemy := game.get_tree().get_first_node_in_group("enemy") as AshfallSoulsEnemy
	if not _require(
		is_instance_valid(first_enemy)
		and is_instance_valid(first_enemy.left_arm_pivot)
		and is_instance_valid(first_enemy.left_leg_pivot)
		and first_enemy.weapon_grip.get_parent() == first_enemy.arm_pivot,
		"Enemy articulated combat rig is incomplete"
	):
		return
	var errant: AshfallSoulsEnemy
	var hollow_raider: AshfallSoulsEnemy
	for enemy_node in game.get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as AshfallSoulsEnemy
		if enemy.enemy_name == "Errant":
			errant = enemy
		elif enemy.enemy_name == "Pillard creux":
			hollow_raider = enemy
	if not _require(
		is_instance_valid(errant)
		and errant.find_child("ErrantHood", true, false) != null
		and errant.find_child("ErrantLanternLight", true, false) != null
		and errant.find_child("ErrantStaff", true, false) != null
		and errant.find_child("EnemySwordBlade", true, false) == null,
		"Errant concept silhouette is incomplete"
	):
		return
	if not _require(
		is_instance_valid(hollow_raider)
		and hollow_raider.find_child("HollowRaiderSkullMask", true, false) != null
		and hollow_raider.find_child("HollowRaiderPack", true, false) != null
		and hollow_raider.find_child("HollowRaiderScytheBlade", true, false) != null
		and hollow_raider.find_child("EnemySwordBlade", true, false) == null,
		"Hollow Raider concept silhouette is incomplete"
	):
		return
	var grounded_y: float = game.player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for frame in range(8):
		await physics_frame
	if not _require(game.player.global_position.y > grounded_y + 0.25, "Space jump did not lift the player"):
		return
	var loot_test := [{
		"name": "Casque du test",
		"slot": "helmet",
		"power": 99,
		"color": Color("#8c929b"),
	}]
	game.player.equip_loot(loot_test)
	if not _require(
		"Casque du test" in game.player.equipment_summary(),
		"Loot equipment was not applied to the player"
	):
		return
	print(
		"Ashfall runtime smoke: player=%s camera=%s meshes=%d health=%.1f OK"
		% [game.player.global_position, game.follow_camera.global_position, meshes.size(), game.player.health]
	)
	game.queue_free()
	await process_frame
	quit()

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
