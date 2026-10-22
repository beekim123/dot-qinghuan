class_name RunState
extends RefCounted

const SAVE_PATH = "user://qinghuan_meta.json"
const STAGES = ["灰寂", "初醒", "萌青", "繁茂", "清欢"]
const TIMES = ["晨", "午", "暮", "夜"]
var meta: Dictionary = {"sand":0,"oil":0,"dew":0,"bond":0,"unlocked":["dida","taituan","dengxin"],"inherited":"","runs":0,"wins":0}
var planet: PlanetModel
var rng = RandomNumberGenerator.new()
var seed_value: int = 0
var team: Array = []
var starters: Array = ["dida","taituan","dengxin"]
var hp: int = 18
var max_hp: int = 18
var dew: int = 0
var hour: int = 0
var stage: int = 0
var wins: int = 0
var candidates: Array = []
var chosen: Dictionary = {}
var last_message: String = ""
var earned_sand: int = 0
var ended: bool = false
var won: bool = false

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for key in meta:
			if data.has(key): meta[key] = data[key]
		for key in ["sand","oil","dew","bond","runs","wins"]: meta[key] = maxi(0,int(meta[key]))
		if not meta.unlocked is Array: meta.unlocked = starters.duplicate()
		for id in starters:
			if not id in meta.unlocked: meta.unlocked.append(id)

func save_meta() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(meta, "\t"))

func start_run(seed_override: int = 0) -> void:
	seed_value = seed_override if seed_override != 0 else int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())
	rng.seed = seed_value
	planet = PlanetModel.new()
	planet.generate(seed_value)
	team.clear()
	for id in starters: team.append({"id":id,"level":1,"evolved":false})
	var inherited = str(meta.inherited)
	if inherited != "" and not has_species(inherited): team.append({"id":inherited,"level":1,"evolved":false})
	max_hp = 18 + mini(3,int(meta.oil)) * 2
	hp = max_hp
	dew = 12
	hour = 0
	stage = 0
	wins = 0
	ended = false
	won = false
	chosen = {}
	last_message = "灯婆婆：不必急着走远，先让一小片草地亮起来。"
	make_candidates()

func has_species(id: String) -> bool:
	for member in team:
		if member.id == id: return true
	return false

func available_friend() -> String:
	var missing: Array = []
	for id in GameData.IDS:
		if not has_species(id): missing.append(id)
	if missing.is_empty(): return ""
	return missing[rng.randi_range(0,missing.size()-1)]

func recruit(id: String) -> void:
	if id.is_empty() or has_species(id): return
	team.append({"id":id,"level":maxi(1,1+wins/2),"evolved":false})

func train(index: int = -1) -> void:
	for i in team.size():
		if index == -1 or i == index: team[i].level = mini(12,int(team[i].level)+1)

func evolve(index: int) -> bool:
	if index < 0 or index >= team.size() or team[index].evolved or int(team[index].level)<3: return false
	team[index].evolved = true
	return true

func make_candidates() -> void:
	candidates.clear()
	var pool: Array = []
	for i in planet.cells.size():
		var cell: Dictionary = planet.cells[i]
		if cell.biome != "water" and not cell.clear: pool.append(i)
	if pool.size()<3:
		for i in planet.cells.size():
			if planet.cells[i].biome != "water": pool.append(i)
	var selected: Array = []
	for n in 3:
		var best: int = pool[rng.randi_range(0,pool.size()-1)]
		var best_score: float = -1000.0
		for attempt in 70:
			var index: int = pool[rng.randi_range(0,pool.size()-1)]
			var score: float = 0.0
			for near in planet.region(index,3):
				if not planet.cells[near].clear: score += 1.0
			for other in selected: score -= maxf(0.0,0.7-planet.cells[index].dir.angle_to(planet.cells[other].dir))*100.0
			score += rng.randf()*6.0
			if score>best_score:
				best = index
				best_score = score
		selected.append(best)
		var type = "battle"
		if n==1: type = "rest" if hour%2==1 else "battle"
		if n==2: type = "shop" if hour%2==0 else "rest"
		candidates.append(_node(best,type,-1))
	for i in 3:
		if planet.springs[i].sealed: continue
		var unlocked = (i==0 and wins>=2 and stage>=1) or (i==1 and wins>=4 and stage>=2) or (i==2 and sealed_count()==2 and stage>=3)
		if unlocked: candidates.append(_node(int(planet.springs[i].cell),"boss",i))

