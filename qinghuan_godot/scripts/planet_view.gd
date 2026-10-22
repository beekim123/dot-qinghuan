class_name PlanetView
extends Node3D
## World map only. All positions stay attached to the same seeded model on rotation.
signal cell_selected(cell: int)
const RADIUS: float = 2.0
const BIOME_COLORS: Dictionary = {"grass":Color("63c74d"),"forest":Color("3e8948"),"lake":Color("0099db"),"water":Color("124e89"),"sand":Color("ead4aa"),"mountain":Color("8b9bb4"),"snow":Color("c0cbdc")}
var model: PlanetModel
var camera: Camera3D
var globe: Node3D
var surface: MeshInstance3D
var candidates: Array = []
var selected_cell: int = -1
var _markers: Array = []
var _target_rotation := Quaternion.IDENTITY
var _focusing: bool = false
var _time: float = 0.0
var _marker_cache: Dictionary = {}
var _marker_phase: int = -1
var _selection: MeshInstance3D

func setup(value: PlanetModel) -> void:
	model = value
	if globe == null:
		_build_scene()
	refresh()
	focus_cell(model.landing)

func _build_scene() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("181425")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c0cbdc")
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.15
	camera.position = Vector3(0,0,8)
	camera.current = true
	add_child(camera)
	globe = Node3D.new()
	add_child(globe)
	surface = MeshInstance3D.new()
	globe.add_child(surface)
	_selection = MeshInstance3D.new()
	globe.add_child(_selection)
	var stars := SurfaceTool.new()
	stars.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 64872
	for i in range(58):
		var x: float = rng.randf_range(-7.0,7.0)
		var y: float = rng.randf_range(-4.0,4.0)
		var size: float = 0.014 if i%4 else 0.027
		stars.set_color(Color("5a6988") if i%3 else Color("c0cbdc"))
		for p in [Vector3(x-size,y-size,-4),Vector3(x+size,y-size,-4),Vector3(x+size,y+size,-4),Vector3(x-size,y-size,-4),Vector3(x+size,y+size,-4),Vector3(x-size,y+size,-4)]:
			stars.add_vertex(p)
	var star_mesh := MeshInstance3D.new()
	star_mesh.mesh = stars.commit()
	star_mesh.material_override = _vertex_material()
	add_child(star_mesh)

func _vertex_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func refresh() -> void:
	if globe == null or model == null:
		return
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in model.cells.size():
		var c: Dictionary = model.cells[index]
		var radius: float = _cell_radius(c)
		var color: Color = BIOME_COLORS.get(c.biome,Color("63c74d"))
		if not c.clear:
			color = color.lerp(Color("5a6988"),0.62)
		var n: Vector3 = c.dir
		# Broad discrete light bands retain small cell silhouettes at native resolution.
		var light: float = n.dot(Vector3(-0.5,0.7,0.6).normalized())
		var brightness: float = 1.08 if light > 0.55 else (0.9 if light > 0.0 else (0.71 if light > -0.5 else 0.55))
		color = Color(color.r*brightness,color.g*brightness,color.b*brightness)
		var corners: Array = c.corners
		for k in corners.size():
			var a: Vector3 = (corners[k] as Vector3).slerp(n,0.018).normalized()
			var b: Vector3 = (corners[(k+1)%corners.size()] as Vector3).slerp(n,0.018).normalized()
			_emit(mesh,n*radius,a*radius,b*radius,color)
			var side: Color = color.darkened(0.24)
			_emit(mesh,a*radius,a*(RADIUS-0.025),b*radius,side)
			_emit(mesh,b*radius,a*(RADIUS-0.025),b*(RADIUS-0.025),side)
		if c.clear and c.biome in ["grass","forest"] and index % 3 == 0:
			# Small tapered two-tone sprouts, not generic sphere trees.
			var tangent: Vector3 = n.cross(Vector3.UP).normalized()
			if tangent.length_squared() < 0.01:
				tangent = Vector3.RIGHT
			var p: Vector3 = n*(radius+0.005)
			_emit(mesh,p-tangent*0.045,p+n*0.11,p+tangent*0.04,Color("265c42"))
			_emit(mesh,p,p+n*0.11,p+tangent*0.04,Color("63c74d"))
	surface.mesh = mesh.commit()
	surface.material_override = _vertex_material()
	_rebuild_markers()
	_draw_selection()

func _cell_radius(c: Dictionary) -> float:
	return RADIUS + (0.075 if c.biome == "mountain" else (0.11 if c.biome == "snow" else (0.015 if c.biome in ["water","lake"] else 0.035)))

