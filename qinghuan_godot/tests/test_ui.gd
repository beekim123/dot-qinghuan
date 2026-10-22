extends SceneTree
var checks=0
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		push_error(message)
		quit(1)
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.run.meta={"sand":0,"oil":0,"dew":0,"bond":0,"unlocked":["dida","taituan","dengxin"],"inherited":"","runs":0,"wins":0}
	check(scene.mode=="yard","yard boot")
	scene._start_run()
	check(scene.mode=="map","new run map")
	check(scene.run.team.size()==3,"starter team")
	scene._select_node(0)
	for i in 100: scene.globe._process(0.016)
	scene._enter_selected()
	check(scene.mode=="battle","enter battle")
	scene._auto_deploy()
	check(scene.sim.units.size()==3,"auto deploy")
	scene._toggle_pause()
	check(scene.sim.running,"start combat")
	scene._toggle_pause()
	check(scene.paused,"pause combat")
	scene._toggle_pause()
	check(not scene.paused,"resume combat")
	for i in 12000:
		if scene.sim.finished: break
		scene.sim.step(1.0/30)
	check(scene.sim.finished,"real result terminal")
	check(scene.sim.victory,"starter first victory")
	scene._battle_finished()
	check(scene.mode=="reward","reward UI")
	check(scene.run.planet.clear_fraction()>0,"map clearing")
	scene._reward("friend",scene.run.chosen.friend)
	check(scene.mode=="map" and scene.run.hour==1,"reward map advance once")
	check(scene.run.team.size()==4,"bond friend")
	var rest_index=-1
	for i in scene.run.candidates.size():
		if scene.run.candidates[i].type=="rest": rest_index=i
	check(rest_index>=0,"rest offered")
	scene._select_node(rest_index)
	for i in 100: scene.globe._process(0.016)
	scene._enter_selected()
	check(scene.mode=="service","rest service")
	scene._rest("train",-1)
	check(scene.mode=="map" and scene.run.hour==2,"rest advances once")
	var shop_index=-1
	for i in scene.run.candidates.size():
		if scene.run.candidates[i].type=="shop": shop_index=i
	check(shop_index>=0,"shop offered")
	scene._select_node(shop_index)
	for i in 100: scene.globe._process(0.016)
	scene._enter_selected()
	check(scene.mode=="service","shop service")
	var before=scene.run.dew
	scene._shop("train",8,0)
	check(scene.run.dew==before-8,"shop one debit")
	scene._leave_service()
	check(scene.mode=="map" and scene.run.hour==3,"shop leaving advances")
	scene.run.finish(false)
	scene._show_ending()
	check(scene.mode=="ending","ending displayed")
	scene._inherit(0)
	check(scene.mode=="yard","inherit returns yard")
	scene._start_run()
	check(scene.mode=="map" and scene.run.hour==0,"repeat new run")
	print("UI_PASS ",checks," checks")
	scene.queue_free()
	await process_frame
	quit(0)
