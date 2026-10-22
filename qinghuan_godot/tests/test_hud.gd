extends SceneTree
# Use a disposable XDG_DATA_HOME: boot reads the normal local meta save.
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("HUD: " + message)

func _initialize() -> void:
 call_deferred("run_test")

func inside_window(control: Control, scene: Control) -> bool:
 return Rect2(Vector2.ZERO,scene.size).encloses(control.get_rect())

func disjoint(a: Control,b: Control,label: String) -> void:
 if a.is_visible_in_tree() and b.is_visible_in_tree():
  check(not a.get_global_rect().intersects(b.get_global_rect()),label)

func common(scene, label: String) -> void:
 check(not scene.side_panel.visible and not scene.side_scroll.visible,label+" no dashboard sidebar")
 check(scene.world_image.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,label+" nearest pixel filtering")
 var scale_x: float = scene.world_image.size.x/float(scene.world.size.x)
 var scale_y: float = scene.world_image.size.y/float(scene.world.size.y)
 check(is_equal_approx(scale_x,roundf(scale_x)) and is_equal_approx(scale_x,scale_y),label+" integer uniform render scale")
 check(scene.world_image.size.x>=scene.size.x*0.90,label+" world spans window rather than sidebar column")
 check(inside_window(scene.roster_scroll,scene),label+" roster inside window")
 check(scene.roster_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,label+" roster overflow can scroll")
 for card in scene.roster.get_children():
  check(card.size.x<=104.1,label+" compact fixed roster slot")
  check((card.size_flags_horizontal & Control.SIZE_EXPAND)==0,label+" roster slot does not stretch")
 for point in [Vector2(10,10),Vector2(scene.world.size)*0.5,Vector2(scene.world.size)-Vector2(10,10)]:
  var screen: Vector2 = scene.world_image.position+point/Vector2(scene.world.size)*scene.world_image.size
  var converted: Vector2 = (screen-scene.world_image.position)/scene.world_image.size*Vector2(scene.world.size)
  check(converted.distance_to(point)<0.001,label+" screen/viewport roundtrip")
 for control in [scene.heart_icon,scene.heart_readout,scene.dew_readout,scene.battle_title]:
  check(inside_window(control,scene),label+" top status within window")
 disjoint(scene.heart_readout,scene.battle_title,label+" heart and wave distinct")
 disjoint(scene.battle_title,scene.dew_readout,label+" wave and dew distinct")

