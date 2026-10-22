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
  var changed_terrain = 0
  for i in run.planet.cells.size():
   if saved.planet.cells[i].biome != run.planet.cells[i].biome: changed_terrain += 1
  check(changed_terrain>10,"new seed materially changes terrain")
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
 var nursery = Run.new()
 nursery.start_run(444)
 check(not nursery.evolve(0),"level1 evolution rejected")
 nursery.train(0)
 check(nursery.team[0].level==2 and nursery.team[1].level==1,"individual shop training scope")
 nursery.train()
 check(nursery.team[0].level==3 and nursery.team[1].level==2,"rest whole-team training scope")
 check(nursery.evolve(0) and nursery.team[0].evolved,"actual level3 evolution")
 check(not nursery.evolve(0),"duplicate evolution rejected")
 var prior_count = nursery.team.size()
 nursery.recruit("chayan"); nursery.recruit("chayan")
 check(nursery.team.size()==prior_count+1,"bonding unique species")
 check(not nursery.buy_upgrade("oil"),"cannot buy upgrade without sand")
 var matching = Run.new()
 matching.meta.inherited="dida"
 matching.start_run(90)
 check(matching.team.size()==3 and matching.team[0].level==2,"matching heir grants level2 starter")
 check(matching.team[1].level==1 and matching.team[2].level==1,"matching heir buffs only chosen species")
 var different = Run.new()
 different.meta.inherited="piaopiao"
 different.start_run(90)
 check(different.team.size()==4 and different.team[3].id=="piaopiao" and different.team[3].level==1,"distinct heir adds level1 fourth companion")
 var poor = Sim.new()
 poor.setup({"seed":7,"team":starters,"heart_hp":18,"biome":"grass"})
 var poor_spots = [Vector2i(1,5),Vector2i(1,4),Vector2i(2,5)]
 for i in range(3): check(poor.deploy(i,poor_spots[i])=="","poor formation legal")
 poor.start()
 for tick in range(6000):
  poor.step(0.05)
  if poor.finished: break
 var sleepers = 0
 for unit in poor.units:
  if unit.hp<=0: sleepers+=1
 print("POSITION_RESULT poor_won=",poor.victory," heart=",poor.heart_hp," sleepers=",sleepers," time=",poor.time)
 check(poor.heart_hp<terrain_worst_hp,"three-unit positions materially change heart outcome")
 check(poor.finished,"poor formation actual terminal outcome")
 # A lonely blocker beside the center should genuinely exhaust and release its targets.
 var weary = Sim.new()
 weary.setup({"seed":7,"team":starters,"heart_hp":30})
 check(weary.deploy(1,Vector2i(5,2))=="","sleep test legal blocker")
 weary.start()
 var saw_sleep = false
 for tick in range(6000):
  weary.step(0.05)
  if weary.units[0].hp<=0: saw_sleep=true
  if weary.finished: break
 print("SLEEP_RESULT observed=",saw_sleep," hp=",weary.units[0].hp," heart=",weary.heart_hp)
 check(saw_sleep and weary.units[0].state=="sleep","real erosion produces sleeping companion")
 var boss_pressure = Sim.new()
 boss_pressure.setup({"seed":7,"team":starters,"heart_hp":100,"boss":"mianmian"})
 boss_pressure.start()
 var witnessed_boss = false
 var boss_at_heart = false
 for tick in range(14000):
  boss_pressure.step(0.05)
  for enemy in boss_pressure.enemies:
   if enemy.id=="mianmian":
    witnessed_boss=true
    if enemy.pos.distance_to(Vector2(boss_pressure.heart))<0.15: boss_at_heart=true
  if boss_pressure.finished: break
 check(witnessed_boss and boss_at_heart,"boss actually spawns and advances dynamically to heart")
 check(boss_pressure.finished and not boss_pressure.victory and boss_pressure.heart_hp==0,"uncleansed boss never awards timed victory")
 print("BOSS_PRESSURE_RESULT witnessed=",witnessed_boss," reached_heart=",boss_at_heart," victory=",boss_pressure.victory," seconds=",boss_pressure.time)
 print("RUN_CHECKS ",checks," FAILURES ",failures)
 quit(1 if failures>0 else 0)
