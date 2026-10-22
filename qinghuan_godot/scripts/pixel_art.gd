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

static func _dida(im: Image,s: String,f: int,e: bool) -> void:
 # A teardrop with a curled crest, tiny paddle hands and a rippled skirt.
 var crest := f % 2
 _stamp(im,6,5,["......s",".....ss","....sss","...sssr","..stssrr",".stsssrrr",".ssssrrrrr","ssssrrrrrq","sssrrrrrrq","ssrrrrrrqq","srrrrrrqqq",".rrrrrqqq","..rrrrqq","...qqqq"],true)
 _stamp(im,3,13 + (1 if s == "attack" and f == 0 else 0),[".ss","ssr",".rq"],true)
 _stamp(im,17,12 if s == "attack" and f == 1 else 14,["ss.","rss","qr."],true)
 _stamp(im,8,19,["ss..ss","qq..qq"],true)
 _px(im,13+crest,4,"s")
 _face(im,9,12,s,f)
 if e:
  _stamp(im,4,7,["s..s","ssrs",".rr"],true)
  _stamp(im,7,18,["stsssss",".qqqqq"],true)
 if s == "attack" and f == 2: _stamp(im,20,10-f,["s","st","r"],true)
 if s == "sleep": _sleep(im,f)

static func _taituan(im: Image,s: String,f: int,e: bool) -> void:
 # Low broad moss animal, distinct leafy brows, stone feet, and root arms.
 _stamp(im,4,8,["..mm...mm",".mlmm.mmmm","mmmmmmmmmmm","mmnmmmmmnmmm","mnnmmmmnnnmm","nnnmmmmnnnnn","nnmmmmnnnnno","nnnmmnnnnnoo",".nnnnnnnnoo","..ooooooo"],true)
 _stamp(im,5,18,["vvv....vvv","www....www"],true)
 _stamp(im,3,12 if s != "attack" or f != 1 else 10,["mn","no","oo"],true)
 _stamp(im,17,12 if s != "attack" or f != 1 else 10,["mm","nn","oo"],true)
 _face(im,7,12,s,f,6)
 _stamp(im,10,5+f%2,["m..m","mmmn",".nn"],true)
 if e:
  _stamp(im,6,4,["..mm",".mlmm","mmmmmm","nnnnnn"],true)
  _stamp(im,14,6,["cc","dd","ff"],true)
 if s == "attack" and f == 2:
  _stamp(im,1,18,["n...n","on.no",".ooo"],true)
  _stamp(im,18,18,["n...n","on.no",".ooo"],true)
 if s == "move":
  _rect(im,5+(f%2)*2,20,3,1,"w"); _rect(im,13+(1-f%2)*2,20,3,1,"w")
 if s == "sleep": _sleep(im,f)

static func _dengxin(im: Image,s: String,f: int,e: bool) -> void:
 # Ceramic oil-lamp body with a living flame and brass handle.
 var flame: Array = ["...k","..kl","..llt",".kllt","kkllk","jkkkj",".jjj"]
 if f % 2 == 1: flame = ["..k","..lk",".kll",".kltl","kkllk","jkkkj",".jjj"]
 if s == "attack" and f == 0: flame = ["....k","...kl","..kll",".kkll","jjkkk",".jjj"]
 if s == "attack" and f == 1: flame = ["..k..k","..l.kl",".kltll","kklllk","jjkkjj",".jjjj"]
 _stamp(im,8,4,flame,true)
 _stamp(im,5,12,["cccccccccccc",".dddddddddd","..ddeeeddd","..eeeeeeef","...ffffff"],true)
 _stamp(im,16,11,[".ddd","d..d","d..d","ddd"],true)
 _stamp(im,8,18,["ddd..ddd","fff..fff"],true)
 _face(im,8,13,s,f)
 if e:
  _stamp(im,3,11,["kk","ll","kk"],true)
  _stamp(im,6,18,["kkkkkkkkkk",".ffffffff"],true)
 if s == "attack" and f == 2: _stamp(im,19,5,[".k","klk","jkj",".j"],true)
 if s == "sleep": _sleep(im,f)

static func _chayan(im: Image,s: String,f: int,e: bool) -> void:
 # Porcelain teacup with asymmetrical vapor curls: not a recolored blob.
 _stamp(im,5,11,["uuuuuuuuuuu","utttttttttu",".ucccccccu",".uuuuuuuvu","..uuuuuvv","..uvvvvvv","...vvvvv"],true)
 _stamp(im,16,12,["uuu","u.u","uuu"],true)
 _stamp(im,7,18,["vvvvvvv",".xxxxx"],true)
 var shift := f % 2
 _stamp(im,7+shift,3,[".uu","ut.","uu.",".vu","..u",".uu"],false)
 _stamp(im,13-shift,5,[".tt","tu.","uv.",".u"],false)
 _face(im,8,13,s,f)
 if e:
  _stamp(im,3,8,[".u..u","uuuuu",".vvv"],true)
  _rect(im,8,17,7,1,"s")
 if s == "attack":
  if f == 0: _stamp(im,10,7,["uuu","uvu",".v."])
  if f == 2: _stamp(im,18,5-f,[".uuu","utttu",".uvv","..u"],true)
 if s == "sleep": _sleep(im,f)