func run_test() -> void:
 var scene = load("res://main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.run.meta={"sand":0,"oil":0,"dew":0,"bond":0,"unlocked":["dida","taituan","dengxin"],"inherited":"","runs":0,"wins":0}
 scene.run.start_run(20261022)
 scene._show_map()
 for dimensions in [Vector2(1440,900),Vector2(1180,812)]:
  scene.size=dimensions
  scene._layout()
  await process_frame
  await process_frame
  var label = "map %dx%d"%[dimensions.x,dimensions.y]
  common(scene,label)
  check(scene.map_choices.visible,label+" landing choices visible")
  check(inside_window(scene.map_choices,scene),label+" choices within window")
  check(scene.map_choices.get_child_count()==scene.run.candidates.size(),label+" each landing has card")
  disjoint(scene.map_choices,scene.roster_scroll,label+" landing choices above roster")
  scene._select_node(0)
  await process_frame
  check(scene.setup_button.visible,label+" selected landing has enter CTA")
  disjoint(scene.setup_button,scene.roster_scroll,label+" enter CTA separate from roster")
 # Skipping eligible springs can legitimately produce five landing cards.
 scene.run.wins=4
 scene.run.stage=3
 scene.run.make_candidates()
 scene._show_map()
 for dimensions in [Vector2(1440,900),Vector2(1180,812)]:
  scene.size=dimensions
  scene._layout()
  await process_frame
  await process_frame
  print("HUD_MAP_CHOICES ",dimensions," count=",scene.map_choices.get_child_count()," actual_width=",scene.map_choices.size.x)
  check(scene.map_choices.get_child_count()==5,"five eligible landing cards fixture")
  check(inside_window(scene.map_choices,scene),"five landing cards fit viewport "+str(dimensions))
  for card in scene.map_choices.get_children():
   check(Rect2(Vector2.ZERO,scene.size).encloses(card.get_global_rect()),"landing card fully visible "+str(dimensions))
 # All seven companions exercise the largest legitimate team and card list.
 for id in ["chayan","yingzi","yaya","piaopiao"]: scene.run.recruit(id)
 for member in scene.run.team: member.evolved=true
 scene.run.chosen=scene.run.candidates[0].duplicate(true)
 scene._show_battle()
 for dimensions in [Vector2(1440,900),Vector2(1180,812)]:
  scene.size=dimensions
  scene._layout()
  await process_frame
  await process_frame
  var label = "battle %dx%d"%[dimensions.x,dimensions.y]
  common(scene,label)
  check(scene.roster.get_child_count()==7,label+" all seven party slots")
  check(not scene.map_choices.visible,label+" no landing choices during battle")
  for control in [scene.top_controls,scene.skill_button,scene.setup_button,scene.auto_button]:
   check(control.is_visible_in_tree() and inside_window(control,scene),label+" actionable HUD within window")
  disjoint(scene.top_controls,scene.dew_readout,label+" controls separate from resource")
  disjoint(scene.skill_button,scene.roster_scroll,label+" lantern separate from party")
  disjoint(scene.setup_button,scene.roster_scroll,label+" begin separate from party")
  disjoint(scene.setup_button,scene.skill_button,label+" begin separate from lantern")
  disjoint(scene.auto_button,scene.setup_button,label+" recommend and begin separated")
  # Actual projection + picking, including the center and legal deployment cells.
  for cell in [Vector2i(5,3),Vector2i(4,3),Vector2i(5,2),Vector2i(6,3)]:
   var projected: Vector2 = scene.arena.camera.unproject_position(scene.arena._world(Vector2(cell),scene.arena._height(cell)+0.055))
   var screen: Vector2 = scene.world_image.position+projected/Vector2(scene.world.size)*scene.world_image.size
   var viewport: Vector2 = (screen-scene.world_image.position)/scene.world_image.size*Vector2(scene.world.size)
   check(scene.arena.screen_to_cell(viewport)==cell,label+" actual projected cell picking "+str(cell))
   for control in [scene.roster_scroll,scene.skill_button,scene.setup_button,scene.auto_button,scene.top_controls]:
    check(not control.get_global_rect().has_point(screen),label+" central tactical tile not under HUD")
  var occluded_tiles: Array = []
  for y in scene.sim.height:
   for x in scene.sim.width:
    var cell = Vector2i(x,y)
    var p: Vector2 = scene.arena.camera.unproject_position(scene.arena._world(Vector2(cell),scene.arena._height(cell)+0.055))
    var screen: Vector2 = scene.world_image.position+p/Vector2(scene.world.size)*scene.world_image.size
    for control in [scene.roster_scroll,scene.skill_button,scene.setup_button,scene.auto_button,scene.top_controls]:
     if control.is_visible_in_tree() and control.get_global_rect().has_point(screen):
      occluded_tiles.append(cell)
      break
  print("HUD_TILE_OCCLUSION ",label," ",occluded_tiles)
  check(occluded_tiles.is_empty(),label+" every battlefield tile center clear of action HUD")
  scene.sim.remove(Vector2i(4,3))
  scene.selected_team=0
  var target = Vector2i(4,3)
  var pixel: Vector2 = scene.arena.camera.unproject_position(scene.arena._world(Vector2(target),scene.arena._height(target)+0.055))
  scene._world_click(pixel/Vector2(scene.world.size)*scene.world_image.size,false)
  var found = false
  for unit in scene.sim.units:
   if unit.team_index==0 and unit.cell==target: found=true
  check(found,label+" actual image-local click deploys correct cell")
 scene._toggle_pause()
 await process_frame
 check(not scene.setup_button.visible and not scene.auto_button.visible,"setup CTAs hide once battle starts")
 check(scene.top_controls.visible and scene.skill_button.visible,"combat controls remain visible")
 print("HUD_CHECKS ",checks," FAILURES ",failures)
 scene.queue_free()
 await process_frame
 quit(1 if failures>0 else 0)
