class_name BattleSim
extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const DIRS = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
var width: int = 11
var height: int = 7
var heart = Vector2i(5,3)
var entrances: Array = [Vector2i(0,3),Vector2i(10,3),Vector2i(5,0)]
var tiles: Array = []
var units: Array = []
var enemies: Array = []
var events: Array = []
var team: Array = []
var heart_hp: int = 12
var dew: int = 6
var wave: int = 0
var total_waves: int = 3
var running: bool = false
var finished: bool = false
var victory: bool = false
var time: float = 0.0
var skill_cooldown: float = 0.0
var boss: String = ""
var biome: String = "grass"
var free_limit: int = 3
var _rng = RandomNumberGenerator.new()
var _strength: float = 1.0
var _spawn_left: int = 0
var _spawn_timer: float = 0.0
var _break_timer: float = 0.0
var _uid: int = 0
var _boss_spawned: bool = false
var _boss_washed: bool = false
var _accum: float = 0.0

func setup(config: Dictionary) -> void:
 _rng.seed = int(config.get("seed", 1))
 team = config.get("team", []).duplicate(true)
 heart_hp = int(config.get("heart_hp", 12))
 dew = int(config.get("dew", 6))
 boss = str(config.get("boss", ""))
 biome = str(config.get("biome", "grass"))
 free_limit = 3 + int(config.get("stage", 0))
 _strength = (1.0 + 0.12 * (int(config.get("spring_level",1))-1)) * (1.0 + 0.08 * int(config.get("stage",0)))
 units.clear(); enemies.clear(); events.clear(); tiles.clear()
 running = false; finished = false; victory = false; time = 0.0; wave = 0
 _spawn_left = 0; _uid = 0; _boss_spawned = false; _boss_washed = false; _accum = 0.0
 skill_cooldown = 0.0
 for y in range(height):
  for x in range(width):
   var cell = Vector2i(x,y)
   var tile = {"terrain":"grass", "height":0.0, "obstacle":"", "dew":false}
   if biome == "sand": tile.terrain = "sand"
   elif biome == "forest": tile.terrain = "forest"
   elif biome == "snow": tile.terrain = "snow"
   if cell.distance_to(heart) > 1.5 and not cell in entrances:
    var chance = _rng.randf()
    if biome == "lake" and chance < 0.17:
     tile.terrain = "water"
    elif biome == "mountain" and chance < 0.12:
     tile.terrain = "high"; tile.height = 0.45
    elif chance < (0.09 if biome == "forest" else 0.035):
     tile.obstacle = "tree" if biome == "forest" else "rock"
   tiles.append(tile)
 # Preserve terrain diversity but prune only blockers which disconnect an entrance.
 for entrance in entrances:
  if _path(entrance, {}).is_empty():
   for tile in tiles:
    tile.obstacle = ""
    if tile.terrain in ["water", "high", "deep"]: tile.terrain = "grass"; tile.height = 0.0
 if biome == "forest":
  _forest_landforms()
 for c in [Vector2i(3,4),Vector2i(7,2)]:
  tiles[_index(c)].dew = true
  tiles[_index(c)].obstacle = ""
  tiles[_index(c)].terrain = "grass"


# Compact authored landform footprints, mirrored by the encounter seed.
# Grass knolls are gentle walkable steps, not the impassable "high" platforms.
func _forest_landforms() -> void:
 var mirror_x: bool = _rng.randf() < 0.5
 var mirror_y: bool = _rng.randf() < 0.5
 var water_count: int = _rng.randi_range(2,4)
 var pocket: Array = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
 for i in range(water_count):
  var cell: Vector2i = pocket[i]
  if mirror_x: cell.x = width-1-cell.x
  if mirror_y: cell.y = height-1-cell.y
  var tile: Dictionary = tiles[_index(cell)]
  tile.terrain = "water"
  tile.height = 0.0
  tile.obstacle = ""
 var knoll: Array = [Vector2i(8,1),Vector2i(9,1),Vector2i(9,2)]
 for i in range(knoll.size()):
  var cell: Vector2i = knoll[i]
  if mirror_x: cell.x = width-1-cell.x
  if mirror_y: cell.y = height-1-cell.y
  var tile: Dictionary = tiles[_index(cell)]
  tile.terrain = "forest"
  tile.height = 0.4 if i == 1 else 0.25
  tile.obstacle = ""
 # The corner pool must never turn incidental tree clutter into a sealed arena.
 # Remove only decorative blockers if necessary, retaining the coherent pool.
 for entrance in entrances:
  if _path(entrance, {}).is_empty():
   for tile in tiles: tile.obstacle = ""

