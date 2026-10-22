extends SceneTree
const Run = preload("res://scripts/run_state.gd")
const Sim = preload("res://scripts/battle_sim.gd")
const Data = preload("res://scripts/game_data.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: "+label)

# Reproduces main.gd's recommended deployment, not an optimal hidden formation.
func recommend(sim, run) -> void:
 var placements = [Vector2i(5,2),Vector2i(4,3),Vector2i(6,3),Vector2i(5,4),Vector2i(4,4),Vector2i(6,4)]
 var count = mini(run.team.size(),3+run.stage)
 for i in count:
  var placed = false
  for cell in placements:
   if sim.deploy(i,cell)=="": placed=true; break
  if not placed:
   for y in range(1,sim.height-1):
    for x in range(1,sim.width-1):
     if not placed and sim.deploy(i,Vector2i(x,y))=="": placed=true
  check(placed,"recommend legal member%d"%i)

func fight(run):
 var sim = Sim.new()
 sim.setup(run.battle_config())
 recommend(sim,run)
 sim.start()
 for tick in range(6000):
  sim.step(0.05)
  # Ordinary player action: use the visible lantern when several enemies threaten.
  if sim.skill_cooldown<=0 and sim.enemies.size()>=4: sim.lantern()
  if sim.finished: break
 check(sim.finished,"simulation terminates")
 return sim

func _initialize() -> void:
 var terrain_victories: int = 0
 var terrain_worst_hp: int = 18
 var starters = [{"id":"dida","level":1},{"id":"taituan","level":1},{"id":"dengxin","level":1}]
 var minimal = {"team":starters,"stage":0}
 for biome in ["grass","forest","lake","mountain","sand","snow"]:
  for seed_value in range(8):
   var arena_test = Sim.new()
   arena_test.setup({"seed":seed_value,"biome":biome,"team":starters,"heart_hp":18})
   recommend(arena_test,minimal)
   arena_test.start()
   for tick in range(6000):
    arena_test.step(0.05)
    if arena_test.finished: break
   if arena_test.victory: terrain_victories += 1
   terrain_worst_hp = mini(terrain_worst_hp,arena_test.heart_hp)
   check(arena_test.victory,"recommended no-skill formation biome%s seed%d"%[biome,seed_value])
 print("RECOMMEND_RESULT wins=",terrain_victories,"/48 worst_hp=",terrain_worst_hp)
 var final_run
 for seed_value in [1,7,22,83,144,20261022]:
  var run = Run.new()
  run.start_run(seed_value)
  check(run.planet.cells.size()==362,"new globe362")
  check(run.team.size()==3 and run.hp==18 and run.stage==0,"fresh baseline without upgrades")
  var total_time = 0.0
  var hp_lost = 0
  for encounter in range(18):
   var next = run.candidates[0]
   for node in run.candidates:
    if node.type=="boss": next=node; break
   run.chosen=next
   var before_hp: int = run.hp
   var sim = fight(run)
   total_time += sim.time
   hp_lost += maxi(0,before_hp-sim.heart_hp)
   run.resolve_battle(sim)
   if run.ended: break
   check(run.planet.cells[int(next.cell)].clear,"winner's actual region clears")
   if next.friend!="": run.recruit(str(next.friend))
   else: run.train()
   for i in run.team.size(): run.evolve(i)
   run.advance()
  print("RUN_RESULT seed=",seed_value," won=",run.won," battles=",run.wins," hour=",run.hour," hp_lost=",hp_lost," team=",run.team.size()," seconds=",snappedf(total_time,0.1))
  check(run.ended and run.won,"starter-to-victory reachable seed%d"%seed_value)
  check(run.stage==4 and run.sealed_count()==3,"three sealed springs and final stage")
  check(run.planet.clear_fraction()>0.99,"victory clears actual globe")
  check(run.meta.wins==1 and run.meta.runs==1 and run.meta.sand>=100,"win persisted rewards")
  check(run.team.size()==7 and run.meta.unlocked.size()==7,"all seven available and unlocked")
  var sand_before: int = run.meta.sand
  run.finish(true)
  check(run.meta.sand==sand_before and run.meta.runs==1,"finish idempotent")
  run.inherit(3)
  var heir: String = run.team[3].id
  check(run.meta.inherited==heir,"inherit chosen yao")
  check(run.buy_upgrade("oil"),"purchase real permanent oil upgrade")
  check(run.meta.sand==sand_before-35,"upgrade spends star-sand")
  var saved = Run.new()
  saved.load_meta()
  check(saved.meta.inherited==heir and saved.meta.oil==1 and saved.meta.unlocked.size()==7,"meta read round trip")
  saved.start_run(seed_value+1)
  check(saved.hp==20 and saved.team.size()==4,"next run includes oil and inheritance")
  check(saved.seed_value!=seed_value and saved.hour==0 and saved.wins==0,"next run fresh seeded state")
  check(saved.planet.clear_fraction()==0.0,"next globe not old cleared globe")
  for member in saved.team: check(member.level==1 and not member.evolved,"levels and evolution reset")
  final_run = run
 # True loss through the simulator, not calling finish(false) as a shortcut.
 var loss = Run.new()
 loss.start_run(332)
 loss.chosen = loss.candidates[0]
 var empty = Sim.new()
 empty.setup(loss.battle_config())
 empty.start()
 for tick in range(5000):
  empty.step(0.05)
  if empty.finished: break
 loss.resolve_battle(empty)
 check(loss.ended and not loss.won and loss.hp==0,"undefended actual battle ends run")
 check(loss.meta.runs==1 and loss.meta.wins==0 and loss.meta.sand>=12,"loss grants consolation meta")
 check(loss.planet.clear_fraction()==0.0,"loss never purifies a region")
 loss.inherit(1)
 loss.start_run(333)
 check(not loss.ended and loss.hp==18,"loss back to fresh run")
 var stage_before = loss.stage
 loss.planet.clear_region(10,3)
 loss.update_stage()
 stage_before = loss.stage
 for cell in loss.planet.cells: cell.clear=false
 loss.update_stage()
 check(loss.stage==stage_before,"stage never decreases after murk")
 var old_level = loss.planet.springs[0].level
 for i in range(4): loss.advance()
 check(loss.hour==4 and loss.planet.springs[0].level==old_level+1,"four hours strengthen springs")
 var deterministic = Run.new()
 deterministic.start_run(333)
 check(deterministic.planet.cells[0].dir==loss.planet.cells[0].dir,"geometry remains stable")
 check(not loss.buy_upgrade("bad_key"),"invalid upgrade rejected")
 print("RUN_CHECKS ",checks," FAILURES ",failures)
 quit(1 if failures>0 else 0)
