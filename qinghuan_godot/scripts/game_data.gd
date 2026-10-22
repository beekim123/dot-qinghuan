class_name GameData
extends RefCounted

const IDS = ["dida", "taituan", "dengxin", "chayan", "yingzi", "yaya", "piaopiao"]
const SPECIES = {
 "dida": {"name":"滴答","grown_name":"涟涟","role":"射","element":"水","hp":9.0,"damage":2.7,"range":2.7,"interval":0.95,"color":"2ce8f5","description":"连珠减速；相邻苔伙伴缓缓恢复体力。"},
 "taituan": {"name":"苔团","grown_name":"苔墩","role":"拦","element":"苔","hp":26.0,"damage":2.0,"range":1.45,"interval":1.0,"color":"63c74d","description":"拦住邻格的两只地面浊；相邻伙伴受到的侵蚀减少。"},
 "dengxin": {"name":"灯芯","grown_name":"灯盏","role":"溅","element":"暖","hp":10.0,"damage":4.2,"range":2.5,"interval":1.7,"color":"feae34","description":"火团洗净一小片浊；相邻伙伴力提升。"},
 "chayan": {"name":"茶烟","grown_name":"茶雾","role":"控","element":"汽","hp":10.0,"damage":1.5,"range":2.8,"interval":1.5,"color":"c0cbdc","description":"茶香让一片浊减速；每第三次出手使它们短暂安睡。"},
 "yingzi": {"name":"萤子","grown_name":"萤火","role":"射","element":"光","hp":9.0,"damage":2.0,"range":3.0,"interval":1.15,"color":"fee761","description":"光点在三只浊之间跳跃。"},
 "yaya": {"name":"芽芽","grown_name":"叶叶","role":"援","element":"苔","hp":13.0,"damage":1.1,"range":2.5,"interval":1.2,"color":"3e8948","description":"为体力最低的伙伴回复；无伤者时用叶片洗净浊。"},
 "piaopiao": {"name":"瓢瓢","grown_name":"大瓢","role":"产","element":"水","hp":12.0,"damage":0.9,"range":2.3,"interval":1.3,"color":"0099db","description":"每六秒接一滴露水，站在露眼上更快。"}
}

static func species(id: String) -> Dictionary:
 return SPECIES.get(id, SPECIES.dida).duplicate(true)

static func display_name(member: Dictionary) -> String:
 var data = species(str(member.get("id", "dida")))
 return data.grown_name if member.get("evolved", false) else data.name