func _index(cell: Vector2i) -> int:
 return cell.y * width + cell.x

func in_bounds(cell: Vector2i) -> bool:
 return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func _terrain_open(cell: Vector2i) -> bool:
 if not in_bounds(cell): return false
 var tile: Dictionary = tiles[_index(cell)]
 return tile.obstacle == "" and not tile.terrain in ["water", "deep", "high"]

func _occupied(except_index: int = -1) -> Dictionary:
 var result = {}
 for unit in units:
  if unit.team_index != except_index and unit.hp > 0: result[unit.cell] = true
 return result

func _path(start_cell: Vector2i, blocked: Dictionary) -> Array:
 if start_cell == heart: return [heart]
 if not in_bounds(start_cell) or blocked.has(start_cell): return []
 var queue: Array = [start_cell]
 var previous = {start_cell: start_cell}
 var cursor = 0
 while cursor < queue.size():
  var current: Vector2i = queue[cursor]; cursor += 1
  for direction in DIRS:
   var next: Vector2i = current + direction
   if previous.has(next) or blocked.has(next) or not _terrain_open(next): continue
   previous[next] = current
   if next == heart:
    var result: Array = [heart]
    var back: Vector2i = heart
    while back != start_cell:
     back = previous[back]; result.push_front(back)
    return result
   queue.append(next)
 return []

func paths() -> Array:
 var result: Array = []
 var blocked = _occupied()
 for entrance in entrances: result.append(_path(entrance, blocked))
 return result

func can_deploy(team_index: int, cell: Vector2i) -> String:
 if finished: return "本场已经结束"
 if team_index < 0 or team_index >= team.size(): return "请选择一只小妖"
 if not in_bounds(cell): return "请放在沙盘方格内"
 if cell == heart: return "这里是心，需要留空"
 if cell in entrances: return "入口需要留空"
 var tile: Dictionary = tiles[_index(cell)]
 if tile.obstacle != "": return "树石占据了这格"
 if tile.terrain == "deep": return "深水不能部署"
 if tile.terrain == "water" and Data.species(team[team_index].id).element != "水": return "浅水仅水属性小妖可站"
 var occupied = _occupied(team_index)
 if occupied.has(cell): return "这格已有伙伴"
 for other in units:
  if other.team_index != team_index and other.cell == cell: return "这格有熟睡的伙伴，请先将它移开"
 for enemy in enemies:
  if enemy.hp > 0 and not enemy.flying and (Vector2(cell).distance_to(enemy.pos) < 0.7 or enemy.next_cell == cell):
   return "浊正在经过这里"
 occupied[cell] = true
 for entrance in entrances:
  if _path(entrance, occupied).is_empty(): return "会封死通路：每个入口都需要能到达心"
 for enemy in enemies:
  if enemy.hp > 0 and not enemy.flying:
   if _path(enemy.cell, occupied).is_empty() or _path(enemy.next_cell, occupied).is_empty(): return "会封死通路：浊需要保留绕行空间"
 var existing = _find_unit(team_index)
 var cost = _deploy_cost(existing)
 if not running and existing.is_empty() and units.size() >= free_limit: return "免费出阵已满；开战后可用露水增援"
 if dew < cost: return "露水不足，需要 %d 滴" % cost
 return ""

func _deploy_cost(existing: Dictionary) -> int:
 if not existing.is_empty() and existing.hp <= 0: return 4
 if not running: return 0
 return 4 if existing.is_empty() else 2

func _find_unit(team_index: int) -> Dictionary:
 for unit in units:
  if unit.team_index == team_index: return unit
 return {}

func deploy(team_index: int, cell: Vector2i) -> String:
 var reason = can_deploy(team_index, cell)
 if reason != "": return reason
 var unit = _find_unit(team_index)
 dew -= _deploy_cost(unit)
 if unit.is_empty():
  var member: Dictionary = team[team_index]
  var data = Data.species(member.id)
  var multiplier = 1.0 + 0.16 * (int(member.get("level",1))-1)
  if member.get("evolved",false): multiplier *= 1.3
  unit = {"team_index":team_index,"id":member.id,"cell":cell,"hp":data.hp*multiplier,"max_hp":data.hp*multiplier,"damage":data.damage*multiplier,"range":data.range,"interval":data.interval,"role":data.role,"element":data.element,"state":"idle","anim_time":0.0,"cooldown":0.2,"pending":-1,"attack_clock":0.0,"production":0.0,"shots":0,"evolved":member.get("evolved",false)}
  units.append(unit)
 else:
  unit.cell = cell
  if unit.hp <= 0: unit.hp = unit.max_hp * 0.55
  unit.state = "idle"; unit.anim_time = 0.0
 return ""

