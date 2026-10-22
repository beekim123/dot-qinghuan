extends SceneTree
const Model = preload("res://scripts/planet_model.gd")
func _init() -> void:
	for seed_value in range(40):
		var m = Model.new()
		m.generate(seed_value*733+9)
		assert(m.cells.size()==362,"Cell count")
		var pentagons: int = 0
		for i in m.cells.size():
			var c: Dictionary = m.cells[i]
			assert(c.neighbors.size() in [5,6],"Cell degree")
			assert(c.corners.size()==c.neighbors.size(),"Dual face corners")
			if c.neighbors.size()==5: pentagons+=1
			for neighbor in c.neighbors:
				assert(m.cells[neighbor].neighbors.has(i),"Reciprocity")
		assert(pentagons==12,"Pentagon count")
		for a in range(3):
			for b in range(a+1,3):
				assert(m.cells[m.springs[a].cell].dir.dot(m.cells[m.springs[b].cell].dir) < cos(deg_to_rad(75.0)),"Spring separation")
		var clone = Model.new()
		clone.generate(seed_value*733+9)
		assert(m.cells==clone.cells and m.springs==clone.springs,"Deterministic generation")
		assert(m.clear_fraction()==0.0)
		m.clear_region(m.landing)
		assert(m.clear_fraction()>0.0)
		assert(m.clear_region(m.landing)==0,"Idempotent clear")
	print("PLANET PASS: 40 seeds, 362 cells, 12 pentagons, reciprocal adjacency, spaced springs, deterministic generation, persistent/idempotent clearing.")
	quit()
