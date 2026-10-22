extends SceneTree
const Sim = preload("res://scripts/battle_sim.gd")
const Data = preload("res://scripts/game_data.gd")
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  push_error("FAIL: " + message)
  failures += 1

func _initialize() -> void:
 var starters = [{"id":"dida","level":1},{"id":"taituan","level":1},{"id":"dengxin","level":1}]
 for biome in ["grass","forest","lake","mountain","sand","snow"]:
  for seed_value in range(8):
   var sim = Sim.new()
   sim.setup({"seed":seed_value,"biome":biome,"team":starters})
   check(sim.tiles.size() == 77,"terrain dimensions")
   for path in sim.paths(): check(path.size() >= 2,"initial entrance connectivity")
   check(sim.can_deploy(0,sim.heart) != "","reject heart")
   check(sim.can_deploy(0,Vector2i(-1,0)) != "","reject outside")
 var sim = Sim.new()
 sim.setup({"seed":7,"team":starters,"heart_hp":12})
 check(sim.deploy(0,Vector2i(4,3)) == "","deploy dida")
 check(sim.deploy(1,Vector2i(5,2)) == "","deploy taituan")
 check(sim.deploy(2,Vector2i(6,3)) == "","deploy dengxin")
 sim.start()
 for i in range(5000):
  sim.step(0.05)
  if sim.finished: break
 check(sim.finished,"battle terminates")
 print("STARTER_RESULT victory=",sim.victory," heart=",sim.heart_hp," time=",sim.time," dew=",sim.dew)
 check(sim.victory,"baseline formation viable")
 var empty = Sim.new()
 empty.setup({"seed":7,"team":starters,"heart_hp":4})
 empty.start()
 for i in range(3000):
  empty.step(0.05)
  if empty.finished: break
 check(empty.finished and not empty.victory and empty.heart_hp == 0,"real failure without defense")
 var block = Sim.new()
 var all_team = []
 for id in Data.IDS: all_team.append({"id":id,"level":4,"evolved":true})
 block.setup({"seed":1,"team":all_team,"stage":4,"dew":30})
 for i in range(3): check(block.deploy(i,[Vector2i(4,3),Vector2i(5,2),Vector2i(6,3)][i]) == "","surround 3 sides")
 var before = block.dew
 check(block.deploy(3,Vector2i(5,4)).contains("封死"),"full blockade rejected")
 check(block.dew == before,"reject does not debit")
 check(block.remove(Vector2i(4,3)) == "","remove valid")
 check(block.deploy(3,Vector2i(5,4)) == "","new route after remove")
 for boss_id in ["spring", "mianmian"]:
  var boss_sim = Sim.new()
  boss_sim.setup({"seed":11,"team":all_team,"stage":3,"spring_level":2,"heart_hp":18,"boss":boss_id,"dew":12})
  var spots = [Vector2i(4,2),Vector2i(5,2),Vector2i(6,2),Vector2i(4,4),Vector2i(6,4),Vector2i(5,4),Vector2i(3,3)]
  for i in range(6):
   check(boss_sim.deploy(i,spots[i]) == "","boss deployment")
  boss_sim.start()
  check(boss_sim.deploy(6,spots[6]) == "","dew reinforcement")
  for i in range(6000):
   boss_sim.step(0.05)
   if boss_sim.skill_cooldown <= 0.0 and boss_sim.enemies.size() > 3: boss_sim.lantern()
   if boss_sim.finished: break
  print("BOSS_RESULT ",boss_id," victory=",boss_sim.victory," heart=",boss_sim.heart_hp," time=",boss_sim.time)
  check(boss_sim.finished and boss_sim.victory,"boss wash completion")
 var roles = Sim.new()
 roles.setup({"seed":3,"team":all_team,"stage":4,"dew":20})
 check(roles.deploy(6,Vector2i(3,4)) == "","producer dew tile")
 check(roles.deploy(5,Vector2i(4,4)) == "","healer deployment")
 check(roles.deploy(1,Vector2i(4,3)) == "","healing target")
 roles.units[2].hp = 5.0
 roles.start()
 for i in range(90): roles.step(0.05)
 check(roles.units[2].hp > 5.0,"yaya healing actually works")
 check(roles.dew > 20,"piaopiao produces on dew tile")
 var pre_dew = roles.dew
 check(roles.lantern() == "","lantern valid")
 check(roles.dew == pre_dew-6,"lantern debits")
 check(roles.lantern() != "","lantern cooldown rejects")
 var wake = Sim.new()
 wake.setup({"seed":7,"team":all_team,"stage":4,"dew":20})
 wake.deploy(0,Vector2i(4,3)); wake.deploy(1,Vector2i(5,2)); wake.deploy(2,Vector2i(6,3))
 wake.units[1].hp = 0.0
 check(wake.deploy(3,Vector2i(5,4)) == "","sleep releases occupancy")
 var wake_before = wake.dew
 check(wake.deploy(1,Vector2i(5,2)).contains("封死"),"wake must not seal route")
 check(wake.dew == wake_before,"failed wake does not debit")
 wake.remove(Vector2i(4,3))
 check(wake.deploy(1,Vector2i(5,2)) == "","wake after opening route")
 check(wake.units[0].hp > 0 and wake.dew == wake_before-4,"wake restores health and spends4")
 var deterministic_a = Sim.new(); var deterministic_b = Sim.new()
 for same in [deterministic_a, deterministic_b]:
  same.setup({"seed":22,"biome":"lake","team":starters})
  same.deploy(0,Vector2i(4,3)); same.deploy(1,Vector2i(5,2)); same.deploy(2,Vector2i(6,3)); same.start()
  for i in range(30): same.step(0.05)
 check(deterministic_a.tiles == deterministic_b.tiles,"seeded terrain deterministic")
 check(deterministic_a.enemies == deterministic_b.enemies,"seeded simulation deterministic")
 check(deterministic_a.dew == deterministic_b.dew,"seeded economy deterministic")
 for enemy in deterministic_a.enemies:
  if not enemy.flying:
   var before_deploy = deterministic_a.dew
   check(deterministic_a.deploy(0,enemy.next_cell) != "","cannot place into active traversal")
   check(deterministic_a.dew == before_deploy,"active traversal rejection free")
 print("BATTLE_CHECKS ",checks," FAILURES ",failures)
 quit(1 if failures > 0 else 0)
