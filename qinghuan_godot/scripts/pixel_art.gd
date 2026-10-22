class_name PixelArt
extends RefCounted
## Original indexed pixel artwork. Every mark is authored on the source pixel grid.
## Transparent padding uses a bottom-centred anchor. No file textures are loaded.
const PALETTE = {
 "a":"be4a2f", "b":"d77643", "c":"ead4aa", "d":"e4a672", "e":"b86f50", "f":"733e39", "g":"3e2731", "h":"a22633",
 "i":"e43b44", "j":"f77622", "k":"feae34", "l":"fee761", "m":"63c74d", "n":"3e8948", "o":"265c42", "p":"193c3e",
 "q":"124e89", "r":"0099db", "s":"2ce8f5", "t":"ffffff", "u":"c0cbdc", "v":"8b9bb4", "w":"5a6988", "x":"3a4466",
 "y":"262b44", "z":"181425", "A":"ff0044", "B":"68386c", "C":"b55088", "D":"f6757a", "E":"e8b796", "F":"c28569"
}
const IDS = ["dida","taituan","dengxin","chayan","yingzi","yaya","piaopiao","murk","fluff","shell","spring","mianmian","heart","tree","rock","lantern"]
static var _cache: Dictionary = {}

static func color(code: String) -> Color:
 return Color("#" + str(PALETTE.get(code,"ffffff"))) if code != "." else Color.TRANSPARENT

static func frame_count(state: String) -> int:
 match state:
  "attack": return 4
  "sleep": return 2
  "hit": return 2
  _: return 4

static func texture(id: String, state: String = "idle", frame: int = 0, evolved: bool = false, moss: int = 3) -> Texture2D:
 var key := "%s/%s/%d/%s/%d" % [id,state,posmod(frame,frame_count(state)),evolved,moss]
 if _cache.has(key): return _cache[key]
 var im := render_image(id,state,frame,evolved,moss)
 var result := ImageTexture.create_from_image(im)
 _cache[key] = result
 return result

static func render_image(id: String, state: String = "idle", frame: int = 0, evolved: bool = false, moss: int = 3) -> Image:
 if id == "fly": id = "fluff"
 if id == "big": id = "shell"
 assert(id in IDS, "Unknown authored sprite: " + id)
 assert(state in ["idle","attack","move","hit","sleep","victory"], "Unknown animation: " + state)
 var size := 32 if id in ["mianmian","spring"] else 24
 var im := Image.create(size,size,false,Image.FORMAT_RGBA8)
 im.fill(Color.TRANSPARENT)
 var f := posmod(frame,frame_count(state))
 match id:
  "dida": _dida(im,state,f,evolved)
  "taituan": _taituan(im,state,f,evolved)
  "dengxin": _dengxin(im,state,f,evolved)
  "chayan": _chayan(im,state,f,evolved)
  "yingzi": _yingzi(im,state,f,evolved)
  "yaya": _yaya(im,state,f,evolved)
  "piaopiao": _piaopiao(im,state,f,evolved)
  "mianmian": _mianmian(im,state,f,moss)
  "spring": _spring(im,state,f)
  "murk","fluff","shell": _murk(im,id,state,f)
  "heart","lantern": _heart(im,state,f)
  "tree": _tree(im,f)
  "rock": _rock(im)
  _: _murk(im,"murk",state,f)
 if state == "hit": _hit_pose(im,id,f)
 if state == "move" and id in ["dida","taituan","dengxin","yaya","piaopiao"]:
  var foot_color: String = {"dida":"q","taituan":"w","dengxin":"f","yaya":"o","piaopiao":"f"}[id]
  _rect(im,5,20,13,2,".")
  _rect(im,7+f%2,20,3,1,foot_color)
  _rect(im,13-f%2,20+(f%2),3,1,foot_color)
 if state == "victory":
  _stamp(im,18,2+f%2,[".l.","ltl",".l."])
 return im

static func _px(im: Image,x: int,y: int,c: String) -> void:
 if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height(): im.set_pixel(x,y,color(c))

