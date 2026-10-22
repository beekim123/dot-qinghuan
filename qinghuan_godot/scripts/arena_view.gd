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
const Decor = preload("res://scripts/arena_decor.gd")

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
	env.background_color = Color("181f2e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8b9bb4")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("e8b796")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.1
	camera.position = Vector3(7.8, 16.65, 16.2)
	add_child(camera)
	camera.look_at(Vector3(0, 0.15, 0))
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
		"water": return Color("124e89").lerp(Color("0099db"),0.62)
		"deep": return Color("124e89")
		"sand": return Color("ead4aa")
		"high": return Color("8b9bb4")
		"snow": return Color("c0cbdc")
	return Color("63c74d")

func _tile_texture(terrain: String, clean: bool, cell: Vector2i = Vector2i.ZERO) -> ImageTexture:
	var im := Image.create(32,32,false,Image.FORMAT_RGBA8)
	var base := _tile_color(terrain)
	if terrain in ["grass","forest"]:
		base = Color("3e8948").lerp(Color("63c74d"),0.27 if terrain=="grass" else 0.08)
	if not clean: base = base.lerp(Color("5a6988"),0.18)
	im.fill(base)
	# Continuous world-space patches cross cells; no checkerboard or random confetti.
	for y in range(32):
		for x in range(32):
			var gx := cell.x*32+x
			var gy := cell.y*32+y
			var bands := sin(float(gx)*0.038+sin(float(gy)*0.046)*1.5)+cos(float(gy)*0.034+0.6)
			var col := base
			if terrain in ["grass","forest"]:
				if bands>1.14: col=base.lerp(Color("265c42"),0.32)
				elif bands< -0.8: col=base.lerp(Color("63c74d"),0.24)
				# Connected russet earth clearing, avoiding route-shaped decoration.
				var r := pow((float(gx)-176.0)/87.0,2)+pow((float(gy)-116.0)/69.0,2)
				if r<0.65+0.12*sin(float(gx/4)*0.34): col=base.lerp(Color("b86f50"),0.37)
			elif terrain in ["water","deep"]:
				col=base.lerp(Color("124e89"),0.2 if bands>0 else 0.0)
				if (gy%15 in [3,4]) and gx%29 in range(6,17): col=Color("2ce8f5").lerp(base,0.68)
			elif terrain=="sand":
				if bands>0.8: col=base.lerp(Color("d77643"),0.16)
			elif terrain=="high":
				if y in [9,10] and x<20 or x in [20,21] and y<10: col=base.darkened(0.22)
			im.set_pixel(x,y,col)
	# Sparse corner notches are much quieter than dashed permanent grid lines.
	if terrain not in ["water","deep"]:
		var cue := base.darkened(0.09)
		im.fill_rect(Rect2i(0,0,3,1),cue);im.fill_rect(Rect2i(0,0,1,3),cue)
	return ImageTexture.create_from_image(im)

