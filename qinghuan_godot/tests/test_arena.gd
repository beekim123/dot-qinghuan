extends SceneTree
var arena: ArenaView
var vp: SubViewport
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var battle := BattleSim.new()
	battle.setup({"seed":27,"biome":OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "forest","team":[{"id":"dida","level":1},{"id":"taituan","level":1},{"id":"dengxin","level":1}],"heart_hp":20,"dew":12,"stage":0,"spring_level":1,"boss":""})
	vp=SubViewport.new()
	vp.size=Vector2i(480,270)
	vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	arena=ArenaView.new()
	vp.add_child(arena)
	arena.setup(battle)
	for c in [Vector2i(4,3),Vector2i(5,2),Vector2i(6,3)]:
		battle.deploy([Vector2i(4,3),Vector2i(5,2),Vector2i(6,3)].find(c),c)
	arena.refresh(0.0)
	await process_frame
	for y in range(battle.height):
		for x in range(battle.width):
			var c := Vector2i(x,y)
			var p := arena.camera.unproject_position(arena._world(Vector2(c),arena._height(c)+0.055))
			assert(arena.screen_to_cell(p)==c,"Tile center picking failed %s"%c)
	battle.start()
	for i in range(300):
		battle.step(0.05)
		arena.refresh(0.05)
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("/tmp/qinghuan-arena-test.png")
	print("ARENA_PASS: 77 projected tile centers pick correctly; deployment and 15 seconds battle visualization update without error")
	vp.queue_free()
	await process_frame
	await process_frame
	quit()