static func _rect(im: Image,x: int,y: int,w: int,h: int,c: String) -> void:
 for yy in range(y,y+h):
  for xx in range(x,x+w): _px(im,xx,yy,c)

static func _stamp(im: Image, x: int,y: int,rows: Array, outline: bool = false) -> void:
 if outline:
  for yy in rows.size():
   var row: String = rows[yy]
   for xx in row.length():
    if row[xx] != ".":
     for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: _px(im,x+xx+d.x,y+yy+d.y,"z")
 for yy in rows.size():
  var row: String = rows[yy]
  for xx in row.length():
   if row[xx] != ".": _px(im,x+xx,y+yy,row[xx])

static func _face(im: Image,x: int,y: int,state: String,f: int,sep: int = 5) -> void:
 if state == "sleep" or (state == "idle" and f == 3):
  _rect(im,x,y+1,2,1,"z"); _rect(im,x+sep,y+1,2,1,"z")
 elif state == "hit":
  _stamp(im,x,y,["z.",".z","z."]); _stamp(im,x+sep,y,[".z","z.",".z"])
 else:
  _rect(im,x,y,2,3,"z"); _rect(im,x+sep,y,2,3,"z")
  _px(im,x,y,"t"); _px(im,x+sep,y,"t")
 _px(im,x+3,y+3,"z")

static func _sleep(im: Image,f: int) -> void:
 _stamp(im,18,3-f,["uuu","..u",".u.","uuu"])

static func _hit_pose(im: Image,id: String,f: int) -> void:
 # Recoil affects a character-specific appendage, never a full-sprite flash/scale.
 match id:
  "dida":
   _rect(im,10,1,11,6,".")
   _stamp(im,10-f,5,["sssss","rssss",".rrr"],true)
  "taituan":
   _rect(im,8,1,9,6,".")
   _stamp(im,9,5+f,["mmmmmm",".nnnn"],true)
  "dengxin":
   _rect(im,8,1,13,6,".")
   _stamp(im,9-f,5,["kkkkk","kllllkk",".llllk"],true)
  "chayan":
   _rect(im,4,1,14,8,".")
   _stamp(im,6,5+f,["uu...uuu",".uu.uu","..uuu"])
  "yingzi":
   _rect(im,0,4,7,10,"."); _rect(im,18,4,6,10,".")
   _stamp(im,4,11+f,["uu","uv","vv"],true)
   _stamp(im,18,11+f,["uu","vu","vv"],true)
  "yaya":
   _rect(im,0,1,10,8,".")
   _stamp(im,3,6+f,["mmmm","mllmm",".nnnn","..nn"],true)
  "piaopiao":
   _rect(im,17,0,7,10,".")
   _stamp(im,16,3+f,["ccc","dcd","ddd",".dd",".ed",".ed"],true)

static func _dida(im: Image,s: String,f: int,e: bool) -> void:
 # Broad drop with a sweeping water crest and one continuous pale face plane.
 _stamp(im,4,3,[".........ss","........sss",".......ssss","......sssss","....ssssssrr","..ssssssssrrrr",".ssttsssssrrrrr","sstttssssssrrrrr","ssttssssssssrrrr","ssssssssssssrrrq","ssssssssssssrrrq","sssssssssssrrrrq",".sssssssssrrrrqq",".ssssssssrrrrrqq","..rrrrrrrrrrrqq","...rrrrrrrrqqq",".....qqqqqqq"],true)
 _stamp(im,2,13 if s != "attack" or f != 1 else 10,["ss","ssr","rrq"],true)
 _stamp(im,19,12 if s in ["hit","attack"] and f == 1 else 14,["ss","rs","qr"],true)
 _stamp(im,7,20,["sss...sss","qqq...qqq"],true)
 _face(im,8,11,s,f,6)
 _rect(im,6,15,2,1,"r"); _rect(im,16,15,2,1,"r")
 if f%2 == 1: _stamp(im,12,4,["sss","ssr"])
 if e:
  _stamp(im,2,7,["s..s","ssss",".rr"],true)
  _stamp(im,6,18,["ssssssssssss",".qqqqqqqqqq"],true)
 if s == "attack" and f == 2: _stamp(im,19,8,[".s","sts","srr",".q"],true)
 if s == "sleep": _sleep(im,f)

