class_name ArenaView
extends Node3D
## The arena is a real 3D tiled diorama; all figures remain palette-index sprites.

var sim: BattleSim
var camera: Camera3D
var selected_index: int = -1
var hover_cell := Vector2i(-1, -1)
var _terrain_root: Node3D
var _actors: Dictionary = {}
var _tile_meshes: Array[MeshInstance3D] = []
var _clean_materials: Array[StandardMaterial3D] = []
var _dirty_materials: Array[StandardMaterial3D] = []
var _hover: Node3D
var _paths_root: Node3D
var _effects: Array[Dictionary] = []
var _clock: float = 0.0
var _clean_time: float = -1.0
var _path_clock: float = 0.0
var _heart_sprite: Sprite3D
var _last_heart: int = 0
var _bar_cache: Dictionary = {}

func setup(battle: BattleSim) -> void:
	sim = battle
	for child in get_children():
		child.queue_free()
	_actors.clear()
	_tile_meshes.clear()
	_clean_materials.clear()
	_dirty_materials.clear()
	_effects.clear()
	_clean_time = -1.0
	_last_heart = int(sim.heart_hp)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("262b44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c0cbdc")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ead4aa")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.8
	camera.position = Vector3(7.8, 16.4, 16.2)
	add_child(camera)
	camera.look_at(Vector3(0, 0.0, 0))
	camera.current = true
	_terrain_root = Node3D.new()
	add_child(_terrain_root)
	_build_terrain()
	_paths_root = Node3D.new()
	add_child(_paths_root)
	_hover = _outline(Color("fee761"), 0.96)
	add_child(_hover)
	_hover.visible = false
	refresh(0.0)

