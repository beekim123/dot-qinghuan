extends Control

const BG = preload("res://scripts/backdrop.gd")
const CREAM = Color("ead4aa")
const MUTED = Color("8b9bb4")
const MINT = Color("63c74d")
const GOLD = Color("fee761")
const BIOMES = {"grass":"草原","forest":"林间","lake":"湖畔","mountain":"山脚","sand":"沙岸","snow":"雪坡","water":"湖畔"}
const TYPES = {"battle":"守心","rest":"露泉","shop":"行商","boss":"封泉"}
var run = RunState.new()
var mode: String = "yard"
var world: SubViewport
var world_image: TextureRect
var world_node: Node3D
var globe: PlanetView
var arena: ArenaView
var sim: BattleSim
var sidebar: VBoxContainer
var side_scroll: ScrollContainer
var roster: HBoxContainer
var header: Label
var subtitle: Label
var status: Label
var toast: Label
var world_title: Label
var world_hint: Label
var action_bar: HBoxContainer
var pause_button: Button
var speed_button: Button
var skill_button: Button
var selected_team: int = 0
var selected_node: int = -1
var paused: bool = false
var speed: float = 1.0
var drag_start: Vector2
var drag_last: Vector2
var dragging: bool = false
var moved: bool = false
var settled: bool = false
var toast_timer: float = 0.0
var battle_title: Label
var yard_preview: PlanetModel
var ui_clock: float = 0.0

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(1120,760))
	_build_theme()
	run.load_meta()
	_build_shell()
	resized.connect(_layout)
	_layout()
	_show_yard()

func _build_theme() -> void:
	var t = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC","WenQuanYi Zen Hei","Microsoft YaHei","PingFang SC","sans-serif"])
	t.default_font = font
	t.default_font_size = 17
	t.set_color("font_color","Label",CREAM)
	t.set_color("font_color","Button",CREAM)
	t.set_color("font_hover_color","Button",GOLD)
	t.set_color("font_disabled_color","Button",Color("5a6988"))
	for style in ["normal","hover","pressed","disabled","focus"]:
		var s = StyleBoxFlat.new()
		s.bg_color = Color("3a4466") if style=="hover" else Color("262b44")
		if style=="pressed": s.bg_color=Color("265c42")
		if style=="disabled": s.bg_color=Color("181425")
		s.border_color = Color("63c74d") if style in ["hover","focus","pressed"] else Color("5a6988")
		s.set_border_width_all(2 if style=="focus" else 1)
		s.content_margin_left=14
		s.content_margin_right=14
		s.content_margin_top=10
		s.content_margin_bottom=10
		t.set_stylebox(style,"Button",s)
	t.set_constant("separation","VBoxContainer",12)
	t.set_constant("separation","HBoxContainer",10)
	theme=t

func _build_shell() -> void:
	var bg = Control.new()
	bg.set_script(BG)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	header = _label("清欢小星",30,GOLD)
	header.position=Vector2(32,18)
	add_child(header)
	subtitle = _label("一盏小灯，慢慢把星球养回绿色。",16,MUTED)
	subtitle.position=Vector2(220,29)
	add_child(subtitle)
	status = _label("",17,CREAM)
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	add_child(status)
	world=SubViewport.new()
	world.size=Vector2i(480,270)
	world.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world.own_world_3d=true
	world.transparent_bg=false
	add_child(world)
	world_image=TextureRect.new()
	world_image.texture=world.get_texture()
	world_image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	world_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	world_image.stretch_mode=TextureRect.STRETCH_SCALE
	world_image.mouse_filter=Control.MOUSE_FILTER_STOP
	world_image.gui_input.connect(_world_input)
	add_child(world_image)
	world_title=_label("",21,GOLD)
	add_child(world_title)
	world_hint=_label("",15,MUTED)
	add_child(world_hint)
	side_scroll=ScrollContainer.new()
	side_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(side_scroll)
	sidebar=VBoxContainer.new()
	sidebar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	side_scroll.add_child(sidebar)
	action_bar=HBoxContainer.new()
	add_child(action_bar)
	roster=HBoxContainer.new()
	add_child(roster)
	toast=_label("",17,GOLD)
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(toast)