func _build_terrain() -> void:
	_build_island()
	for y in range(sim.height):
		for x in range(sim.width):
			var cell := Vector2i(x, y)
			var t: Dictionary = sim.tiles[y * sim.width + x]
			var terrain := str(t.get("terrain", "grass"))
			var h := _height(cell)
			var position3 := _world(Vector2(cell), h)
			var sides := _mat(Color("733e39") if terrain != "high" else Color("5a6988"))
			_box(position3 + Vector3(0, -(h + 0.6) * 0.5, 0), Vector3(1.0, h + 0.6, 1.0), sides, _terrain_root)
			var dirty := _mat(Color.WHITE)
			dirty.albedo_texture = _tile_texture(terrain, false,cell)
			dirty.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var clean := _mat(Color.WHITE)
			clean.albedo_texture = _tile_texture(terrain, true,cell)
			clean.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var top := _box(position3 + Vector3(0,0.025,0), Vector3(1.001,0.05,1.001), dirty, _terrain_root)
			_tile_meshes.append(top)
			_dirty_materials.append(dirty)
			_clean_materials.append(clean)
			if str(t.get("obstacle", "")) != "":
				var obstacle := _sprite(str(t.obstacle), 0.052)
				obstacle.position = position3 + camera.global_basis.y * ((9.5 if str(t.obstacle)=="tree" else 8.5)*0.052)
				_terrain_root.add_child(obstacle)
				_shadow(position3 + Vector3(0,0.058,0), 0.65, _terrain_root)
			if terrain in ["water","deep"]: _shore(cell,position3)
			if terrain=="high":
				_box(position3+Vector3(0,-0.05,0),Vector3(1.02,0.08,1.02),_mat(Color("c0cbdc")),_terrain_root)
			if bool(t.get("dew", false)):
				# Dew eyes are small spring ripples, never neon square pads.
				for j in range(3):
					_box(position3+Vector3(0,0.058,float(j-1)*0.13),Vector3(0.40-abs(j-1)*0.12,0.008,0.035),_mat(Color("2ce8f5"),true),_terrain_root)

	for entrance in sim.entrances:
		var c: Vector2i = entrance
		var root := _entrance_mark()
		root.position = _world(Vector2(c), _height(c) + 0.08)
		_terrain_root.add_child(root)
		# Stepped inward arrow, not a permanent lane.
		var inward := (Vector2(sim.heart) - Vector2(c)).normalized()
		var a := _world(Vector2(c), _height(c) + 0.1)
		for k in range(3):
			_box(a + Vector3(inward.x,0,inward.y) * (float(k)-1.0) * 0.13, Vector3(0.34-float(k)*0.08,0.04,0.10), _mat(Color("b55088"),true),_terrain_root)
	var heart_pos := _world(Vector2(sim.heart),_height(sim.heart))
	_box(heart_pos+Vector3(0,0.06,0),Vector3(0.72,0.12,0.72),_mat(Color("d77643")),_terrain_root)
	_heart_sprite = _sprite("heart", 0.045)
	_heart_sprite.position = heart_pos + Vector3(0,0.12,0) + camera.global_basis.y * (10.5*0.045)
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
	var sprite := _sprite(id,0.054 if id != "mianmian" else 0.065)
	var foot := 8.5 if id in ["mianmian","spring"] else 7.5 if id=="murk" else 8.5 if id=="big" else 10.5
	sprite.position = camera.global_basis.y * (foot*sprite.pixel_size) + Vector3(0,0.06,0)
	root.add_child(sprite)
	_shadow(Vector3(0,0.07,0),0.62 if id != "mianmian" else 0.95,root)
	var bar := Sprite3D.new()
	bar.pixel_size = 0.035
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bar.position.y = 1.18 if id != "mianmian" else 1.95
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
	if hover_cell.x<0: return
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

func _island_outline() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-6.2,-3.2),Vector2(-5.8,-4.1),Vector2(-4.7,-4.2),Vector2(-4.1,-4.65),
		Vector2(-2.7,-4.55),Vector2(-1.9,-4.85),Vector2(-0.4,-4.55),Vector2(0.8,-4.8),
		Vector2(2.0,-4.45),Vector2(3.4,-4.65),Vector2(4.6,-4.2),Vector2(5.8,-3.9),
		Vector2(6.1,-2.9),Vector2(6.65,-2.2),Vector2(6.45,-0.8),Vector2(6.8,0.1),
		Vector2(6.25,1.2),Vector2(6.45,2.45),Vector2(5.85,3.55),Vector2(4.8,4.05),
		Vector2(3.7,4.4),Vector2(2.5,4.15),Vector2(1.4,4.55),Vector2(0.3,4.2),
		Vector2(-1.0,4.4),Vector2(-2.1,4.15),Vector2(-3.3,4.55),Vector2(-4.6,4.1),
		Vector2(-5.7,3.7),Vector2(-6.35,2.7),Vector2(-6.2,1.45),Vector2(-6.65,0.4),
		Vector2(-6.25,-0.7),Vector2(-6.5,-1.8)])