func _mat(col: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _box(pos: Vector3, size: Vector3, material: Material, parent: Node) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = material
	obj.position = pos
	parent.add_child(obj)
	return obj

func _height(cell: Vector2i) -> float:
	if cell.x < 0 or cell.y < 0 or cell.x >= sim.width or cell.y >= sim.height:
		return 0.0
	return float(sim.tiles[cell.y * sim.width + cell.x].get("height", 0.0))

func _world(point: Vector2, elevation: float = 0.0) -> Vector3:
	return Vector3(point.x - float(sim.width - 1) * 0.5, elevation, point.y - float(sim.height - 1) * 0.5)

func _tile_color(terrain: String) -> Color:
	match terrain:
		"forest": return Color("3e8948")
		"water": return Color("0099db")
		"deep": return Color("124e89")
		"sand": return Color("ead4aa")
		"high": return Color("8b9bb4")
		"snow": return Color("c0cbdc")
	return Color("63c74d")

func _tile_texture(terrain: String, clean: bool) -> ImageTexture:
	var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := _tile_color(terrain)
	if not clean:
		base = base.lerp(Color("5a6988"), 0.42)
	im.fill(base)
	# A few authored clusters suggest the material without visual noise.
	var shade := base.darkened(0.13)
	var light := base.lightened(0.12)
	if terrain == "water" or terrain == "deep":
		for row in [4, 11]:
			for x in range(3, 8): im.set_pixel(x + (4 if row == 11 else 0), row, light)
		im.set_pixel(8, 3, light)
	elif terrain == "sand":
		for p in [Vector2i(4,5),Vector2i(5,5),Vector2i(10,11),Vector2i(11,11)]: im.set_pixelv(p, shade)
	elif terrain == "high":
		for x in range(3, 10): im.set_pixel(x, 10, shade)
		for y in range(4, 10): im.set_pixel(10, y, light)
	else:
		for p in [Vector2i(3,11),Vector2i(4,10),Vector2i(4,11),Vector2i(11,4),Vector2i(11,5),Vector2i(12,5)]: im.set_pixelv(p, shade)
		for p in [Vector2i(5,10),Vector2i(12,4)]: im.set_pixelv(p, light)
	return ImageTexture.create_from_image(im)

func _build_terrain() -> void:
	var bottom := _mat(Color("3e2731"))
	_box(Vector3(0, -0.68, 0), Vector3(sim.width + 0.14, 0.22, sim.height + 0.14), bottom, _terrain_root)
	for y in range(sim.height):
		for x in range(sim.width):
			var cell := Vector2i(x, y)
			var t: Dictionary = sim.tiles[y * sim.width + x]
			var terrain := str(t.get("terrain", "grass"))
			var h := _height(cell)
			var position3 := _world(Vector2(cell), h)
			var sides := _mat(Color("733e39") if terrain != "high" else Color("5a6988"))
			_box(position3 + Vector3(0, -(h + 0.6) * 0.5, 0), Vector3(0.98, h + 0.6, 0.98), sides, _terrain_root)
			var dirty := _mat(Color.WHITE)
			dirty.albedo_texture = _tile_texture(terrain, false)
			dirty.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var clean := _mat(Color.WHITE)
			clean.albedo_texture = _tile_texture(terrain, true)
			clean.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var top := _box(position3 + Vector3(0,0.025,0), Vector3(0.97,0.05,0.97), dirty, _terrain_root)
			_tile_meshes.append(top)
			_dirty_materials.append(dirty)
			_clean_materials.append(clean)
			if str(t.get("obstacle", "")) != "":
				var obstacle := _sprite(str(t.obstacle), 0.047)
				obstacle.position = position3 + Vector3(0, 0.58, 0)
				_terrain_root.add_child(obstacle)
				_shadow(position3 + Vector3(0,0.058,0), 0.65, _terrain_root)
			if bool(t.get("dew", false)):
				var ring := _outline(Color("2ce8f5"), 0.62)
				ring.position = position3 + Vector3(0,0.065,0)
				_terrain_root.add_child(ring)
	for entrance in sim.entrances:
		var c: Vector2i = entrance
		var root := _outline(Color("b55088"), 0.8)
		root.position = _world(Vector2(c), _height(c) + 0.08)
		_terrain_root.add_child(root)
		# Stepped inward arrow, not a permanent lane.
		var inward := (Vector2(sim.heart) - Vector2(c)).normalized()
		var a := _world(Vector2(c), _height(c) + 0.1)
		for k in range(3):
			_box(a + Vector3(inward.x,0,inward.y) * (float(k)-1.0) * 0.13, Vector3(0.34-float(k)*0.08,0.04,0.10), _mat(Color("b55088"),true),_terrain_root)
	var heart_pos := _world(Vector2(sim.heart),_height(sim.heart))
	_box(heart_pos+Vector3(0,0.06,0),Vector3(0.72,0.12,0.72),_mat(Color("d77643")),_terrain_root)
	_heart_sprite = _sprite("heart", 0.052)
	_heart_sprite.position = heart_pos + Vector3(0,0.77,0)
	_terrain_root.add_child(_heart_sprite)
	var glow := OmniLight3D.new()
	glow.position = heart_pos+Vector3(0,1.1,0)
	glow.light_color = Color("fee761")
	glow.light_energy = 0.7
	glow.omni_range = 4.0
	_terrain_root.add_child(glow)
	_shadow(heart_pos+Vector3(0,0.07,0),0.8,_terrain_root)

func _sprite(id: String, pixel_size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = PixelArt.texture(id)
	s.pixel_size = pixel_size
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	return s

func _shadow(pos: Vector3, size: float, parent: Node) -> void:
	# Stepped three-strip shadow is deliberately pixel-shaped, never blurred.
	var mat := _mat(Color("193c3e"), true)
	_box(pos,Vector3(size,0.008,size*0.28),mat,parent)
	_box(pos,Vector3(size*0.7,0.009,size*0.55),mat,parent)

func _outline(col: Color, size: float) -> Node3D:
	var root := Node3D.new()
	var mat := _mat(col, true)
	for sign_value in [-1.0,1.0]:
		_box(Vector3(sign_value*size*0.5,0,0),Vector3(0.035,0.025,size),mat,root)
		_box(Vector3(0,0,sign_value*size*0.5),Vector3(size,0.025,0.035),mat,root)
	return root

func set_selected(team_index: int) -> void:
	selected_index = team_index

func set_hover(cell: Vector2i, valid: bool) -> void:
	hover_cell = cell
	if not is_instance_valid(_hover): return
	_hover.visible = cell.x >= 0 and cell.y >= 0 and cell.x < sim.width and cell.y < sim.height
	if _hover.visible:
		_hover.position = _world(Vector2(cell),_height(cell)+0.10)
		for part in _hover.get_children():
			part.material_override.albedo_color = Color("fee761") if valid else Color("e43b44")

func screen_to_cell(viewport_pos: Vector2) -> Vector2i:
	if not is_instance_valid(camera): return Vector2i(-1,-1)
	var origin := camera.project_ray_origin(viewport_pos)
	var direction := camera.project_ray_normal(viewport_pos)
	var best_distance := INF
	var result := Vector2i(-1,-1)
	for y in range(sim.height):
		for x in range(sim.width):
			var c := Vector2i(x,y)
			var h := _height(c)+0.055
			if absf(direction.y)<0.0001: continue
			var distance := (h-origin.y)/direction.y
			if distance < 0.0 or distance >= best_distance: continue
			var hit := origin+direction*distance
			var center := _world(Vector2(c),h)
			if absf(hit.x-center.x)<=0.5 and absf(hit.z-center.z)<=0.5:
				best_distance = distance
				result = c
	return result

func _make_actor(key: String, id: String, enemy: bool) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var sprite := _sprite(id,0.048 if id != "mianmian" else 0.055)
	sprite.position.y = 0.64 if id != "mianmian" else 0.86
	root.add_child(sprite)
	_shadow(Vector3(0,0.07,0),0.62 if id != "mianmian" else 0.95,root)
	var bar := Sprite3D.new()
	bar.pixel_size = 0.035
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bar.position.y = 1.35 if id != "mianmian" else 1.95
	root.add_child(bar)
	var selection := _outline(Color("fee761"),0.83)
	selection.position.y = 0.09
	selection.visible = false
	root.add_child(selection)
	var data := {"root":root,"sprite":sprite,"bar":bar,"selection":selection,"enemy":enemy}
	_actors[key] = data
	return data

func _bar_texture(hp: float, maximum: float, enemy: bool) -> Texture2D:
	var amount := clampi(int(14.0*hp/maxf(maximum,0.01)),0,14)
	var key := "%s:%s" % [amount,enemy]
	if _bar_cache.has(key): return _bar_cache[key]
	var im := Image.create(16,3,false,Image.FORMAT_RGBA8)
	im.fill(Color("181425"))
	for x in range(1,15):
		im.set_pixel(x,1,Color("b55088") if enemy and x<=amount else Color("63c74d") if x<=amount else Color("3a4466"))
	var texture := ImageTexture.create_from_image(im)
	_bar_cache[key] = texture
	return texture

func refresh(delta: float) -> void:
	if sim == null: return
	_clock += delta
	var alive_keys: Dictionary = {}
	for u in sim.units:
		var key := "u%d" % int(u.team_index)
		alive_keys[key] = true
		var data: Dictionary = _actors.get(key,{})
		if data.is_empty(): data = _make_actor(key,str(u.id),false)
		var cell: Vector2i = u.cell
		data.root.position = _world(Vector2(cell),_height(cell))
		_update_actor(data,u)
		data.selection.visible = int(u.team_index)==selected_index
	for e in sim.enemies:
		var key := "e%d" % int(e.uid)
		alive_keys[key] = true
		var data: Dictionary = _actors.get(key,{})
		if data.is_empty(): data = _make_actor(key,str(e.id),true)
		var p: Vector2 = e.pos
		var cell := Vector2i(roundi(p.x),roundi(p.y))
		data.root.position = _world(p,_height(cell)+(0.34 if str(e.id)=="fly" else 0.0))
		_update_actor(data,e)
	for key in _actors.keys():
		if not alive_keys.has(key):
			_actors[key].root.queue_free()
			_actors.erase(key)
	for event in sim.events: _event_fx(event)
	sim.events.clear()
	_update_effects(delta)
	if is_instance_valid(_heart_sprite):
		_heart_sprite.texture = PixelArt.texture("heart","idle",int(_clock*4.0)%4)
	if sim.finished and sim.victory:
		if _clean_time<0.0: _clean_time=0.0
		_clean_time += delta
		for i in range(_tile_meshes.size()):
			var c := Vector2i(i%sim.width,i/sim.width)
			if Vector2(c).distance_to(Vector2(sim.heart))<_clean_time*3.4:
				_tile_meshes[i].material_override=_clean_materials[i]
	_path_clock += delta
	if _path_clock>0.22 or delta==0.0:
		_path_clock=0.0
		_refresh_paths()

func _update_actor(data: Dictionary, actor: Dictionary) -> void:
	var state := str(actor.get("state","idle"))
	var elapsed := float(actor.get("anim_time",_clock))
	var frame := mini(int(elapsed*10.0),PixelArt.frame_count(state)-1) if state=="attack" else int(elapsed*5.0)%maxi(PixelArt.frame_count(state),1)
	data.sprite.texture = PixelArt.texture(str(actor.id),state,frame,bool(actor.get("evolved",false)),int(actor.get("moss",3)))
	data.bar.texture = _bar_texture(float(actor.hp),float(actor.max_hp),bool(data.enemy))
	data.bar.visible = float(actor.hp)<float(actor.max_hp) or bool(data.enemy)
	if actor.has("facing"):
		var facing = actor.facing
		if facing is Vector2: data.sprite.flip_h = facing.x<0.0

func _refresh_paths() -> void:
	if not is_instance_valid(_paths_root): return
	for child in _paths_root.get_children(): child.queue_free()
	if sim.running and hover_cell.x<0: return
	if sim.finished: return
	# Small pale pebbles indicate a live prediction only while arranging/hovering.
	var material := _mat(Color("c0cbdc"),true)
	for path in sim.paths():
		for c in path:
			var cell: Vector2i = c
			_box(_world(Vector2(cell),_height(cell)+0.065),Vector3(0.11,0.012,0.11),material,_paths_root)

func _event_fx(event: Dictionary) -> void:
	var kind := str(event.get("type",""))
	if kind not in ["attack","impact","dew","heart","skill","heal"]: return
	var from: Vector2 = event.get("from",Vector2(sim.heart))
	var to: Vector2 = event.get("to",from)
	var element := str(event.get("kind","water"))
	if kind == "attack":
		for u in sim.units:
			if Vector2(u.cell).distance_to(from)<0.1:
				var key := "u%d" % int(u.team_index)
				if _actors.has(key):
					var a_screen := camera.unproject_position(_world(from))
					var b_screen := camera.unproject_position(_world(to))
					_actors[key].sprite.flip_h = b_screen.x<a_screen.x
	var color := Color("2ce8f5")
	match element:
		"warm","fire","dengxin": color=Color("feae34")
		"moss","taituan","yaya": color=Color("63c74d")
		"light","yingzi","lantern": color=Color("fee761")
		"steam","chayan": color=Color("c0cbdc")
		"murk": color=Color("b55088")
	if kind=="heart": color=Color("e43b44")
	var root := Node3D.new()
	add_child(root)
	var material := _mat(color,true)
	_box(Vector3.ZERO,Vector3(0.13,0.13,0.13),material,root)
	if kind != "attack":
		for d in [Vector3(0.16,0,0),Vector3(-0.16,0,0),Vector3(0,0.16,0)]:
			_box(d,Vector3(0.08,0.08,0.08),material,root)
	var a := _world(from,_height(Vector2i(from))+0.7)
	var b := _world(to,_height(Vector2i(to))+0.55)
	root.position=a
	_effects.append({"node":root,"a":a,"b":b,"age":0.0,"duration":0.24 if kind=="attack" else 0.45,"projectile":kind=="attack"})

func _update_effects(delta: float) -> void:
	for i in range(_effects.size()-1,-1,-1):
		var fx: Dictionary = _effects[i]
		fx.age += delta
		var t := minf(float(fx.age)/float(fx.duration),1.0)
		if bool(fx.projectile):
			fx.node.position = Vector3(fx.a).lerp(Vector3(fx.b),t)+Vector3(0,sin(t*PI)*0.35,0)
		else:
			fx.node.position=Vector3(fx.b)+Vector3(0,t*0.5,0)
		if t>=1.0:
			fx.node.queue_free()
			_effects.remove_at(i)