static func _taituan(im: Image,s: String,f: int,e: bool) -> void:
 # A low, reassuring moss cub: large leaf mantle, warm face and root paws.
 _stamp(im,3,7,["...mmmm...mmmm",".mmmmmmmmmmmmmm","mmmmmmmmmmmmmmmm","mmllmmmmmmmmmmmn","mllmmmmmmmmmmmmn","mmmmccccccccmmnn","mmnccccccccccnnn","nnnccccccccccnno","nnnccccccccccnno","nnnnccccccccnnoo",".nnnnccccccnnoo","..nnnnnnnnnnoo","....ooooooo"],true)
 _stamp(im,5,20,["dddd......dddd","ffff......ffff"],true)
 _stamp(im,1,13 if s != "attack" or f != 1 else 10,["mm","nn","oo"],true)
 _stamp(im,20,13 if s != "attack" or f != 1 else 10,["mm","nn","oo"],true)
 _face(im,8,12,s,f,6)
 _stamp(im,9,3+f%2,["mm..mm","mmmmmn",".nnnn"],true)
 if e:
  _stamp(im,5,4,[".mmmm","mllmmm","nnnnnn"],true)
  _stamp(im,16,4,["ccc","ddd","fff"],true)
 if s == "attack" and f == 2:
  _stamp(im,1,18,["n.n","non",".o"],true)
  _stamp(im,20,18,["n.n","non",".o"],true)
 if s == "sleep": _sleep(im,f)

static func _dengxin(im: Image,s: String,f: int,e: bool) -> void:
 # The flame IS the character: generous gold cheeks above a little brass lamp.
 var flame: Array = ["......kk",".....kll","....klll","...kllllk","..kllllllk",".klltlllllk","kkllttllllk","klllllllllk","klllllllllk","kklllllllkk",".kkkkkkkkk","..jjjjjjj"]
 if f%2 == 1:
  flame = [".....kk",".....llk","....klllk","...klllllk","..klllllllk",".klltllllllk","kkllttlllllk","kllllllllllk","kllllllllllk","kkllllllllkk",".kkkkkkkkkk","..jjjjjjjj"]
 if s == "attack" and f == 0:
  flame = [".......kk","......kll",".....klll","....kllllk","...kllllllk","..klltllllk",".kllttllllk","kkllllllllk","klllllllllk","kklllllllkk",".kkkkkkkkk","..jjjjjjj"]
 _stamp(im,5,3,flame,true)
 _stamp(im,3,16,["cccccccccccccccc",".dddddddddddddd","..eeeeeeeeeeee","....ffffffff"],true)
 _stamp(im,18,15,["ddd","d.d","ddd"],true)
 _stamp(im,7,21,["ddd....ddd"],true)
 _face(im,8,9,s,f,5)
 _rect(im,6,13,2,1,"j"); _rect(im,15,13,2,1,"j")
 if e:
  _stamp(im,1,14,["kk","ll","kk"],true)
  _rect(im,7,19,10,1,"k")
 if s == "attack" and f == 2: _stamp(im,19,6,[".k","klk","jkj",".j"],true)
 if s == "sleep": _sleep(im,f)

