extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("181425"))
	for i in 6:
		draw_rect(Rect2(0,i*size.y/6,size.x,size.y/6+1),Color("262b44").lerp(Color("181425"),float(i)/6.0))
	for i in 75:
		var p = Vector2(fmod(i*137.0+31,size.x),fmod(i*i*61.0+77,size.y))
		draw_rect(Rect2(p,Vector2(2 if i%5 else 3,2 if i%5 else 3)),Color("5a6988") if i%3 else Color("c0cbdc"))
	draw_line(Vector2(24,92),Vector2(size.x-24,92),Color("3a4466"),2)