func remove(cell: Vector2i) -> String:
 if finished: return "本场已经结束"
 for unit in units:
  if unit.cell == cell:
   units.erase(unit)
   return ""
 return "这里没有伙伴"

func start() -> void:
 if finished or running: return
 running = true
 _begin_wave()

func _begin_wave() -> void:
 wave += 1
 _spawn_left = 5 + wave * 2
 _spawn_timer = 0.8
 _break_timer = 0.0
 events.append({"type":"wave","wave":wave})
 for unit in units:
  if unit.hp > 0 and unit.id == "taituan": unit.hp = minf(unit.max_hp, unit.hp + unit.max_hp * 0.2)

func step(dt: float) -> void:
 if not running or finished: return
 _accum += minf(dt, 0.25)
 while _accum >= 0.05 and not finished:
  _accum -= 0.05
  _tick(0.05)

func _tick(dt: float) -> void:
 time += dt
 skill_cooldown = maxf(0.0, skill_cooldown-dt)
 if _spawn_left > 0:
  _spawn_timer -= dt
  if _spawn_timer <= 0:
   var id = "murk"
   if _spawn_left == 1 and wave >= 2: id = "big"
   elif wave >= 2 and _spawn_left % 4 == 0: id = "fly"
   _spawn(id, entrances[(_spawn_left+wave) % entrances.size()])
   _spawn_left -= 1; _spawn_timer = 1.65
 if boss != "" and wave == total_waves and not _boss_spawned and _spawn_left <= 3:
  _spawn(boss, Vector2i(5,0)); _boss_spawned = true
 for unit in units: _update_unit(unit, dt)
 var blockers_used = {}
 for enemy in enemies:
  if enemy.hp > 0: _update_enemy(enemy,dt,blockers_used)
 for enemy in enemies.duplicate():
  if enemy.hp <= 0:
   if enemy.id in ["spring","mianmian"]: _boss_washed = true
   if not enemy.get("leaked", false):
    var value = 3 if enemy.id == "big" else 1
    dew += value
    events.append({"type":"dew","from":enemy.pos,"to":enemy.pos,"kind":enemy.id})
   enemies.erase(enemy)
 if heart_hp <= 0:
  heart_hp = 0; finished = true; victory = false; running = false
  return
 if _spawn_left == 0 and enemies.is_empty():
  if wave >= total_waves and (boss == "" or _boss_washed):
   finished = true; victory = true; running = false
  elif wave < total_waves:
   _break_timer += dt
   if _break_timer >= 3.5: _begin_wave()

func _spawn(id: String, cell: Vector2i) -> void:
 _uid += 1
 var hp = 4.2; var speed = 0.48; var erosion = 1.0; var contact = 1
 if id == "fly": hp = 3.0; speed = 0.65
 if id == "big": hp = 15.0; speed = 0.32; erosion = 2.0; contact = 3
 if id == "spring": hp = 54.0; speed = 0.18; erosion = 2.4; contact = 3
 if id == "mianmian": hp = 95.0; speed = 0.15; erosion = 2.8; contact = 3
 hp *= _strength
 enemies.append({"uid":_uid,"id":id,"pos":Vector2(cell),"cell":cell,"next_cell":cell,"hp":hp,"max_hp":hp,"speed":speed,"erosion":erosion,"contact":contact,"flying":id=="fly","state":"move","anim_time":0.0,"slow":0.0,"stun":0.0,"age":0.0,"pulse":0.0,"moss":3 if id=="mianmian" else 0,"moss_damage":0.0,"leaked":false})

func _target(unit: Dictionary) -> Dictionary:
 var best: Dictionary = {}
 var best_distance = INF
 var bonus = 0.6 if tiles[_index(unit.cell)].terrain == "high" else 0.0
 for enemy in enemies:
  if enemy.hp <= 0: continue
  if Vector2(unit.cell).distance_to(enemy.pos) > unit.range + bonus: continue
  var distance = enemy.pos.distance_to(Vector2(heart))
  if distance < best_distance: best_distance = distance; best = enemy
 return best

