extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("13292d"))
	draw_rect(Rect2(0,0,size.x,82),Color("193337"))
	draw_rect(Rect2(28,80,size.x-56,2),Color("35504a"))
	# Deliberate stepped leaf silhouettes frame the interface, not scattered noise.
	for i in 5:
		var x=28+i*18
		var y=size.y-24-i*8
		draw_rect(Rect2(x,y,8,4),Color("345047"))
		draw_rect(Rect2(x+4,y-4,12,4),Color("345047"))
	for i in 4:
		draw_rect(Rect2(size.x-48-i*12,26+i*6,8,4),Color("47634f"))