static func _chayan(im: Image,s: String,f: int,e: bool) -> void:
 # Wide porcelain cup, soft ceramic face, two broad readable steam curls.
 _stamp(im,3,10,[".uuuuuuuuuuuuu","utttttttttttttu","ucccccccccccccu","uuuuuuuuuuuuuuu","uuuuuuuuuuuuuvv",".uuuuuuuuuuuvv",".uuuuuuuuuuvvv","..uuuuuuuvvvv","...vvvvvvvvv"],true)
 _stamp(im,18,12,["uuu","u.u","u.u","uuu"],true)
 _stamp(im,6,20,["uuuuuuuuuuu",".vvvvvvvvv"],true)
 _stamp(im,6+f%2,3,[".uu","utt","uu.",".uu","..u"],false)
 _stamp(im,13-f%2,2,[".tt","ttu","uu.",".uu","..u",".uu"],false)
 _face(im,7,13,s,f,6)
 _rect(im,5,16,2,1,"v"); _rect(im,16,16,2,1,"v")
 if e:
  _rect(im,6,18,10,1,"s")
  _stamp(im,2,7,["uuu","uvu",".v"],true)
 if s == "attack":
  if f == 0: _stamp(im,9,6,["uuu","uvu",".v"])
  if f == 2: _stamp(im,19,4,[".uuu","utttu",".uvv","..u"],true)
 if s == "sleep": _sleep(im,f)

static func _yingzi(im: Image,s: String,f: int,e: bool) -> void:
 # A lantern-bellied firefly, big expressive head and two clean wing fans.
 var wing_y := 8 if f%2 == 0 else 6
 _stamp(im,1,wing_y,["uuuu","uttuu","utttuu",".uuuvv","..vvvv"],true)
 _stamp(im,17,wing_y,["uuuu","uuttu","uutttu","vvuuu","vvvv"],true)
 _stamp(im,7,6,["..ccccc",".clllllc","clllllllc","clllllllc","clllllllc",".kkkkkkk","..yyyyy",".klllllk","kllttlllk","kllttlllk",".klllllk","..kkkkk"],true)
 _stamp(im,8,2,["l.....l","y.....y",".y...y"],false)
 _face(im,8,8,s,f,5)
 if e:
  _stamp(im,1,14,["ssuu",".uuu","..vv"],true)
  _stamp(im,18,14,["uuss","uuu","vv"],true)
 if s == "attack" and f == 2:
  _stamp(im,19,2,[".l.","ltl",".l."],false)
  _rect(im,10,15,4,2,"t")
 if s == "sleep": _sleep(im,f)

static func _yaya(im: Image,s: String,f: int,e: bool) -> void:
 # A rounded seedling with two broad leaves, not a stick figure.
 _stamp(im,6,10,["..ccccccc",".ccccccccc","ccccccccccc","ccccccccccc","ccccccccddd","cccccccdddd",".cccccddddd",".ddddddddd","..ddddddd","...eeeee"],true)
 _rect(im,11,6,2,5,"n")
 _stamp(im,2,3+f%2,["mmmmm","mllmmm","mmmmmn",".mnnnn","..nnn"],true)
 _stamp(im,13,2,["..mmmmm",".mllmmm","mmmmmmn","nnnnnn",".nnn"],true)
 _stamp(im,3,13,["mm","mmn",".nn"],true)
 _stamp(im,18,12 if s == "attack" and f == 1 else 14,["mm","nmm","nn"],true)
 _stamp(im,7,21,["nnn....nnn"],true)
 _face(im,8,13,s,f,5)
 if e:
  _stamp(im,10,1,[".DD.","Dllk",".kk."],true)
  _stamp(im,19,9,["mm","mn","nn"],true)
 if s == "attack" and f == 2: _stamp(im,19,6,[".l.","lml",".l."],true)
 if s == "sleep": _sleep(im,f)

static func _piaopiao(im: Image,s: String,f: int,e: bool) -> void:
 # A cheerful broad wooden rain ladle, with water brim and a sturdy handle.
 _stamp(im,18,2,["ccc","dcd","ddd","ddd","edd","edd","edd","edd","edd","edd"],true)
 _stamp(im,2,10,["..cccccccccccc",".ccsssssssssscc","ccssttssssssssc","cssssssssrrrrsc","cdddddddddddddc","cddddddddddddec",".ddddddddddeee",".dddddddddeeee","..eeeeeeeeeee","...fffffffff"],true)
 _stamp(im,6,21,["ddd.....ddd"],true)
 _face(im,6,14,s,f,6)
 _stamp(im,5+f%2,12,["ttsss","sssss"])
 if e:
  _stamp(im,18,3,["mmm","mnn","nnn"],true)
  _rect(im,5,18,12,1,"c")
 if s == "attack":
  if f == 0: _rect(im,5,12,6,1,"s")
  if f == 2: _stamp(im,3,5,[".s","sts","srr",".q"],true)
 if s == "sleep": _sleep(im,f)