func _emit(mesh: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	mesh.set_color(color)
	mesh.add_vertex(a)
	mesh.add_vertex(b)
	mesh.add_vertex(c)

func set_candidates(value: Array) -> void:
	candidates = value.duplicate(true)
	_rebuild_markers()

func _rebuild_markers() -> void:
	if globe == null:
		return
	for entry in _markers:
		entry.sprite.queue_free()
	_markers.clear()
	for i in model.springs.size():
		var spring: Dictionary = model.springs[i]
		_add_marker(spring.cell,"sealed" if spring.sealed else "spring",i)
	for i in candidates.size():
		var candidate: Dictionary = candidates[i]
		_add_marker(candidate.cell,str(candidate.type),i)

func _add_marker(index: int,kind: String,number: int) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _marker_texture(kind,number,0)
	sprite.pixel_size = 0.017
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.position = model.cells[index].dir * (_cell_radius(model.cells[index])+0.15)
	globe.add_child(sprite)
	_markers.append({"sprite":sprite,"cell":index,"kind":kind,"number":number})

func _marker_texture(kind: String,number: int,phase: int) -> Texture2D:
	var cache_key: String = kind + str(phase)
	if _marker_cache.has(cache_key):
		return _marker_cache[cache_key]
	var image := Image.create(19,23,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var foreground := Color("fee761")
	if kind in ["rest","spring_rest"]:
		foreground = Color("2ce8f5")
	elif kind == "shop":
		foreground = Color("ead4aa")
	elif kind in ["spring","boss","mianmian"]:
		foreground = Color("b55088")
	elif kind == "sealed":
		foreground = Color("63c74d")
	# Square framed charms have a clear point anchoring them to their surface cell.
	for y in range(3,19):
		for x in range(2,17):
			if (x in [2,16] and y in [3,18]):
				continue
			image.set_pixel(x,y,Color("181425") if x in [2,16] or y in [3,18] else Color("262b44"))
	for y in range(19,22):
		for x in range(9-(21-y),10+(21-y)):
			image.set_pixel(x,y,foreground)
	for x in range(4,15):
		image.set_pixel(x,4,foreground)
	var pattern: Array
	match kind:
		"rest", "spring_rest": pattern = ["...x...","..xxx..","..xxx..",".xxxxx.","xxxxxxx","xxxxxxx",".xxxxx."]
		"shop": pattern = [".xxxxx.","xx...xx","xxxxxxx","x.x.x.x","xxxxxxx",".x...x.",".xxxxx."]
		"spring", "boss", "mianmian": pattern = [".xxxxx.","xx...xx","x.xxx.x","x.x...x","x.xxx.x","xx...xx",".xxxxx."]
		"sealed": pattern = [".....xx","....xx.","x..xx..","xxxx...",".xx....",".......","..xxx.."]
		_: pattern = ["...x...","..xxx..","..x.x..",".xxxxx.",".xxxxx.","..xxx..","..xxx.."]
	for y in pattern.size():
		for x in pattern[y].length():
			if pattern[y][x] == "x":
				var pixel := Vector2i(x,y)
				if kind in ["spring","boss","mianmian"]:
					for _turn in range(phase % 4):
						pixel = Vector2i(6-pixel.y,pixel.x)
				image.set_pixel(pixel.x+6,pixel.y+8,foreground)
	var texture := ImageTexture.create_from_image(image)
	_marker_cache[cache_key] = texture
	return texture

func handle_drag(delta: Vector2) -> void:
	if globe == null:
		return
	_focusing = false
	var qx := Quaternion(Vector3.UP,delta.x*0.012)
	var qy := Quaternion(Vector3.RIGHT,delta.y*0.012)
	globe.quaternion = (qx*qy*globe.quaternion).normalized()

func focus_cell(index: int) -> void:
	if model == null or index < 0 or index >= model.cells.size():
		return
	selected_cell = index
	var direction: Vector3 = globe.quaternion * (model.cells[index].dir as Vector3)
	_target_rotation = (Quaternion(direction,Vector3.FORWARD*-1.0)*globe.quaternion).normalized()
	_focusing = true
	_draw_selection()

func _draw_selection() -> void:
	if selected_cell < 0 or _selection == null:
		return
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_LINES)
	for index in model.region(selected_cell,2):
		var c: Dictionary = model.cells[index]
		for k in c.corners.size():
			mesh.set_color(Color("fee761") if index == selected_cell else Color("ead4aa").darkened(0.25))
			mesh.add_vertex(c.corners[k]*(_cell_radius(c)+0.007))
			mesh.add_vertex(c.corners[(k+1)%c.corners.size()]*(_cell_radius(c)+0.007))
	_selection.mesh = mesh.commit()
	_selection.material_override = _vertex_material()

func is_front(index: int) -> bool:
	if camera == null or model == null:
		return false
	var d: Vector3 = globe.global_basis * (model.cells[index].dir as Vector3)
	var p: Vector3 = globe.global_position+d*RADIUS
	return d.dot((camera.global_position-p).normalized()) > 0.12

func pick(screen_pos: Vector2) -> int:
	var best: int = -1
	var distance: float = 14.0
	for candidate in candidates:
		var index: int = candidate.cell
		if not is_front(index):
			continue
		var p: Vector3 = globe.to_global(model.cells[index].dir*(_cell_radius(model.cells[index])+0.15))
		var d: float = camera.unproject_position(p).distance_to(screen_pos)
		if d < distance:
			distance = d
			best = index
	if best >= 0:
		cell_selected.emit(best)
	return best

func _process(delta: float) -> void:
	_time += delta
	if globe == null:
		return
	if _focusing:
		globe.quaternion = globe.quaternion.slerp(_target_rotation,1.0-exp(-delta*9.0))
		if globe.quaternion.angle_to(_target_rotation) < 0.003:
			globe.quaternion = _target_rotation
			_focusing = false
	var phase: int = int(_time*3.0)%4
	for marker in _markers:
		if phase != _marker_phase and marker.kind in ["spring","boss","mianmian"]:
			marker.sprite.texture = _marker_texture(marker.kind,marker.number,phase)
		marker.sprite.visible = is_front(marker.cell)
		marker.sprite.modulate = Color.WHITE if marker.kind == "sealed" else Color(1,1,1,0.88+0.12*sin(_time*2.0+marker.number))

	_marker_phase = phase
