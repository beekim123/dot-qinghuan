class_name ArenaDecor
extends RefCounted
## Authored pixel clusters for the forest diorama. No external artwork.
static var cache: Dictionary = {}
static func _rect(im: Image,x:int,y:int,w:int,h:int,c:Color) -> void:
	im.fill_rect(Rect2i(x,y,w,h).intersection(Rect2i(0,0,im.get_width(),im.get_height())),c)
static func _cluster(im:Image,cx:int,cy:int,rx:int,ry:int,c:Color) -> void:
	# Stepped 2-pixel scan bands, not smooth vector rasterization.
	for y in range(-ry,ry+1,2):
		var width := int(float(rx)*sqrt(maxf(0.0,1.0-pow(float(y)/maxi(ry,1),2))))
		width = maxi(2,(width/2)*2)
		_rect(im,cx-width,cy+y,width*2,2,c)
static func texture(kind:String,variant:int=0)->Texture2D:
	var key := "%s%d"%[kind,variant]
	if cache.has(key): return cache[key]
	var im := Image.create(48,56,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	var dark := Color("193c3e")
	var edge := Color("265c42")
	var mid := Color("3e8948")
	var light := Color("63c74d")
	if kind=="tree":
		# Crooked trunk, distinct branches and moss-footed roots.
		_rect(im,21,25,8,27,Color("3e2731"))
		_rect(im,23,25,4,25,Color("733e39"))
		_rect(im,23,30,2,16,Color("b86f50"))
		_rect(im,16,48,8,4,Color("3e2731")); _rect(im,27,49,9,3,Color("3e2731"))
		_rect(im,17,48,6,2,edge); _rect(im,28,49,6,2,edge)
		_rect(im,14,29,11,4,Color("3e2731")); _rect(im,29,23,9,4,Color("3e2731"))
		# Three asymmetrical canopy masses with stepped scalloped boundaries.
		_cluster(im,13,25,12,11,dark); _cluster(im,33,20,13,12,dark); _cluster(im,22,13,15,12,dark)
		_cluster(im,12,22,10,9,edge); _cluster(im,34,17,11,9,edge); _cluster(im,21,10,13,9,edge)
		_cluster(im,10,18,7,5,mid); _cluster(im,28,13,11,6,mid); _cluster(im,19,7,9,5,mid)
		_cluster(im,10,16,5,3,light); _cluster(im,18,5,6,3,light)
		for p in [Vector2i(5,22),Vector2i(12,28),Vector2i(27,23),Vector2i(34,18),Vector2i(24,9)]:
			_rect(im,p.x,p.y,5,2,mid)
		if variant%2==1:
			_cluster(im,35,29,8,6,dark);_cluster(im,34,26,7,5,edge);_rect(im,29,23,5,2,mid)
	elif kind=="fern":
		for pair in [[24,45,2,9],[17,42,6,3],[10,37,8,3],[4,32,8,3],[27,41,7,3],[33,35,8,3],[39,29,6,3]]:
			_rect(im,pair[0],pair[1],pair[2],pair[3],dark)
		for pair in [[23,36,2,17],[18,39,5,3],[12,34,7,3],[6,29,8,3],[26,38,6,3],[32,32,7,3],[38,26,6,3]]:
			_rect(im,pair[0],pair[1],pair[2],pair[3],mid)
		for pair in [[23,32,2,8],[12,33,5,1],[6,28,5,1],[32,31,5,1],[38,25,5,1]]:
			_rect(im,pair[0],pair[1],pair[2],pair[3],light)
	elif kind=="flowers":
		for p in [Vector2i(16,40),Vector2i(26,35),Vector2i(32,44)]:
			_rect(im,p.x,p.y,2,12,edge)
			_rect(im,p.x-2,p.y-2,6,5,Color("e8b796"))
			_rect(im,p.x,p.y-3,2,7,Color("ead4aa"));_rect(im,p.x,p.y,2,2,Color("feae34"))
	elif kind=="mushroom":
		_rect(im,15,38,4,14,Color("ead4aa"));_rect(im,31,42,3,10,Color("ead4aa"))
		_cluster(im,17,38,10,5,Color("733e39"));_cluster(im,17,35,9,4,Color("d77643"))
		_rect(im,12,33,5,2,Color("e4a672"));_rect(im,20,35,3,2,Color("ead4aa"))
		_cluster(im,33,42,7,4,Color("733e39"));_cluster(im,32,39,6,3,Color("d77643"))
	elif kind=="grass":
		for p in [Vector2i(12,47),Vector2i(20,42),Vector2i(26,45),Vector2i(32,48)]:
			_rect(im,p.x,p.y,2,54-p.y,edge);_rect(im,p.x-2,p.y-2,2,5,mid);_rect(im,p.x-3,p.y-3,2,2,light)
	var tex := ImageTexture.create_from_image(im)
	cache[key]=tex
	return tex