func _island_layer(points: PackedVector2Array, top: float, bottom: float, scale_bottom: float, top_color: Color, side_color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for i in range(0,indices.size(),3):
		for k in [0,2,1]:
			var p := points[indices[i+k]]
			st.set_normal(Vector3.UP);st.set_color(top_color);st.add_vertex(Vector3(p.x,top,p.y))
	for i in range(points.size()):
		var p := points[i]
		var q := points[(i+1)%points.size()]
		var a := Vector3(p.x,top,p.y)
		var b := Vector3(q.x,top,q.y)
		var c := Vector3(q.x*scale_bottom,bottom,q.y*scale_bottom)
		var d := Vector3(p.x*scale_bottom,bottom,p.y*scale_bottom)
		var normal := (b-a).cross(d-a).normalized()
		var col := side_color.lightened(0.06 if i%4==0 else 0.0)
		for v in [a,b,c,a,c,d]:
			st.set_normal(normal);st.set_color(col);st.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.mesh=st.commit()
	var mat := _mat(Color.WHITE)
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=mat
	_terrain_root.add_child(mesh)

func _build_island() -> void:
	var points := _island_outline()
	var is_forest := sim.biome in ["forest","grass"]
	var soil := Color("3e8948") if is_forest else Color("d77643") if sim.biome=="sand" else Color("5a6988")
	_island_layer(points,-0.035,-0.26,0.992,soil,Color("265c42") if is_forest else soil.darkened(0.25))
	_island_layer(points,-0.26,-0.72,0.98,Color("733e39"),Color("733e39"))
	var inset := PackedVector2Array()
	for p in points: inset.append(p*0.98)
	_island_layer(inset,-0.72,-1.06,0.97,Color("3e2731"),Color("3e2731"))
	var rockline := PackedVector2Array()
	for p in points: rockline.append(p*0.95)
	_island_layer(rockline,-1.06,-1.45,0.94,Color("3a4466"),Color("262b44"))
	# Roots, stone shelves and hanging moss break the regular cliff silhouette.
	for i in range(0,points.size(),2):
		var p := points[i]
		var q := points[(i+1)%points.size()]
		var c := (p+q)*0.5
		var rock := _box(Vector3(c.x,-0.88,c.y),Vector3(0.48+float(i%3)*0.12,0.16,0.28),_mat(Color("5a6988")),_terrain_root)
		rock.rotation.y=atan2(q.y-p.y,q.x-p.x)
		if is_forest and i%4==0:
			_box(Vector3(c.x,-0.28,c.y),Vector3(0.13,0.56,0.14),_mat(Color("265c42")),_terrain_root)
			_box(Vector3(c.x+0.11,-0.53,c.y+0.04),Vector3(0.13,0.31,0.12),_mat(Color("193c3e")),_terrain_root)
	if is_forest:
		for spec in [[-5.85,-3.4,0.052],[-4.1,-4.5,0.047],[-1.85,-4.75,0.056],[1.5,-4.7,0.047],[4.5,-4.1,0.052],[6.35,-2.85,0.046]]:
			_decor_sprite("tree",Vector3(spec[0],0.0,spec[1]),float(spec[2])*0.90,int(absf(spec[0])*2)%2)
		for spec in [[-5.8,2.8],[-5.95,-0.7],[-3.8,3.95],[-2.4,-4.05],[3.7,3.9],[5.9,1.8],[5.7,-3.2]]:
			_decor_sprite("fern",Vector3(spec[0],0.02,spec[1]),0.027)
		for spec in [[-4.7,-4.0],[3.6,-4.2],[-5.7,1.9],[4.9,3.6]]:
			_decor_sprite("mushroom",Vector3(spec[0],0.02,spec[1]),0.020)
		for spec in [[-1.2,3.9],[2.3,3.9],[-5.9,-2.5],[5.8,-0.8]]:
			_decor_sprite("flowers",Vector3(spec[0],0.02,spec[1]),0.019)
	# Low ferns and shore stones never occupy a legal playable tile.
	for x in range(-5,6,2):
		_decor_sprite("grass",Vector3(float(x)+0.2,0.01,3.95),0.024)
	if sim.biome in ["forest","lake","grass"]: _outside_pool()

func _decor_sprite(kind:String,pos:Vector3,pixel:float,variant:int=0)->void:
	if kind=="tree":
		# Explicit screen-space canopy safety, independent of world/root depth.
		for attempt in range(50):
			var projected_top := camera.unproject_position(pos+camera.global_basis.y*(53.5*pixel))
			if projected_top.y>=10.0: break
			pixel*=0.94
	var sprite := Sprite3D.new()
	sprite.texture=Decor.texture(kind,variant)
	sprite.pixel_size=pixel
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded=false
	# Source y=53 is the foot; billboard foreshortening compensation keeps it grounded.
	sprite.position=pos+camera.global_basis.y*(25.5*pixel)
	_terrain_root.add_child(sprite)
	if kind=="tree":
		var canopy_top := camera.unproject_position(sprite.global_position+camera.global_basis.y*(28.0*pixel)).y
		sprite.set_meta("canopy_top",canopy_top)
		assert(canopy_top>=8.0,"Decorative canopy must remain inside viewport")
	_shadow(pos+Vector3(0,0.012,0),0.75 if kind=="tree" else 0.3,_terrain_root)

func _outside_pool()->void:
	# A shallow side pocket outside x=-5.5: decorative shoreline, not a false deploy cell.
	var water := _mat(Color("124e89"))
	_box(Vector3(-6.0,-0.018,0.5),Vector3(0.7,0.025,1.8),water,_terrain_root)
	_box(Vector3(-5.85,-0.005,0.4),Vector3(0.52,0.025,1.35),_mat(Color("0099db")),_terrain_root)
	for i in range(4):
		_box(Vector3(-5.88,0.015,-0.1+float(i)*0.35),Vector3(0.30,0.008,0.028),_mat(Color("2ce8f5")),_terrain_root)
	for p in [Vector3(-5.67,0.04,-0.5),Vector3(-5.75,0.03,1.4),Vector3(-6.27,0.05,0.4)]:
		var stone := _sprite("rock",0.022)
		stone.position=p+camera.global_basis.y*(8.5*0.022)
		_terrain_root.add_child(stone)

func _shore(cell:Vector2i,pos:Vector3)->void:
	for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var other:Vector2i=cell+d
		if other.x<0 or other.x>=sim.width or other.y<0 or other.y>=sim.height: continue
		if str(sim.tiles[other.y*sim.width+other.x].terrain) not in ["water","deep"]:
			var bank := Color("265c42") if sim.biome in ["forest","grass"] else Color("e4a672")
			for j in range(4):
				var inset := 0.10+float((j+cell.x+cell.y)%3)*0.035
				var tangent := float(j)*0.24-0.36
				var width := Vector3(inset,0.05,0.245) if d.x!=0 else Vector3(0.245,0.05,inset)
				var shift := Vector3(d.x*(0.48-inset*0.5),0.063,d.y*(0.48-inset*0.5))
				shift += Vector3(0,0,tangent) if d.x!=0 else Vector3(tangent,0,0)
				_box(pos+shift,width,_mat(bank),_terrain_root)
				if j%2==0:
					_box(pos+shift+Vector3(-d.x*0.08,0.005,-d.y*0.08),Vector3(0.07,0.018,0.065),_mat(Color("8b9bb4")),_terrain_root)

	# Round each exposed pool corner into a stepped shallow bank.
	for corner in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
		var a := cell+Vector2i(corner.x,0)
		var b := cell+Vector2i(0,corner.y)
		var a_water := a.x>=0 and a.x<sim.width and a.y>=0 and a.y<sim.height and str(sim.tiles[a.y*sim.width+a.x].terrain) in ["water","deep"]
		var b_water := b.x>=0 and b.x<sim.width and b.y>=0 and b.y<sim.height and str(sim.tiles[b.y*sim.width+b.x].terrain) in ["water","deep"]
		if not a_water and not b_water:
			var bank := Color("265c42") if sim.biome in ["forest","grass"] else Color("e4a672")
			_box(pos+Vector3(corner.x*0.36,0.065,corner.y*0.36),Vector3(0.28,0.025,0.28),_mat(bank),_terrain_root)
			_box(pos+Vector3(corner.x*0.27,0.065,corner.y*0.43),Vector3(0.20,0.025,0.14),_mat(bank),_terrain_root)
			_box(pos+Vector3(corner.x*0.43,0.065,corner.y*0.27),Vector3(0.14,0.025,0.20),_mat(bank),_terrain_root)

func _entrance_mark()->Node3D:
	var root := Node3D.new()
	# Broken standing portal stones imply an arrival point without neon cell outlines.
	for x in [-0.30,0.30]:
		_box(Vector3(x,0.13,0),Vector3(0.12,0.24,0.20),_mat(Color("68386c")),root)
		_box(Vector3(x,0.26,0),Vector3(0.08,0.035,0.16),_mat(Color("b55088"),true),root)
	var im := Image.create(16,20,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	var rows := ["................",".......ww.......",".....wwBBw......","....wB..CBw.....","....wB...CBw....",".....wB...Bw....","......wBBCw.....",".....wBCCw......","....wBCCw.......","....wBCw........",".....wBw........","......ww........"]
	var colors := {"w":Color("5a6988"),"B":Color("68386c"),"C":Color("b55088")}
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x]!=".": im.set_pixel(x,y,colors[rows[y][x]])
	var wisp := Sprite3D.new()
	wisp.texture=ImageTexture.create_from_image(im)
	wisp.pixel_size=0.043
	wisp.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	wisp.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wisp.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	wisp.position=Vector3(0,0.22,0)+camera.global_basis.y*0.30
	root.add_child(wisp)
	return root
