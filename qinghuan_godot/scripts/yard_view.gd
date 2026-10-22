class_name YardView
extends Node3D
var lights: Array = []
var clock: float = 0.0
func setup(inherited: String,oil: int) -> void:
	var environment = WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("181425")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("c0cbdc")
	env.ambient_light_energy=0.7
	environment.environment=env
	add_child(environment)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-30,0)
	sun.light_color=Color("ead4aa")
	sun.light_energy=1.3
	add_child(sun)
	var camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=12.8
	camera.position=Vector3(8,9,12)
	add_child(camera)
	camera.look_at(Vector3(0,0.4,0))
	camera.current=true
	_box(Vector3(0,-0.5,0),Vector3(9,0.8,6.5),"733e39")
	_box(Vector3(0,-0.06,0),Vector3(9.2,0.15,6.7),"3e8948")
	_box(Vector3(0,0.03,0.7),Vector3(2.0,0.12,4.6),"b86f50")
	_box(Vector3(-2.3,1.0,-1.3),Vector3(3.0,2.0,2.0),"ead4aa")
	_box(Vector3(-2.3,2.1,-1.3),Vector3(3.7,0.3,2.5),"733e39")
	_box(Vector3(-2.3,2.4,-1.3),Vector3(3.1,0.3,2.0),"b86f50")
	_box(Vector3(-2.3,2.7,-1.3),Vector3(2.4,0.3,1.5),"d77643")
	_box(Vector3(-2.0,0.65,-0.27),Vector3(0.65,1.3,0.05),"3e2731")
	_box(Vector3(-3.1,1.3,-0.26),Vector3(0.55,0.55,0.06),"fee761")
	_box(Vector3(-1.4,1.3,-0.26),Vector3(0.55,0.55,0.06),"fee761")
	_sprite("tree",Vector3(2.4,0.03,-1.7),0.11)
	_sprite("tree",Vector3(-4.0,0.03,1.5),0.08)
	_sprite("tree",Vector3(3.8,0.03,1.6),0.08)
	_sprite("heart",Vector3(2.4,0.6,-1.4),0.065+oil*0.004)
	var ids=["dida","taituan","dengxin"]
	if inherited!="" and not inherited in ids: ids.append(inherited)
	for i in ids.size():
		var s=_sprite(ids[i],Vector3(-1.3+i*1.0,0.12,1.5),0.055)
		lights.append({"sprite":s,"id":ids[i]})
	for i in 7:
		_box(Vector3(-4.0+i*1.3,0.4,3.15),Vector3(0.13,0.8,0.13),"b86f50")
	_box(Vector3(0,0.55,3.15),Vector3(8.3,0.1,0.1),"ead4aa")
	for i in 45:
		var star=MeshInstance3D.new()
		var mesh=BoxMesh.new()
		mesh.size=Vector3.ONE*(0.035 if i%3 else 0.065)
		star.mesh=mesh
		var mat=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color("c0cbdc")
		star.material_override=mat
		star.position=Vector3(sin(i*17.0)*12.0,3.0+fmod(i*2.31,8.0),-7.0-fmod(i*1.17,7.0))
		add_child(star)
func _box(pos: Vector3,dimensions: Vector3,color: String) -> void:
	var object=MeshInstance3D.new()
	var mesh=BoxMesh.new()
	mesh.size=dimensions
	object.mesh=mesh
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Color(color)
	mat.roughness=1.0
	object.material_override=mat
	object.position=pos
	add_child(object)
func _sprite(id: String,pos: Vector3,pixel_size: float) -> Sprite3D:
	var sprite=Sprite3D.new()
	sprite.texture=PixelArt.texture(id)
	sprite.pixel_size=pixel_size
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test=false
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.position=pos+Vector3.UP*float(sprite.texture.get_height())*pixel_size/2
	add_child(sprite)
	return sprite
func _process(delta: float) -> void:
	clock+=delta
	for entry in lights: entry.sprite.texture=PixelArt.texture(entry.id,"idle",int(clock*4)%PixelArt.frame_count("idle"))
