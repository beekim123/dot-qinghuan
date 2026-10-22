class_name HUDFrame
extends Control
## Pixel HUD chrome only. Parent owns text, input and positioning.
## Set rectangles in this Control's local coordinates, then queue_redraw().
var panels: Array[Rect2] = []
var hp_ratio: float = 1.0
var hp_rect: Rect2 = Rect2()
var cooldown_ratio: float = 0.0
var cooldown_rect: Rect2 = Rect2()

const INK := Color("#102c2c")
const EDGE := Color("#416453")
const FACE := Color("#193c3e")
const CREAM := Color("#ead4aa")
const GOLD := Color("#d4a75a")
const MINT := Color("#91c98a")

func _init() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
 for rect in panels:
  _panel(_snap(rect))
 _meter(_snap(hp_rect),clampf(hp_ratio,0.0,1.0),18,true)
 _meter(_snap(cooldown_rect),clampf(cooldown_ratio,0.0,1.0),8,false)

func _snap(rect: Rect2) -> Rect2:
 return Rect2(rect.position.round(),rect.size.round())

func _stepped(rect: Rect2, ink: Color, corner: float = 8.0) -> void:
 if rect.size.x <= 0.0 or rect.size.y <= 0.0: return
 var c: float = minf(corner,floorf(minf(rect.size.x,rect.size.y)/3.0))
 var p := rect.position
 var e := rect.end
 # Two orthogonal steps, never antialiased diagonal lines.
 var h: float = floorf(c/2.0)
 draw_colored_polygon(PackedVector2Array([
  Vector2(p.x+c,p.y),Vector2(e.x-c,p.y),
  Vector2(e.x-c,p.y+h),Vector2(e.x-h,p.y+h),Vector2(e.x-h,p.y+c),
  Vector2(e.x,p.y+c),Vector2(e.x,e.y-c),
  Vector2(e.x-h,e.y-c),Vector2(e.x-h,e.y-h),Vector2(e.x-c,e.y-h),
  Vector2(e.x-c,e.y),Vector2(p.x+c,e.y),
  Vector2(p.x+c,e.y-h),Vector2(p.x+h,e.y-h),Vector2(p.x+h,e.y-c),
  Vector2(p.x,e.y-c),Vector2(p.x,p.y+c),
  Vector2(p.x+h,p.y+c),Vector2(p.x+h,p.y+h),Vector2(p.x+c,p.y+h)
 ]),ink)

func _panel(rect: Rect2) -> void:
 if rect.size.x < 20.0 or rect.size.y < 20.0: return
 _stepped(Rect2(rect.position+Vector2(0,4),rect.size),Color(0.03,0.08,0.08,0.45))
 _stepped(rect,INK)
 _stepped(rect.grow(-2.0),EDGE,6.0)
 _stepped(rect.grow(-4.0),FACE,4.0)
 var p := rect.position
 var e := rect.end
 # Restrained inset lip and paired brass corner clasps; no table-like rules.
 draw_rect(Rect2(p+Vector2(10,4),Vector2(rect.size.x-20,2)),Color("#55715d"))
 draw_rect(Rect2(p+Vector2(8,2),Vector2(13,2)),GOLD)
 draw_rect(Rect2(p+Vector2(2,8),Vector2(2,9)),GOLD)
 draw_rect(Rect2(p+Vector2(5,5),Vector2(3,3)),CREAM)
 draw_rect(Rect2(Vector2(e.x-21,e.y-4),Vector2(13,2)),GOLD)
 draw_rect(Rect2(Vector2(e.x-4,e.y-17),Vector2(2,9)),GOLD)
 draw_rect(Rect2(e-Vector2(8,8),Vector2(3,3)),CREAM)

func _meter(rect: Rect2, ratio: float, count: int, heart: bool) -> void:
 if rect.size.x < float(count*3+8) or rect.size.y < 8.0: return
 _stepped(rect,INK,4.0)
 _stepped(rect.grow(-1.0),GOLD if heart else EDGE,3.0)
 _stepped(rect.grow(-3.0),Color("#102c2c"),2.0)
 var inner := rect.grow(-4.0)
 var gap := 2.0
 var width: float = floorf((inner.size.x-gap*float(count-1))/float(count))
 var used: float = width*float(count)+gap*float(count-1)
 var left: float = inner.position.x+floorf((inner.size.x-used)/2.0)
 var fill_color: Color = MINT if heart else Color("#fee761")
 if heart and ratio <= 0.25: fill_color = Color("#f6757a")
 for i in count:
  var cell := Rect2(Vector2(left+float(i)*(width+gap),inner.position.y),Vector2(width,inner.size.y))
  draw_rect(cell,Color("#294943"))
  var fraction: float = clampf(ratio*float(count)-float(i),0.0,1.0)
  var pixels: float = floorf(width*fraction)
  if pixels > 0.0:
   draw_rect(Rect2(cell.position,Vector2(pixels,cell.size.y)),fill_color)
   if cell.size.y >= 4.0:
    draw_rect(Rect2(cell.position,Vector2(pixels,1)),CREAM)
    draw_rect(Rect2(cell.position+Vector2(0,cell.size.y-1),Vector2(pixels,1)),Color("#527549") if heart else GOLD)
