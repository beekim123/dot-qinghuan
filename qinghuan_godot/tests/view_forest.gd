extends SceneTree
## Graphical review entry: the normal playable battle, deterministic forest seed.
func _initialize() -> void:
	call_deferred("open_forest")
func open_forest() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run.start_run(22)
	game.run.chosen=game.run.candidates[0].duplicate(true)
	game.run.chosen.biome="forest"
	game._show_battle()
	game._auto_deploy()