static func _yingzi(im: Image,s: String,f: int,e: bool) -> void:
 # Firefly: two pairs of pale wings, antennae, dark thorax, luminous tail.
 var wing_y := 10 if f % 2 == 0 else 8
 _stamp(im,3,wing_y,["uttt","uuutt",".uuvv","..vv"],true)
 _stamp(im,15,wing_y,[".tttu","ttuuu","vvuu","vv"],true)
 if e:
  _stamp(im,2,wing_y+5,["ssu",".uu","..v"],true)
  _stamp(im,18,wing_y+5,["uss","uu","v"],true)
 _stamp(im,9,8,[".ccc","clllc","clllc",".kkk",".yyy","yllly","klllk","kltlk",".kkk"],true)
 _stamp(im,8,4,["l.....l",".y...y","..y.y"],false)
 _face(im,9,9,s,f,3)
 if s == "attack" and f == 2:
  _stamp(im,18,3,["..l",".ltl","ll.ll",".l"],false)
  _rect(im,10,14,3,2,"t")
 if s == "sleep": _sleep(im,f)

static func _yaya(im: Image,s: String,f: int,e: bool) -> void:
 # Sprout with long stem, paired leaf hands and an expressive seed coat.
 _stamp(im,9,12,[".ccc","ccddd","cdddd","dddee",".eee"],true)
 _rect(im,11,7,2,6,"n")
 var y := 5 + f % 2
 _stamp(im,4,y,["mmmm","mlmmm",".mmnn","..nn"],true)
 _stamp(im,13,y-2,["...mm","..mlm",".mmmn","nnnn"],true)
 _stamp(im,5,13,["mm","mnn",".nn"],true)
 _stamp(im,15,12 if s == "attack" and f == 1 else 14,["mm","nnm","nn"],true)
 _stamp(im,8,19,["nn...nn","oo...oo"],true)
 _face(im,9,14,s,f,3)
 if e:
  _stamp(im,10,2,[".D.","Dlk",".k."],true)
  _stamp(im,17,9,["mm","mn","n"],true)
 if s == "attack" and f == 2: _stamp(im,19,6,[".l.","lml",".l."],true)
 if s == "sleep": _sleep(im,f)

static func _piaopiao(im: Image,s: String,f: int,e: bool) -> void:
 # Wooden ladle, long crooked handle, blue water bowl and twig legs.
 _stamp(im,16,3,["ccc","dcd","dd.","ed.","ed.","ed.","ed.","ed.","ed."],true)
 _stamp(im,4,11,[".cccccccccc","ccssssssssc","csssrrrsssc","cdddddddddc",".deeeeeeed","..eeeeeee","...fffff"],true)
 _stamp(im,7,19,["dd....dd","ff....ff"],true)
 _face(im,7,14,s,f,5)
 _stamp(im,6+f%2,12,["ttss","ssss"])
 if e:
  _stamp(im,3,10,["ccc","ddd","eee"],true)
  _stamp(im,17,4,[".mm","mmm","nn"],true)
 if s == "attack":
  if f == 0: _rect(im,6,12,5,1,"s")
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
 # Heart lamp altar: warm paper lantern with wood frame and a leafy stand.
 _stamp(im,7,7,[".kkkkkk","kkllllkk","kllllllk","kllllllk","kllllllk","kllllllk","kkllllkk",".kkkkkk"],true)
 _rect(im,10,5,4,1,"d"); _rect(im,11,3,2,3,"f")
 _rect(im,7,9,1,4,"d"); _rect(im,14,9,1,4,"d")
 _stamp(im,10,9,["l.l","tlt",".k."],false)
 _rect(im,10,16,4,3,"f")
 _stamp(im,5,19,["...cccccc","ccccddddcccc",".ffffffffff"],true)
 _stamp(im,4,15,["mm","mn",".n"],true)
 _stamp(im,17,16,["mm","nm","n"],true)
 _px(im,12,7+f%2,"t")
 if s == "hit": _rect(im,8,9,6,1,"D")

static func _tree(im: Image,f: int) -> void:
 # Cedar-like crown kept above the gameplay cell; 2D original sprite.
 _stamp(im,10,14,["ddd","ded","def","def","eff","fff"],true)
 _stamp(im,3,3,["........m",".......mmm","......mlmmm",".....mmmmmmm","....mmmnnmmmm","...mmnnnnnnmmm","..mmmmmmmmmmmmm","....mmnnnnnmm","..mmmmmmmmmmmmm",".mmnnnnnnnnnnmmm","mmmmmmnnnnnmmmmmm","..nnnnnooonnnnn"],true)
 _px(im,11+f%2,4,"l")
 _stamp(im,8,20,["fff..fff"])

static func _rock(im: Image) -> void:
 _stamp(im,5,11,["...uuuu",".uuvvvvvv","uuvvvvvvww","uvvvvvwwww","vvvvwwwwww","vvwwwwwwxx",".wwwwxxxx","..xxxxxx"],true)
 _stamp(im,7,12,["uuu","uvv","vv"])
 _stamp(im,15,15,["w","x","x"])