static func _murk(im: Image,id: String,s: String,f: int) -> void:
 if id == "fluff":
  _stamp(im,4,7+f%2,["uuw....wuu",".wxx..xxw","..xxxxxx","...xwwx"],true)
  _stamp(im,8,10,[".wwww","wwCwwx","wCCCwx",".CCCx","..xx"],true)
  _stamp(im,10,16,["x.x",".x","x.x"],false)
  _face(im,9,11,s,f,3)
 elif id == "shell":
  _stamp(im,3,7,["....vvvv","..vvvwwvv",".vvwwwwwwv","vvwwxxwwwwv","vwwxxxxwwwv","wwxxxxxxwwx","wxxxxBxxxwx",".xxxBBBxxx","..xxxxxxxx"],true)
  _stamp(im,6,16,["CCCxxxxCC","CBBxxxxBC",".BB....BB"],true)
  _stamp(im,5,8,["..vv",".vvw","vvwx"],false)
  _face(im,7,13,s,f,6)
  _px(im,6+f%2,20,"B"); _px(im,15-f%2,20,"B")
 else:
  _stamp(im,6,9,["..CCC",".CCCCCC","CCCCCCBB","CCCBBBCB","CCBBBBBB",".BBBBBBx","..BxxxBB"],true)
  _stamp(im,5+f%2,17,["xx..xx",".x..x"],true)
  _stamp(im,14,5+f%2,["BB",".B",".B"],false)
  _face(im,8,12,s,f,4)
 if s == "attack" and f == 2: _stamp(im,18,11,[".C","CC","B"],true)
 if s == "sleep": _sleep(im,f)

static func _spring(im: Image,s: String,f: int) -> void:
 # A crowned mushroom elder: broad layered cap, stem face, ragged murk cape.
 _stamp(im,4,8,["......CCCCC","....CCCBCCCC","..CCCBBBCCCCC",".CCCBBBBBCCCCB","CCCCCBBBCCCCBBB","CCBCCCCCBBBBBBB","CBBBCCBBBBBBBBB",".BBBBBBBBBBBBB","...xxxxxxxxx"],true)
 _stamp(im,9,17,[".uuuuuuuuu","uuuuuvvvvvv","uuuvvvvvvvv","uuvvvvvvvvw",".vvvvvvvvw","..wwwwwww","..ww...ww"],true)
 _stamp(im,8,4,["C...C...C","CC.CCC.CC",".BBBBBBB","..xxxxx"],true)
 _face(im,11,19,s,f,6)
 _stamp(im,3,19+f%2,["BB","BCB",".BB","..B"],true)
 _stamp(im,23,18-f%2,["BB","BCB","BB","B"],true)
 if s == "attack" and f == 2:
  _stamp(im,24,9,[".CC","CCBC",".BB"],true)
  _stamp(im,1,12,[".CC","CBC",".BB"],true)
 if s == "sleep": _stamp(im,25,3,["uuu","..u",".u","uuu"])