func _enemy_by_uid(uid: int) -> Dictionary:
 for enemy in enemies:
  if enemy.uid == uid and enemy.hp > 0: return enemy
 return {}

func _update_unit(unit: Dictionary, dt: float) -> void:
 unit.anim_time += dt
 if unit.hp <= 0: unit.state = "sleep"; return
 if unit.state == "hit" and unit.anim_time > 0.25: unit.state = "idle"; unit.anim_time = 0.0
 if unit.id == "piaopiao":
  unit.production += dt * (1.5 if tiles[_index(unit.cell)].dew else 1.0)
  if unit.production >= 6.0:
   unit.production -= 6.0; dew += 1
   events.append({"type":"dew","from":Vector2(unit.cell),"to":Vector2(unit.cell),"kind":"piaopiao"})
 if unit.id == "dida":
  for ally in units:
   if ally.hp > 0 and ally.element == "苔" and _adjacent(unit.cell,ally.cell): ally.hp = minf(ally.max_hp,ally.hp+ally.max_hp*0.012*dt)
 if unit.pending >= 0:
  unit.attack_clock += dt
  if unit.attack_clock >= 0.20:
   var target = _enemy_by_uid(unit.pending)
   if not target.is_empty(): _release(unit,target)
   unit.pending = -1
 if unit.state == "attack" and unit.anim_time >= 0.48: unit.state = "idle"; unit.anim_time = 0.0
 unit.cooldown -= dt
 if unit.cooldown > 0: return
 if unit.role == "援":
  var patient: Dictionary = {}
  var fraction = 0.96
  for ally in units:
   if ally.hp > 0 and Vector2(unit.cell).distance_to(Vector2(ally.cell)) <= unit.range and ally.hp/ally.max_hp < fraction:
    patient = ally; fraction = ally.hp/ally.max_hp
  if not patient.is_empty():
   patient.hp = minf(patient.max_hp, patient.hp + 2.2 + unit.damage)
   unit.cooldown = unit.interval; unit.state = "attack"; unit.anim_time = 0.0
   events.append({"type":"attack","from":Vector2(unit.cell),"to":Vector2(patient.cell),"kind":"heal"})
   return
 var target = _target(unit)
 if target.is_empty(): return
 unit.pending = target.uid; unit.attack_clock = 0.0
 unit.state = "attack"; unit.anim_time = 0.0; unit.cooldown = unit.interval

func _adjacent(a: Vector2i, b: Vector2i) -> bool:
 return absi(a.x-b.x)+absi(a.y-b.y) == 1

func _release(unit: Dictionary, target: Dictionary) -> void:
 unit.shots += 1
 var damage: float = unit.damage
 for ally in units:
  if ally.id == "dengxin" and ally.hp > 0 and _adjacent(unit.cell,ally.cell): damage *= 1.08
 var victims: Array = [target]
 if unit.role in ["溅","控"]:
  for enemy in enemies:
   if enemy != target and enemy.hp > 0 and enemy.pos.distance_to(target.pos) < 1.15: victims.append(enemy)
 elif unit.id == "yingzi":
  for enemy in enemies:
   if enemy != target and enemy.hp > 0 and enemy.pos.distance_to(target.pos) < 2.1 and victims.size() < 3: victims.append(enemy)
 for enemy in victims:
  var amount = damage
  if (unit.element == "水" and enemy.id == "murk") or (unit.element == "光" and enemy.id == "big") or (unit.element == "汽" and enemy.id == "fly"): amount *= 1.35
  _damage_enemy(enemy,amount)
  if unit.id in ["dida","chayan"]: enemy.slow = 1.7
  if unit.id == "chayan" and int(unit.shots) % 3 == 0: enemy.stun = 0.7
  events.append({"type":"attack","from":Vector2(unit.cell),"to":enemy.pos,"kind":unit.id})

func _damage_enemy(enemy: Dictionary, amount: float) -> void:
 if enemy.id == "mianmian" and enemy.moss > 0:
  enemy.moss_damage += amount
  if enemy.moss_damage >= enemy.max_hp * 0.10:
   enemy.moss_damage = 0.0; enemy.moss -= 1
   if enemy.moss == 0: enemy.stun = 6.0
 if enemy.id == "mianmian" and enemy.moss == 0 and enemy.stun > 0: amount *= 2.0
 enemy.hp -= amount
 enemy.state = "hit"; enemy.anim_time = 0.0