func _layout() -> void:
	if not is_instance_valid(world_image): return
	var available = size.x-396
	var render_size = Vector2i(480,270) if size.x>=1376 and size.y>=900 else Vector2i(384,216)
	world.size=render_size
	var scale_factor = maxi(1,mini(int(available/render_size.x),int((size.y-360)/render_size.y)))
	world_image.size=Vector2(render_size)*scale_factor
	world_image.position=Vector2(24+(available-world_image.size.x)/2,132)
	world_title.position=Vector2(32,100)
	world_hint.position=Vector2(world_image.position.x,world_image.position.y+world_image.size.y+5)
	world_hint.size=Vector2(available,25)
	side_scroll.position=Vector2(size.x-358,112)
	side_scroll.size=Vector2(330,size.y-164)
	status.position=Vector2(size.x-650,29)
	status.size=Vector2(620,45)
	action_bar.position=Vector2(32,world_image.position.y+world_image.size.y+29)
	roster.position=Vector2(32,maxf(size.y-147,action_bar.position.y+56))
	roster.size=Vector2(available-12,108)
	toast.position=Vector2(32,size.y-29)
	toast.size=Vector2(size.x-60,27)

func _label(text_value: String, font_size: int = 17, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.text=text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func _text(text_value: String, color: Color = CREAM, font_size: int = 17) -> Label:
	var label = _label(text_value,font_size,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(label)
	return label

func _button(text_value: String, callback: Callable, disabled: bool = false) -> Button:
	var button = Button.new()
	button.text=text_value
	button.disabled=disabled
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y=46
	button.pressed.connect(callback)
	sidebar.add_child(button)
	return button

func _action(text_value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text=text_value
	button.custom_minimum_size=Vector2(125,43)
	button.pressed.connect(callback)
	action_bar.add_child(button)
	return button

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _reset_ui() -> void:
	_clear(sidebar)
	_clear(action_bar)
	_clear(roster)
	selected_node=-1
	side_scroll.scroll_vertical=0
	battle_title=null

func _replace_world(node: Node3D) -> void:
	if is_instance_valid(world_node):
		world.remove_child(world_node)
		world_node.queue_free()
	world_node=node
	world.add_child(node)

func _show_yard() -> void:
	mode="yard"
	_reset_ui()
	world_title.text="小院  /  心灯之树"
	world_hint.text="每一局都可以重新开始。带着喜欢的小妖，一起出发。"
	var yard = preload("res://scripts/yard_view.gd").new()
	_replace_world(yard)
	yard.setup(str(run.meta.inherited),int(run.meta.oil))
	_text("灯婆婆的小院",GOLD,25)
	_text("星海很远，小院很近。\n洗净浊，结缘小妖，把一颗小星养回绿色。",MUTED)
	_text("出发伙伴 · 点击下方伙伴替换第三位",CREAM,16)
	var start_names: Array = []
	for id in run.starters: start_names.append(GameData.species(id).name)
	_text(" / ".join(start_names),MINT,19)
	_button("点亮孔明灯 · 开始新的一局",_start_run)
	_text("永久成长  ·  星砂 %d"%int(run.meta.sand),GOLD,21)
	for key in ["oil","dew","bond"]:
		var names = {"oil":"灯油 · 心灯上限 +2","dew":"晨露 · 每场露水 +2","bond":"心意 · 行商结缘减价"}
		var level = int(run.meta[key])
		_button("%s  %d/3\n%s"%[names[key],level,"已长满" if level>=3 else "%d 星砂"%(35+level*30)],_upgrade.bind(key),level>=3 or int(run.meta.sand)<35+level*30)
	var inherited: String = str(run.meta.inherited)
	_text("传承："+(GameData.species(inherited).name if inherited!="" else "暂无 · 结束一局时带一只回家"),MINT)
	_text("已经远行 %d 次 · 清欢 %d 次\n星砂、已结缘伙伴和传承自动保存在本机。"%[int(run.meta.runs),int(run.meta.wins)],MUTED,15)
	_action("玩法小笺",_help)
	_render_roster(true)

func _upgrade(key: String) -> void:
	if run.buy_upgrade(key): _show_yard()

func _start_run() -> void:
	run.start_run()
	_show_map()

func _show_map() -> void:
	mode="map"
	_reset_ui()
	globe=PlanetView.new()
	_replace_world(globe)
	globe.setup(run.planet)
	globe.set_candidates(run.candidates)
	if not run.chosen.is_empty(): globe.focus_cell(int(run.chosen.cell))
	else: globe.focus_cell(int(run.candidates[0].cell))
	world_title.text="苔眠星  /  星相 · %s  /  清亮 %d%%"%[RunState.STAGES[run.stage],int(run.planet.clear_fraction()*100)]
	world_hint.text="拖动星球：全向旋转  ·  点击正面标记，或先从右侧定位落点"
	_text(run.time_label(),GOLD,21)
	_text(run.last_message,MUTED,16)
	_text("选择这一个时辰的落点",CREAM,19)
	for i in run.candidates.size():
		var node: Dictionary = run.candidates[i]
		var title = "星心 · 眠眠" if node.spring==2 else TYPES[node.type]
		if node.type=="boss" and node.spring!=2: title="第 %d 口浊泉"%(int(node.spring)+1)
		_button("%s  ·  %s\n%s"%[title,BIOMES.get(node.biome,"草原"),_node_reward(node)],_select_node.bind(i))
	_text("伙伴达到3级后，点击下方卡片免费化形。",MINT,15)
	_text("三口浊泉",GOLD,19)
	for i in run.planet.springs.size():
		var spring: Dictionary = run.planet.springs[i]
		var need = ["初醒 + 守心胜利 2 场","萌青 + 守心胜利 4 场","繁茂 + 前两泉已封"][i]
		_text("%s %s：%s"%["◇" if spring.sealed else "◆","星心" if i==2 else "浊泉%d"%(i+1),"清泉" if spring.sealed else "Lv.%d · %s"%[spring.level,need]],MINT if spring.sealed else MUTED,15)
	_action("回到落点",_focus_selected)
	_action("玩法小笺",_help)
	_action("结束远行",_confirm_retreat)
	_render_roster()

func _node_reward(node: Dictionary) -> String:
	match node.type:
		"battle": return "洗净区域 · 结缘 / 补给 / 修习"
		"rest": return "心灯回复 / 全队修习 / 立即化形"
		"shop": return "用露水结缘、修习与补给"
		_: return "封泉 · 心灯 +5 · 泉力 Lv.%d"%int(node.level)

func _select_node(index: int) -> void:
	if mode!="map": return
	selected_node=index
	var node: Dictionary = run.candidates[index]
	globe.focus_cell(int(node.cell))
	_clear(action_bar)
	_action("进入 · "+("星心" if node.spring==2 else TYPES[node.type]),_enter_selected)
	_action("回到落点",_focus_selected)
	_action("玩法小笺",_help)
	_note("已定位 %s · %s。确认进入将推进一个时辰。"%[TYPES[node.type],BIOMES.get(node.biome,"草原")])

func _focus_selected() -> void:
	if is_instance_valid(globe) and mode=="map":
		globe.focus_cell(int(run.candidates[maxi(0,selected_node)].cell))

func _enter_selected() -> void:
	if mode!="map" or selected_node<0: return
	if not globe.is_front(int(run.candidates[selected_node].cell)):
		globe.focus_cell(int(run.candidates[selected_node].cell))
		_note("正在转向落点，请等标记来到正面再确认。")
		return
	run.chosen=run.candidates[selected_node].duplicate(true)
	if run.chosen.type in ["battle","boss"]: _show_battle()
	else: _show_service()

func _show_battle() -> void:
	mode="battle"
	_reset_ui()
	selected_team=0
	paused=false
	speed=1.0
	settled=false
	sim=BattleSim.new()
	sim.setup(run.battle_config())
	arena=ArenaView.new()
	_replace_world(arena)
	arena.setup(sim)
	world_title.text="%s沙盘  /  %s"%[BIOMES.get(run.chosen.biome,"草原"),"星心 · 眠眠" if run.chosen.spring==2 else ("泉主守心" if run.chosen.type=="boss" else "守心")]
	world_hint.text="选下方小妖 → 点合法空格布阵  ·  右键收回  ·  空格暂停  ·  Q 灯照  ·  Tab 调速"
	_text("把小灯放在心里",GOLD,25)
	battle_title=_text("布阵阶段 · 尚未开战",MINT,20)
	_text("心在中央，浊会从三边来。没有固定路线：你的阵型会改变通路。",MUTED)
	_text("自由布阵",CREAM,19)
	_text("所有定位都能站在合法空格。\n浅水只适合水属性；高台增加射程。树石、入口和心不可部署。\n若封死任一入口或活着的地面浊的通路，操作会被拒绝。",MUTED,16)
	_button("推荐开局布阵",_auto_deploy)
	_text("小妖困了会睡着，不会离开。选中它再点原格，花 4 露水唤醒。\n战斗中增援、换位花露水，暂停时也能操作。",MUTED,16)
	_text("灯照：消耗露水，净化附近的浊并照顾伙伴。请留意冷却。",CREAM,16)
	pause_button=_action("开始守心  [空格]",_toggle_pause)
	speed_button=_action("速度 1×  [Tab]",_cycle_speed)
	skill_button=_action("灯照  [Q]",_skill)
	_render_roster()

func _auto_deploy() -> void:
	if mode!="battle" or sim.running: return
	var placements = [Vector2i(5,2),Vector2i(4,3),Vector2i(6,3),Vector2i(5,4),Vector2i(4,4),Vector2i(6,4)]
	var count = mini(run.team.size(),3+run.stage)
	for i in count:
		var placed: bool = false
		for cell in placements:
			if sim.deploy(i,cell)=="":
				placed=true
				break
		if not placed:
			for y in range(1,sim.height-1):
				for x in range(1,sim.width-1):
					if not placed and sim.deploy(i,Vector2i(x,y))=="": placed=true
	arena.refresh(0)
	_note("已放置推荐阵型。你仍可自由调整，再开始守心。")

func _toggle_pause() -> void:
	if mode!="battle" or sim.finished: return
	if not sim.running:
		if sim.units.is_empty():
			_note("先放下至少一只小妖，或使用推荐开局布阵。")
			return
		sim.start()
		paused=false
	else: paused=not paused
	pause_button.text="继续守心 [空格]" if paused else "暂停 [空格]"

func _cycle_speed() -> void:
	if mode!="battle": return
	speed=2.0 if speed==1.0 else (3.0 if speed==2.0 else 1.0)
	speed_button.text="速度 %d× [Tab]"%int(speed)

func _skill() -> void:
	if mode!="battle": return
	var reason: String = sim.lantern()
	_note(reason if reason!="" else "灯照亮了，小妖们又有了精神。")

func _show_service() -> void:
	mode="service"
	_reset_ui()
	sim=BattleSim.new()
	sim.setup(run.battle_config())
	arena=ArenaView.new()
	_replace_world(arena)
	arena.setup(sim)
	world_title.text="%s · %s"%[BIOMES.get(run.chosen.biome,"草原"),TYPES[run.chosen.type]]
	world_hint.text="在一小片清静里，歇歇脚。这里没有浊来打扰。"
	if run.chosen.type=="rest":
		_text("露泉 · 听一会儿水声",GOLD,25)
		_text("清凉的露水托着小灯。选一份礼物，这一个时辰便过去了。",MUTED)
		_button("添灯油 · 心灯 +6",_rest.bind("heal",-1))
		_button("一同修习 · 全队等级 +1",_rest.bind("train",-1))
		for i in run.team.size():
			if not run.team[i].evolved:
				_button("化形 · "+GameData.species(run.team[i].id).name,_rest.bind("evolve",i))
	else:
		_text("行商慢慢 · 小摊不赶路",GOLD,24)
		_text("一滴一滴攒下来的露水，可以换一份心意。购买后仍能继续挑选。",MUTED)
		_text("露罐：%d 露水"%run.dew,MINT,22)
		var friend_id: String = str(run.chosen.friend)
		if friend_id!="" and not run.has_species(friend_id):
			var cost = 24-int(run.meta.bond)*3
			_button("结缘 %s · %d 露水"%[GameData.species(friend_id).name,cost],_shop.bind("friend",cost,-1),run.dew<cost)
		_button("灯油 · 心灯 +5 / 12 露水",_shop.bind("heal",12,-1),run.dew<12 or run.hp>=run.max_hp)
		for i in run.team.size():
			_button("修习 %s · +1 级 / 8 露水"%GameData.species(run.team[i].id).name,_shop.bind("train",8,i),run.dew<8)
		_button("收好行囊 · 回星",_leave_service)
	_render_roster()

func _rest(kind: String,index: int) -> void:
	if mode!="service": return
	if kind=="heal": run.hp=mini(run.max_hp,run.hp+6)
	elif kind=="train": run.train()
	else:
		run.team[index].level=maxi(3,int(run.team[index].level))
		run.evolve(index)
	run.last_message="露泉赠了一点清凉，伙伴们精神满满。"
	_leave_service()

func _shop(kind: String,cost: int,index: int) -> void:
	if mode!="service" or run.dew<cost: return
	run.dew-=cost
	if kind=="friend": run.recruit(str(run.chosen.friend))
	elif kind=="heal": run.hp=mini(run.max_hp,run.hp+5)
	else: run.train(index)
	_show_service()

func _leave_service() -> void:
	if mode!="service": return
	run.advance()
	_show_map()

func _battle_finished() -> void:
	settled=true
	run.resolve_battle(sim)
	if run.ended:
		_show_ending()
		return
	mode="reward"
	_reset_ui()
	world_title.text="洗净了  /  这片土地记得你"
	world_hint.text="清亮从心向外展开。回星后，对应区域会永久保留本局的变化。"
	_text("浊散了，露水落下来",GOLD,25)
	_text(run.last_message,MINT)
	_text("伙伴们都获得了一级修习。\n收好一份心意，再回星看看。",MUTED)
	var id: String = str(run.chosen.friend)
	if id!="" and not run.has_species(id):
		_button("结缘 · "+GameData.species(id).name,_reward.bind("friend",id))
	else: _button("共同修习 · 全队再 +1 级",_reward.bind("train",""))
	_button("补给 · 露水 +18，心灯 +3",_reward.bind("supply",""))
	_button("静心修习 · 全队 +1 级",_reward.bind("train",""))
	_render_roster()

func _reward(kind: String,id: String) -> void:
	if mode!="reward": return
	if kind=="friend": run.recruit(id)
	elif kind=="supply":
		run.dew+=18
		run.hp=mini(run.max_hp,run.hp+3)
	else: run.train()
	run.advance()
	_show_map()

func _show_ending() -> void:
	mode="ending"
	_reset_ui()
	globe=PlanetView.new()
	_replace_world(globe)
	globe.setup(run.planet)
	globe.set_candidates([])
	if not run.chosen.is_empty(): globe.focus_cell(int(run.chosen.cell))
	world_title.text="清欢  /  眠眠醒了" if run.won else "灯歇了  /  小院一直在等你"
	world_hint.text="小妖们只是睡着了。一起回家，下次再来。" if not run.won else "小小的星球，终于又有了风。谢谢你，清星人。"
	_text("人间有味是清欢" if run.won else "这一次，也走了很远",GOLD,26)
	_text("眠眠翻了个身，浊苔散成细小的露珠。整颗星慢慢亮起来。" if run.won else "心灯轻轻歇下，小妖们靠在一起睡着了。没有谁被留下。",MUTED)
	_text("带回星砂 +%d"%run.earned_sand,MINT,25)
	_text("已封浊泉 %d/3 · 结缘伙伴 %d\n新结缘的种类已解锁为开局伙伴。"%[run.sealed_count(),run.team.size()],CREAM)
	_text("选一只传承伙伴，一起回小院",GOLD,19)
	for i in run.team.size():
		_button("带 %s 回家"%GameData.species(run.team[i].id).name,_inherit.bind(i))
	_render_roster()

func _inherit(index: int) -> void:
	run.inherit(index)
	_show_yard()

func _render_roster(yard: bool = false) -> void:
	_clear(roster)
	var members: Array = []
	if yard:
		for id in GameData.IDS: members.append({"id":id,"level":1,"evolved":false})
	else: members=run.team
	for i in members.size():
		var member: Dictionary = members[i]
		var data: Dictionary = GameData.species(member.id)
		var card=Button.new()
		card.custom_minimum_size=Vector2(125,104)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.icon=PixelArt.texture(member.id,"idle",0,bool(member.evolved))
		card.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		card.expand_icon=true
		card.add_theme_constant_override("icon_max_width",44)
		card.add_theme_font_size_override("font_size",15)
		var role = str(data.role)
		card.text="%s · %s\n%s"%[GameData.display_name(member),role,"Lv.%d%s"%[int(member.level)," · 已化形" if member.evolved else ""] if not yard else ("可出发" if member.id in run.meta.unlocked else "待结缘")]
		card.tooltip_text="%s · %s\n%s\n点选后部署；地图上等级达到3可免费化形。"%[GameData.display_name(member),role,data.description]
		if yard:
			card.disabled=not member.id in run.meta.unlocked
			card.pressed.connect(_choose_starter.bind(str(member.id)))
		else:
			card.pressed.connect(_select_team.bind(i))
			if i==selected_team:
				var selected_style=StyleBoxFlat.new()
				selected_style.bg_color=Color("193c3e")
				selected_style.border_color=GOLD
				selected_style.set_border_width_all(2)
				selected_style.content_margin_top=8
				selected_style.content_margin_bottom=8
				card.add_theme_stylebox_override("normal",selected_style)
		roster.add_child(card)

func _choose_starter(id: String) -> void:
	if id in run.starters:
		_note("这位伙伴已经在出发队伍里。")
		return
	run.starters[2]=id
	_show_yard()

func _select_team(index: int) -> void:
	selected_team=index
	if mode=="battle":
		arena.set_selected(index)
		_note("已选择 %s：点击空格部署 / 换位；点原来的睡眠格唤醒。"%GameData.species(run.team[index].id).name)
	elif mode in ["map","reward","service"]:
		if run.evolve(index): _note("%s 化形了！新的模样，新的力量。"%GameData.species(run.team[index].id).name)
		else: _note("%s · Lv.%d%s"%[GameData.species(run.team[index].id).name,int(run.team[index].level)," · 已经化形" if run.team[index].evolved else " · 3级可化形，点选即可"])
	_render_roster()

func _world_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging=true
				moved=false
				drag_start=event.position
				drag_last=event.position
			else:
				dragging=false
				if not moved: _world_click(event.position,false)
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: _world_click(event.position,true)
	elif event is InputEventMouseMotion:
		var pos: Vector2 = event.position/world_image.size*Vector2(world.size)
		if dragging and mode in ["map","ending"]:
			if event.position.distance_to(drag_start)>5: moved=true
			if moved and is_instance_valid(globe): globe.handle_drag((event.position-drag_last)/world_image.size*Vector2(world.size))
			drag_last=event.position
		if mode=="battle":
			var cell: Vector2i = arena.screen_to_cell(pos)
			arena.set_hover(cell,sim.can_deploy(selected_team,cell)=="")

func _world_click(local_pos: Vector2,right: bool) -> void:
	var pos=local_pos/world_image.size*Vector2(world.size)
	if mode=="map":
		var cell: int = globe.pick(pos)
		if cell>=0:
			for i in run.candidates.size():
				if int(run.candidates[i].cell)==cell:
					_select_node(i)
					break
	elif mode=="battle" and not sim.finished:
		var cell: Vector2i = arena.screen_to_cell(pos)
		if cell.x<0: return
		var reason: String = sim.remove(cell) if right else sim.deploy(selected_team,cell)
		if reason!="": _note(reason)
		else: _note("阵型已更新，浊会重新寻找通路。")
		arena.refresh(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _toggle_pause()
			KEY_TAB: _cycle_speed()
			KEY_Q: _skill()
			KEY_R: _focus_selected()
			KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7:
				var index: int = int(event.keycode)-KEY_1
				if mode=="battle" and index<run.team.size(): _select_team(index)

func _process(delta: float) -> void:
	ui_clock+=delta
	if mode=="battle" and is_instance_valid(arena) and sim!=null:
		if sim.running and not paused and not sim.finished:
			var remaining: float = minf(delta,0.1)*speed
			while remaining>0.0:
				var dt = minf(remaining,1.0/30.0)
				sim.step(dt)
				remaining-=dt
		arena.refresh(delta if not paused else 0.0)
		if is_instance_valid(battle_title):
			battle_title.text="%s · 第 %d / %d 波\n心灯 %d / %d  ·  露水 %d"%["暂停布阵" if paused else ("自动守心" if sim.running else "自由布阵"),maxi(1,sim.wave),sim.total_waves,int(sim.heart_hp),run.max_hp,int(sim.dew)]
		if is_instance_valid(skill_button): skill_button.text="灯照 %s [Q]"%("%.0fs"%sim.skill_cooldown if sim.skill_cooldown>0 else "就绪")
		if sim.finished and not settled: _battle_finished()
	elif mode in ["reward","service"] and is_instance_valid(arena): arena.refresh(delta)
	if mode=="yard": status.text="小院  ·  星砂 %d"%int(run.meta.sand)
	elif run.planet!=null:
		status.text="心灯 %d/%d   ·   露罐 %d   ·   %s"%[int(sim.heart_hp) if mode=="battle" else run.hp,run.max_hp,run.dew,RunState.STAGES[run.stage]]
	if toast_timer>0:
		toast_timer-=delta
		if toast_timer<=0: toast.text=""

func _note(message: String) -> void:
	toast.text=message
	toast_timer=7.0

func _help() -> void:
	var dialog=AcceptDialog.new()
	dialog.title="清星人的小笺"
	dialog.dialog_text="小院 → 星球选落点 → 独立沙盘守心 → 收获 → 回星。\n\n星球：拖动可翻到背面和两极，右侧列表先定位，再点击进入。\n沙盘：点击下方小妖，再点空格。所有定位自由部署。右键收回。\n空格开始/暂停，Tab调速，Q灯照。战斗中可花露水增援和唤醒。\n\n心灯是整局共用的生命，不会在战斗之间自动回满。\n每四个时辰，未封浊泉增强。洗净区域推动星相，解锁三口泉。\n小妖每战升级；3级后在地图点伙伴即可化形。\n封住两口浊泉，达到繁茂，挑战星心眠眠。\n胜败都会带回星砂，选择一只传承，回小院重新出发。"
	dialog.min_size=Vector2i(680,500)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _confirm_retreat() -> void:
	if mode!="map": return
	var dialog=ConfirmationDialog.new()
	dialog.title="今晚先回家？"
	dialog.dialog_text="结束这次远行，带回已获得的星砂和一只传承伙伴。\n星球和局内等级会在下次出发时重新生成。"
	add_child(dialog)
	dialog.popup_centered(Vector2i(550,180))
	dialog.confirmed.connect(func():
		dialog.queue_free()
		run.finish(false)
		_show_ending())
	dialog.canceled.connect(dialog.queue_free)
