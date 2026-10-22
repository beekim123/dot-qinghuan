extends SceneTree
const Art = preload("res://scripts/pixel_art.gd")
func _init() -> void:
 var checks := 0
 for id in Art.IDS + ["fly","big"]:
  for evolved in [false,true]:
   for state in ["idle","attack","move","hit","sleep"]:
    for f in Art.frame_count(state):
     var im: Image = Art.render_image(id,state,f,evolved)
     assert(im.get_width() in [24,32])
     assert(not im.is_invisible(),"Empty sprite: " + id)
     checks += 1
 for id in ["dida","taituan","dengxin","chayan","yingzi","yaya","piaopiao"]:
  assert(Art.render_image(id,"idle",0).get_data() != Art.render_image(id,"idle",3).get_data(),"Idle is static: " + id)
  assert(Art.render_image(id,"attack",0).get_data() != Art.render_image(id,"attack",1).get_data(),"Attack lacks anticipation/release: " + id)
  assert(Art.render_image(id,"idle",0,false).get_data() != Art.render_image(id,"idle",0,true).get_data(),"Evolution looks identical: " + id)
  assert(Art.render_image(id,"move",0).get_data() != Art.render_image(id,"move",1).get_data(),"Movement is static: " + id)
 assert(Art.render_image("mianmian","idle",0,false,3).get_data() != Art.render_image("mianmian","idle",0,false,0).get_data(),"Moss not removed visually")
 print("ART PASS: ",checks," nonempty indexed frames; seven local idle/attack/evolution differences")
 quit()