func _node(cell: int, type: String, spring: int) -> Dictionary:
	var nearest: int = planet.nearest_spring(cell)
	return {"cell":cell,"type":type,"spring":spring,"biome":planet.cells[cell].biome,"seed":rng.randi(),"level":int(planet.springs[nearest].level),"friend":available_friend()}

func sealed_count() -> int:
	var count: int = 0
	for spring in planet.springs:
		if spring.sealed: count+=1
	return count

func battle_config() -> Dictionary:
	return {"seed":chosen.seed,"biome":chosen.biome,"team":team.duplicate(true),"heart_hp":hp,"dew":8+int(meta.dew)*2,"stage":stage,"spring_level":chosen.level,"boss":("mianmian" if chosen.spring==2 else "spring") if chosen.type=="boss" else "","free_cap":mini(6,3+stage)}

func resolve_battle(sim: BattleSim) -> void:
	hp = int(sim.heart_hp)
	if not sim.victory:
		finish(false)
		return
	wins += 1
	dew += int(sim.dew) + mini(6,int(sim.dew)/10*2)
	train()
	planet.clear_region(int(chosen.cell),3)
	last_message = "浊散成露水，小妖都醒来了。这片土地记得你。"
	if chosen.type=="boss":
		planet.springs[int(chosen.spring)].sealed = true
		hp = mini(max_hp,hp+5)
		last_message = "浊泉已封，清泉留下了新的光。心灯 +5。"
		if int(chosen.spring)==2:
			stage = 4
			for cell in planet.cells: cell.clear = true
			finish(true)
			return
	update_stage()

func update_stage() -> void:
	var fraction = planet.clear_fraction()
	var next = 3 if fraction>=0.42 else (2 if fraction>=0.25 else (1 if fraction>=0.10 else 0))
	if next>stage:
		hp = mini(max_hp,hp+3*(next-stage))
		stage = next
		last_message += " 星相 · %s，心灯回暖，免费出阵 +1。"%STAGES[stage]

func advance() -> void:
	hour += 1
	if hour%4==0:
		for spring in planet.springs:
			if spring.sealed: continue
			spring.level = int(spring.level)+(2 if hour>=16 else 1)
			var removed: int = 0
			for index in planet.region(int(spring.cell),4):
				if planet.cells[index].clear and removed<2:
					planet.cells[index].clear = false
					removed+=1
		last_message += " 浊潮经过：未封的浊泉变强了。"
	make_candidates()

func finish(victory: bool) -> void:
	if ended: return
	ended = true
	won = victory
	earned_sand = maxi(12,int(planet.clear_fraction()*100)+sealed_count()*15+maxi(0,team.size()-3)*5+(40 if victory else 0))
	meta.sand = int(meta.sand)+earned_sand
	meta.runs = int(meta.runs)+1
	if victory: meta.wins = int(meta.wins)+1
	for member in team:
		if not member.id in meta.unlocked: meta.unlocked.append(member.id)
	save_meta()

func inherit(index: int) -> void:
	if index>=0 and index<team.size(): meta.inherited=team[index].id
	save_meta()

func buy_upgrade(key: String) -> bool:
	if not key in ["oil","dew","bond"]: return false
	var level = int(meta[key])
	var cost = 35+level*30
	if level>=3 or int(meta.sand)<cost: return false
	meta.sand = int(meta.sand)-cost
	meta[key] = level+1
	save_meta()
	return true

func time_label() -> String:
	return "第 %d 天 · %s时 / 浊泉随时辰增强"%[hour/4+1,TIMES[hour%4]]
