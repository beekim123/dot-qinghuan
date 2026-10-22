class_name PlanetModel
extends RefCounted
## Frequency-six icosahedral triangulation, dualised into 350 hexagons and 12 pentagons.
var cells: Array = []
var springs: Array = []
var world_seed: int = 0
var landing: int = 0
var _lookup: Dictionary = {}
var _triangles: Array = []

func generate(seed_value: int) -> void:
	world_seed = seed_value
	cells.clear()
	springs.clear()
	_lookup.clear()
	_triangles.clear()
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var v: Array = [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
	var faces: Array = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	for f in faces:
		var grid: Dictionary = {}
		for i in range(7):
			for j in range(7-i):
				var p: Vector3 = (v[f[0]] * (6-i-j) + v[f[1]] * i + v[f[2]] * j).normalized()
				grid[Vector2i(i,j)] = _vertex(p)
		for i in range(6):
			for j in range(6-i):
				_triangle(grid[Vector2i(i,j)], grid[Vector2i(i+1,j)], grid[Vector2i(i,j+1)])
				if i+j < 5:
					_triangle(grid[Vector2i(i+1,j)], grid[Vector2i(i+1,j+1)], grid[Vector2i(i,j+1)])
	for c in cells:
		var n: Vector3 = c.dir
		var tangent: Vector3 = n.cross(Vector3.UP).normalized()
		if tangent.length_squared() < 0.1:
			tangent = n.cross(Vector3.RIGHT).normalized()
		var bitangent: Vector3 = n.cross(tangent)
		c.corners.sort_custom(func(a: Vector3,b: Vector3) -> bool: return atan2(a.dot(bitangent), a.dot(tangent)) < atan2(b.dot(bitangent), b.dot(tangent)))
		c.neighbors.sort()
	_generate_terrain(seed_value)

func _vertex(p: Vector3) -> int:
	var key := Vector3i(roundi(p.x*100000),roundi(p.y*100000),roundi(p.z*100000))
	if _lookup.has(key):
		return _lookup[key]
	var index: int = cells.size()
	_lookup[key] = index
	cells.append({"dir":p,"neighbors":[],"corners":[],"biome":"grass","clear":false,"height":0.0,"mark":false})
	return index

func _triangle(a: int,b: int,c: int) -> void:
	var center: Vector3 = (cells[a].dir + cells[b].dir + cells[c].dir).normalized()
	for index in [a,b,c]:
		cells[index].corners.append(center)
		for other in [a,b,c]:
			if other != index and not cells[index].neighbors.has(other):
				cells[index].neighbors.append(other)
	_triangles.append([a,b,c])

func _generate_terrain(seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.65
	noise.fractal_octaves = 3
	var forest := FastNoiseLite.new()
	forest.seed = seed_value ^ 71939
	forest.frequency = 3.1
	var order: Array = []
	for i in cells.size():
		var d: Vector3 = cells[i].dir
		cells[i].height = noise.get_noise_3dv(d)
		order.append(i)
	order.sort_custom(func(a: int,b: int) -> bool: return cells[a].height < cells[b].height)
	for rank in order.size():
		var index: int = order[rank]
		var c: Dictionary = cells[index]
		var percentile: float = float(rank)/float(order.size())
		c.height = percentile
		if percentile < 0.14:
			c.biome = "water"
		elif percentile < 0.22:
			c.biome = "lake"
		elif percentile > 0.97:
			c.biome = "snow"
		elif percentile > 0.87:
			c.biome = "mountain"
		elif forest.get_noise_3dv(c.dir) > 0.03:
			c.biome = "forest"
		else:
			c.biome = "grass"
	for c in cells:
		if c.biome == "grass":
			for neighbor in c.neighbors:
				if cells[neighbor].biome == "water":
					c.biome = "sand"
					break
	var eligible: Array = []
	for i in cells.size():
		if cells[i].height < 0.25 or cells[i].height > 0.8:
			continue
		var inland := true
		for neighbor in cells[i].neighbors:
			if cells[neighbor].biome in ["water","lake"]:
				inland = false
		if inland:
			eligible.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	landing = eligible[rng.randi_range(0,eligible.size()-1)]
	var chosen: Array = [eligible[rng.randi_range(0,eligible.size()-1)]]
	for s in range(2):
		var best: int = -1
		var best_score: float = -2.0
		for index in eligible:
			var score: float = 2.0
			for old in chosen:
				score = minf(score, 1.0 - cells[index].dir.dot(cells[old].dir))
			if score > best_score:
				best_score = score
				best = index
		chosen.append(best)
	chosen.sort_custom(func(a: int,b: int) -> bool: return cells[a].dir.dot(cells[landing].dir) > cells[b].dir.dot(cells[landing].dir))
	for index in chosen:
		springs.append({"cell":index,"sealed":false,"level":1})

func region(cell: int, radius: int) -> Array:
	if cell < 0 or cell >= cells.size():
		return []
	var result: Array = [cell]
	var frontier: Array = [cell]
	for _r in range(radius):
		var next: Array = []
		for index in frontier:
			for neighbor in cells[index].neighbors:
				if not result.has(neighbor):
					result.append(neighbor)
					next.append(neighbor)
		frontier = next
	return result

func clear_region(cell: int, radius: int = 3) -> int:
	var newly_clear: int = 0
	for index in region(cell,radius):
		if not cells[index].clear:
			newly_clear += 1
		cells[index].clear = true
	cells[cell].mark = true
	return newly_clear

func clear_fraction() -> float:
	var land: int = 0
	var cleared: int = 0
	for c in cells:
		if c.biome != "water":
			land += 1
			if c.clear:
				cleared += 1
	return float(cleared)/maxi(land,1)

func nearest_spring(cell: int) -> int:
	var best: int = 0
	var score: float = -2.0
	for i in springs.size():
		var dot: float = cells[cell].dir.dot(cells[springs[i].cell].dir)
		if dot > score:
			score = dot
			best = i
	return best