static func _mianmian(im: Image,s: String,f: int,moss: int = 3) -> void:
 # Old moss turtle, three separate murk-growth silhouettes on the shell.
 _stamp(im,5,11,[".....nnnnnn","...nnmmmmnnnn","..nmmmmmnnnnnn",".nmmllmmnnnnnno","nmmmmmnnnnnnnno","nmmmnnnonnnnnno","nnnnnnoonnnnnoo","nnnnnooonnnnooo",".nooooooonnooo","..ooooooooooo"],true)
 # Shell plates are deliberately grouped, not random noise.
 _stamp(im,9,13,["mmmm..nnnn","mmmn.onnnn","nnno.oonnn","....o....","nnn.oonnn"],false)
 _stamp(im,6,21,["ddddd.......dddd","eeee........eeee",".ff..........ff"],true)
 _stamp(im,1,18,[".dddddd","dcccdddd","dcccdddd","ddeeeeee",".eeeeee"],true)
 _rect(im,3,20,2,2,"z")
 if s == "sleep" or (s == "idle" and f == 3): _rect(im,3,20,2,1,"d")
 else: _px(im,3,20,"t")
 _stamp(im,28,20,["nn","o"],true)
 var growth_y := 6+f%2
 if moss >= 1: _stamp(im,8,growth_y,[".CC","CBBC",".BB",".xx"],true)
 if moss >= 2: _stamp(im,15,4,[".CCC","CCBBC","CBBBC",".BBB","..xx"],true)
 if moss >= 3: _stamp(im,23,growth_y+1,[".CC","CBBC","BBB",".xx"],true)
 if s == "move":
  _rect(im,7+f%2,25,3,1,"f"); _rect(im,21-f%2,25,3,1,"f")
 if s == "attack":
  if f == 0: _rect(im,2,23,3,1,"f")
  if f == 2: _stamp(im,0,13,[".C","CBC",".BB"],true)
 if s == "hit": _stamp(im,2,20,["z.z",".z."])

static func _heart(im: Image,s: String,f: int) -> void:
 # A welcoming roofed heart shrine: broad luminous paper, clear wooden joinery.
 _stamp(im,3,4,["......kkkk","....kkllllkk","..kkllllllllkk","kkddddddddddddkk",".ffffffffffffff"],true)
 _stamp(im,6,9,["dddddddddddd","dlllllllllld","dllltttlllld","dlltlltlllld","dlltlltlllld","dlllkkllllld","dlllllllllld","dddddddddddd"],true)
 _rect(im,5,9,2,10,"f"); _rect(im,17,9,2,10,"f")
 _stamp(im,2,20,["cccccccccccccccccccc",".dddddddddddddddddd"],true)
 _stamp(im,1,15,["mm","mn",".n"],true)
 _stamp(im,20,15,["mm","nm","n"],true)
 _px(im,11+f%2,10,"t")
 if s == "hit": _rect(im,8,11,8,1,"D")

static func _tree(im: Image,f: int) -> void:
 # Three interlocking rounded canopy masses with large highlight/shadow planes.
 _stamp(im,9,13,["ddddd","deddd","deeff","defff","eefff","eefff","fffff","ff.fff"],true)
 _stamp(im,2,3,["......mmmmmmm","....mmllllmmmm","...mmlllllmmmmm","...mlllllmmmmmmn",".mmmmmmmmmmmmmmmn","mmllllmmmmmmmmmmnn","mllllmmmmmmmmmmmnn","mlllmmmmmmmmmmnnnn","mmmmmmmmmmnnnnnnnn","mmmmmmmmnnnnnnnnno",".mmmmnnnnnnnnnnoo","..nnnnnnnooooooo","....ooooo..ooo"],true)
 _stamp(im,3,6,["mmllll","mllllm","mmmmmm"],false)
 _stamp(im,13,4,["mmmmm","mmmnn","nnnnn"],false)
 _stamp(im,7,21,["fff...ffff"],false)
 if f%2 == 1: _rect(im,7,6,3,1,"m")

static func _rock(im: Image) -> void:
 # One broad fractured stone, a lower companion, and a restrained moss lip.
 _stamp(im,3,9,["....uuuuuuu","..uuuuuvvvvvv",".uuuuuvvvvvvvv","uuuuuvvvvvvvww","uuuvvvvvvvvwww","uvvvvvvvwwwwww","vvvvvwwwwwwwww",".wwwwwwwwwwxx","..wwwwwwxxxx"],true)
 _stamp(im,14,16,[".vvvvv","vvvwwww","vvwwwww",".wwxxx"],true)
 _stamp(im,5,9,["mmmm","mmnn",".nn"],false)
 _stamp(im,8,11,["uv",".v",".w","..w","..x"],false)