func _update_enemy(enemy: Dictionary, dt: float, blockers_used: Dictionary) -> void:
 enemy.anim_time += dt; enemy.age += dt
 enemy.slow = maxf(0.0, enemy.slow-dt); enemy.stun = maxf(0.0, enemy.stun-dt)
 if enemy.stun > 0: enemy.state = "sleep"; return
 if enemy.state == "hit" and enemy.anim_time < 0.18: return
 if enemy.id in ["spring","mianmian"]:
  enemy.pulse += dt
  var summon_interval = 10.0 if enemy.id == "spring" else 8.0
  if enemy.pulse >= summon_interval:
   enemy.pulse = 0.0
   if enemy.id != "mianmian" or enemy.moss > 0: _spawn("murk",entrances[int(enemy.age) % entrances.size()])
   for unit in units:
    if unit.hp > 0 and Vector2(unit.cell).distance_to(enemy.pos) <= 2.2: _hurt_unit(unit,1.5)
  if enemy.hp > enemy.max_hp * 0.5 and enemy.age < 18.0: enemy.state = "idle"; return
 if not enemy.flying:
  for unit in units:
   if unit.hp <= 0 or unit.role != "拦": continue
   var capacity = 2
   var weight = 2 if enemy.id in ["big","spring","mianmian"] else 1
   if int(blockers_used.get(unit.team_index,0))+weight > capacity: continue
   if Vector2(unit.cell).distance_to(enemy.pos) <= 1.15:
    blockers_used[unit.team_index] = int(blockers_used.get(unit.team_index,0))+weight
    _hurt_unit(unit, enemy.erosion*dt)
    enemy.state = "attack"
    return
 enemy.state = "move"
 var speed: float = enemy.speed * (0.5 if enemy.slow > 0 else 1.0)
 if enemy.flying:
  enemy.pos = enemy.pos.move_toward(Vector2(heart),speed*dt)
 else:
  if enemy.pos.distance_to(Vector2(enemy.next_cell)) < 0.015:
   enemy.cell = enemy.next_cell
   var route = _path(enemy.cell,_occupied())
   if route.size() > 1: enemy.next_cell = route[1]
  if tiles[_index(enemy.cell)].terrain == "sand": speed *= 0.8
  enemy.pos = enemy.pos.move_toward(Vector2(enemy.next_cell),speed*dt)
 if enemy.pos.distance_to(Vector2(heart)) < 0.12:
  if enemy.id in ["spring","mianmian"]:
   enemy.pulse += dt * 3.0
   if enemy.pulse < 3.0: return
   enemy.pulse = 0.0
  else:
   enemy.hp = 0; enemy.leaked = true
  heart_hp -= enemy.contact
  events.append({"type":"heart","from":enemy.pos,"to":Vector2(heart),"kind":enemy.id})

func _hurt_unit(unit: Dictionary, amount: float) -> void:
 if tiles[_index(unit.cell)].terrain == "forest": amount *= 0.85
 for ally in units:
  if ally.id == "taituan" and ally.hp > 0 and _adjacent(unit.cell,ally.cell): amount *= 0.9
 unit.hp = maxf(0.0,unit.hp-amount)
 if unit.hp <= 0:
  unit.state = "sleep"; unit.anim_time = 0.0
  events.append({"type":"sleep","from":Vector2(unit.cell),"to":Vector2(unit.cell),"kind":unit.id})
 elif unit.state != "attack": unit.state = "hit"; unit.anim_time = 0.0

func lantern() -> String:
 if finished or not running: return "请先开始守心"
 if skill_cooldown > 0: return "灯照正在恢复（%d 秒）" % ceili(skill_cooldown)
 if dew < 6: return "灯照需要 6 滴露水"
 dew -= 6; skill_cooldown = 18.0
 for enemy in enemies:
  if enemy.hp > 0:
   _damage_enemy(enemy,5.0); enemy.slow = 4.0
 for unit in units:
  if unit.hp > 0: unit.hp = minf(unit.max_hp,unit.hp+3.0)
 events.append({"type":"attack","from":Vector2(heart),"to":Vector2(heart),"kind":"lantern"})
 return ""
