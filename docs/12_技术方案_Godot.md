# 12 技术方案（Godot · v3）

> v3.1：本文件仅为后续 Godot 移植方案，不是当前实施任务。先完成 16 的两种完整离线 HTML 并由用户选定画风。两场景、自由方格与动态寻路以 03/04 为准；下列 Sprite3D/像素贴图配置是像素风的后续路径，线条版对应程序生成二维纹理，不是三维建模小妖。

## 1. 版本与基本选择

| 项 | 选择 | 说明 |
|---|---|---|
| 引擎 | **Godot 4.7.2**（用户给出的目标，移植开工时核实平台安装，不表示已验证） | — |
| 渲染器 | Forward+ | 战场要用阴影、泛光、体积雾、景深 |
| 语言 | GDScript，全部写类型标注 | 模拟成为瓶颈时再把热点挪到 GDExtension |
| 平台 | Windows、macOS、Linux（Steam Deck） | 先 PC |
| 分辨率 | 窗口 1920×1080；界面基准 960×540；像素风世界 480×270 最近邻放大；线条风高清，机位相同 | 见 [09](09_美术规范_HD2D.md) 第 2 节 |

---

## 2. 工程结构

```
res://
  project.godot
  addons/
    qinghuan_art/            美术导入插件：字符画 JSON → 贴图、图集、SpriteFrames、地块图集
  art/                       美术源数据（见 09 第 9 节）：palette、sprites、tiles、battlefields
  audio/                     音色预设、曲谱、音效参数，以及构建出的 ogg / wav
  data/
    species.json  skills.json  enemies.json  waves.json  balance.json
    nodes.json  events.json  shop.json  gifts.json  traits.json  omens.json
    meta_tree.json  vehicles.json  ascension.json
    i18n/zh_CN.csv
  src/
    core/          随机数、事件总线、存档、设置、字符画解析
    content/       内容数据库（只读）
    planet/        六边格球、地形、浊、浊泉、落点区域、净化、浊潮、星相、时辰天气
    battlefield/   战场：选模板、镜像、装饰、动态通行图、校验（纯逻辑）
    battle/        战斗模拟（纯逻辑，坐标是方格）
    yao/           小妖个体、结缘、合流、化形
    run/           一局：落点生成、奖励、行商、奇遇、星签、队伍
    meta/          局外：心灯之树、羁绊、传承、解锁、浊深、每日星球、故事
    view_planet/   星球视图的表现
    view_battle/   战场的表现：地块网格、精灵、光、特效、镜头
    ui/            界面
    audio/         音乐分层与音效调度
  scenes/        main.tscn、planet_scene.tscn、battle_scene.tscn、yard_scene.tscn
  shaders/       tile.gdshader、sprite.gdshader、water.gdshader、portal.gdshader、
                 planet.gdshader、clouds.gdshader、post_dissolve.gdshader、vignette.gdshader
  tests/
  tools/         无界面平衡模拟、整局模拟、内容校验、模板校验、截图脚本
```

---

## 3. 架构

### 3.1 分层

```
  数据层（content/）       只读：种类、技能、浊、模板、星签……
        ↓
  逻辑层（planet/ battlefield/ battle/ yao/ run/ meta/）
        纯 GDScript 类（RefCounted），不碰节点和画面；可以无界面运行
        输入：命令（ChooseNode、PlaceUnit、CastVehicleSkill……）
        输出：状态 + 事件（UnitAttacked、MurkPopped、TileCleared……）
        ↓
  表现层（view_planet/ view_battle/ ui/ audio/）
        读状态画画面，听事件放特效和声音；只通过命令改逻辑
```

- 逻辑和表现完全分开：战斗和整局都能无界面跑上万次做平衡；改画面不会改坏规则。
- 事件用轻量的事件总线（`EventBus`），事件是带类型的小对象。

### 3.2 自动加载（Autoload）

| 名字 | 职责 |
|---|---|
| `Content` | 内容数据库 |
| `Meta` | 局外状态 |
| `Run` | 当前这一局的状态（不在局里时为空） |
| `SceneDirector` | 场景切换和转场（星球 ↔ 战场 ↔ 小院），见第 4.3 节 |
| `EventBus` | 事件分发 |
| `SaveService` | 存档读写和版本迁移 |
| `Settings` | 设置 |
| `AudioDirector` | 音乐分层、音效限流 |

---

## 4. 场景

### 4.1 星球视图 `planet_scene.tscn`

```
PlanetScene (Node)
├─ PlanetView (SubViewportContainer，960×540，拉伸 ×2，最近邻)
│   └─ SubViewport 480×270（own_world_3d）
│       ├─ WorldEnvironment        背景色、轻的泛光
│       ├─ DirectionalLight3D      太阳（按时辰）
│       ├─ Camera3D                视角约 20°；旋转使用四元数轨迹球，能查看两极与背面
│       ├─ Sky                     星空（大球内表面 + 着色器）
│       └─ PlanetRoot (Node3D)     拖动时旋转的是它
│           ├─ Tiles (MeshInstance3D)        六棱柱网格 + planet.gdshader
│           ├─ Props (MultiMeshInstance3D)   草、小树（随星相出现）
│           ├─ Springs (Node3D)              浊泉漩涡
│           ├─ NodeMarkers (Node3D)          落点标记
│           ├─ Clouds (MeshInstance3D)       云层球壳
│           └─ Atmosphere (MeshInstance3D)   大气光晕
└─ UI (CanvasLayer)          顶栏、落点面板、队伍按钮……
```

### 4.2 战场 `battle_scene.tscn`

```
BattleScene (Node3D)
├─ WorldEnvironment           Glow、体积雾、色调、背景
├─ DirectionalLight3D         太阳，开阴影（按时辰设置角度和颜色）
├─ CameraRig (Node3D)
│   └─ Camera3D               固定透视，FOV 30°，俯角 40°，不旋转；CameraAttributesPractical（景深）
├─ Board (Node3D)
│   ├─ Ground (MeshInstance3D)          所有地块拼成一个网格，tile.gdshader
│   ├─ Water (MeshInstance3D)           水面，water.gdshader
│   ├─ Border (MeshInstance3D)          沙盘外两格的边缘
│   ├─ Decor (Node3D)                   装饰精灵（Sprite3D / MultiMesh）
│   ├─ Portal(s) (Node3D)               浊泉口：漩涡 + 粒子 + 紫色点光
│   └─ Heart (Node3D)                   心的精灵 + 点光；载具悬在上方
├─ Units (Node3D)             小妖精灵（AnimatedSprite3D）
├─ Enemies (Node3D)           浊和首领
├─ Fx (Node3D)                弹道、闪电、粒子（对象池）
├─ Overlay (Node3D)           格子高亮、射程、相邻连线、可关闭的预测路径（贴地的平面）
└─ UI (CanvasLayer)           顶栏、左右栏、出阵栏、弹窗
```

### 4.3 转场（SceneDirector）
1. 星球视图：落点区域拉近 1.2 秒。
2. 屏幕截一帧 → 盖一层全屏的像素溶解着色器（方块从 1 变大到 16）。
3. 后台加载战场：读模板、生成网格、放装饰（< 0.3 秒）。
4. 溶解反向（方块从 16 变小到 1），露出灰色的战场 → 落地演出 → 布阵。
5. 回去时反过来；星球视图恢复到之前的旋转，从落点拉远后播放星球上的净化动画。

两个场景都常驻内存（星球很小），切换时只切换显示和处理，不重新生成星球。

---

## 5. 星球（地图）

### 5.1 生成六边格球（Goldberg）

```
输入：n（每条边分几段）= 6
1. 建正二十面体（12 个顶点、20 个三角面）。
2. 每个三角面按 n 细分成 n² 个小三角形，所有新顶点投影到单位球面，按坐标去重。
3. 得到 10n² + 2 = 362 个顶点。每个顶点就是一个格子的中心。
4. 邻居 = 和它共享边的顶点（12 个格子有 5 个邻居，其余 6 个）。
5. 每个格子的轮廓 = 它周围小三角形的重心，按角度排序。
6. 建网格：每格一个六棱柱（顶面 = 轮廓按地形高度外推，侧面连回半径 1），顶点带格子编号。
```

### 5.2 地形和浊泉
- `FastNoiseLite`（Simplex，3D，按格子中心方向取样）。高度分档：水 20%、山石前 2.8%–11.5%、雪顶前 2.8%。
- 浊泉：3 口，陆地、不挨水、高度排名 20%–80%，彼此夹角至少 75°；离降临点最远的是星心之泉。
- 每局随机种子；第一局用固定的教学种子；每日星球用日期当种子。
- 每格的地形、浊、清亮、高亮打进一张数据纹理（32 × ⌈格数 ÷ 32⌉），着色器按格子编号读。

### 5.3 落点区域
- 落点 = 中心格 + 两圈 = 19 格。`RegionProfile`：各地形的比例、离最近浊泉的格数和方向、浊气、特征。
- `RegionProfile` 交给战场模块选模板（第 6 节）。

### 5.4 一局的推进
- `RunGen.new_run(seed, meta)`：生成星球、浊泉、降临点，检查连通，不合格换种子（最多 20 次）。
- `NodeGen.offer(run)`：每个时辰 3 个候选落点（[07](07_一局的结构与局外成长.md) 第 5 节）。
- `Run.advance_time()`：时辰前进，一天结束时结算浊潮和浊的退去。
- 种子派生：每个系统用自己的子种子（例如 `hash(种子, "nodes", 时辰编号)`）。

---

## 6. 战场（沙盘）

### 6.1 选模板和生成
```
BattlefieldGen.build(profile, run, rng) → Battlefield
1. 按 profile 选家族（规则见 data/战场模板 第 3 节）。
2. 在家族里选一个这一局还没用过的模板；入口压力与地貌来自 profile；不使用长路/短路模板。
3. 50% 左右镜像。
4. 从 d 标记里选 1–2 个露眼格（露眼特征 +1）。
5. 按家族的装饰表，在空格子上随机撒小装饰（不占格）。
6. 由地形与占格构建四邻接通行图，对每个入口 BFS/A* 到中心心。
7. 校验（和模板校验工具同一套规则），不通过就换模板。
```

### 6.2 数据
`Battlefield`：宽、深、每格的地形、高度、标记、可部署性、占格、露眼、通行图、各敌人当前动态路径、多个入口、中心心、装饰列表。这是战斗模拟的输入，和画面无关。

### 6.3 模板文件
- `art/battlefields/<id>.json`，字段见 [data/战场模板](data/战场模板.md) 第 1 节；不含道路层。
- `tools/validate_battlefields.gd`：校验全部模板（入口到心及活敌到心连通、占格变化合法、露眼数量、尺寸、数据合法）。每次改模板都跑，持续集成里也跑。

---

## 7. 战斗模拟

### 7.1 基本
- **固定步长 30 Hz**，与帧率无关。1×、2×、3× 推进不同步数；暂停不推进。
- **确定性**：每场一个种子；同样的种子加同样的命令 = 同样的结果。
- `Battle.new(battlefield, team, waves, rng)` → 反复 `step()` → `result()`。

### 7.2 坐标
- 格子坐标 `(x, y)`，格子中心在 `(x + 0.5, y + 0.5)`；世界坐标里 1 格 = 1 米，高度每级 0.5 米。
- 小妖固定在格子中心（结缘战里走动时在相邻格子中心之间插值）。
- 地面浊按当前 BFS/A* 路径移动，在相邻格中心间插值；占格变更重算路径，拒绝彻底封路操作，拦截邻格经过的敌人。完整规则见 04 第 2.3 节。
- 飞行的浊：从浊泉口直线飞向心。
- 距离：两点在平面上的直线距离（格），不算高度。
- 相邻：上下左右。

### 7.3 每一步的顺序

```
1. 处理玩家命令（增援、换位、唤醒、载具技能）
2. 出生：按波次表放出新的浊；首领的计时技能
3. 移动：地面浊动态寻路前进；被拦住的停下；飞行的直线前进；结缘战的小妖走位
4. 拦：分配拦截（每个拦最多拦 N 只地面浊）
5. 选目标（按定位的规则，见 04 第 4.5 节）
6. 出手：普攻或主技 → 生成弹道（有飞行时间，不做物理碰撞）
7. 结算到达的弹道：伤害、溅射、跳跃、控制、治疗、护盾
8. 持续效果到期
9. 经济：产露
10. 浊到达心：扣心灯
11. 胜负判定和波次推进
12. 输出这一步的事件列表
```

### 7.4 技能用数据描述
技能是「效果」的列表，大部分不写代码：

```json
{
  "id": "skill.dida_lianzhu",
  "target": "nearest_to_heart",
  "effects": [
    { "type": "projectile", "count": 3, "interval": 0.15, "speed": 6,
      "on_hit": [ { "type": "damage", "scale": 0.8 }, { "type": "slow", "amount": 0.35, "duration": 1.2 } ] }
  ]
}
```
首领的特殊机制用脚本钩子实现。

### 7.5 模拟工具
- **战斗模拟**：`godot --headless --path . --script res://tools/balance_sim.gd -- --template grass_01 --team dida,taituan,dengxin --runs 2000`，输出胜率、掉的心灯、时长、露水收支、每只小妖的伤害占比。
- **整局模拟**：自动选落点、自动布阵、自动选奖励，跑上千局，对照 [07](07_一局的结构与局外成长.md) 第 9 节的目标。
- **回放**：记录「种子 + 模板 + 布阵 + 带时间戳的命令」，出 bug 时一键重现。

---

## 8. 战场渲染

### 8.1 地块网格
像素风的世界统一低分辨率视口+最近邻输出，线条风用高清二维美术纹理；以下描述几何生成，不能取代 09 的画风规则。景深/泛光不能糊掉主体像素。

- 运行时把整个沙盘拼成**一个** `ArrayMesh`：每格一个顶面四边形，高度 ≥ 1 的格子再加看得见的侧面。顶面和侧面的 UV 指向地块图集里对应的贴图（按格子哈希选变体）。
- 顶点带格子编号（`CUSTOM0`），`tile.gdshader` 按编号从数据纹理读：`murk`（浊）、高亮状态、动态预测路径高亮、是否露眼。
- `tile.gdshader`：普通的 spatial 着色器（**不是 unshaded**，吃引擎光照），在 `fragment()` 里：
  1. 读图集颜色（最近邻）；
  2. 浊：按 `murk` 把颜色换成灰（和浊色表一致的灰），清亮过渡时用每像素哈希阈值；
  3. 路径提示：仅部署/调试时轻量显示实时结果，不改变地面为永久紫色道路；
  4. 高亮：可放（亮黄描边闪烁）、不可放（红边）、射程（变亮）；
  5. 高差边：读邻格高度，高的一侧边缘 1 像素变亮，低的一侧变暗。
- 水面单独一个网格，`water.gdshader`：波纹、闪光，略微透明。

### 8.2 精灵
- 小妖、浊、装饰都用 `Sprite3D` / `AnimatedSprite3D`：
  - `billboard = Y`（绕竖直轴对着镜头）；
  - `texture_filter = nearest`；
  - `alpha_cut = Opaque Pre-Pass`（这样透明边缘能正确排序、能投影——HD-2D 最常见的坑）；
  - `pixel_size = 1/16`（16 像素 = 1 米）；
  - `shaded = true`（吃光照）。
- 需要浊化、异色、受击变白时，用一个自定义的 `sprite.gdshader` 作为 `material_override`：读贴图颜色 → 按模式换色 → 交给引擎光照。
- 发光像素：图集旁边一张发光遮罩，着色器里把这些像素写进 `EMISSION`，触发泛光。

### 8.3 光和后期
- 太阳：`DirectionalLight3D`，开阴影，按时辰设置角度、颜色、强度。
- 点光：`OmniLight3D`，心、载具、灯芯、萤子、火团、灯照、浊泉口。数量上限 16（超过时按距离关掉远的）。
- `WorldEnvironment`：Glow（高阈值）、体积雾（夜、雾天）、色调调整；色调映射用 Filmic 或 AgX（这时不再要求屏幕颜色锁在调色板里）。
- 景深：相机的 `CameraAttributesPractical`，打开近处和远处虚化。
- 暗角：一个很轻的后期着色器。

### 8.4 星球视图的渲染
- 480×270 的 SubViewport，`planet.gdshader`：地块底色 + 少量像素杂点（三平面投影一张 16×16 的程序贴图）+ 浊的灰 + 清亮过渡 + 高亮；光照用 2–3 档阶梯明暗（简单的 `dot(法线, 太阳)` 分档）。
- 星球视图很简单，不需要点光和阴影。

---

## 9. 美术导入
- `addons/qinghuan_art/` 的编辑器导入插件读字符画 JSON（精灵、地块），生成：
  - 精灵：RGBA8 贴图（每帧一格的图集）+ 发光遮罩 + `SpriteFrames`（含派生帧和动画）；
  - 地块：一张地块图集（每格 16×16 / 16×8）+ 每种地形的 UV 表。
- 战场模板在运行时读（文件很小）。
- 调色板：从 `art/palette/endesga32.json` 读；浊色表、异色表做成一张小的换色纹理给 `sprite.gdshader` 和 `tile.gdshader` 用。
- 一致性测试：同一份字符画，导入后的贴图逐像素等于源数据。

---

## 10. 存档

| 文件 | 内容 | 什么时候存 |
|---|---|---|
| `user://meta.json` | 星砂、心灯之树、羁绊、传承栏、解锁、浊深、故事进度、统计 | 回到小院时、局末结算后 |
| `user://run.json` | 种子、时辰、星球每格的 `murk` 和 `clear`、浊泉状态、当前候选落点、已用过的模板、队伍、星签、心意、露罐、心灯 | 每次回到星球视图（选落点之前） |

- 地形不存，用种子重新生成。战斗中不存档；战斗中退出，下次从这场战斗之前继续。
- 最外层有 `version`，读档时按版本号依次跑迁移函数。

---

## 11. 本地化
- 所有文字放 `data/i18n/<语言>.csv`，代码里不写死中文。
- 构建检查：每个键在每种语言都有；每个字都在像素字体里有字形。

---

## 12. 音频实现
- 音乐分层用 `AudioStreamSynchronized`，状态切换（星球 ↔ 战斗 ↔ 胜利）用 `AudioStreamInteractive`。
- `AudioDirector`：星相 → 打开哪些声部；时辰 → 低通；音效限流；结缘、化形时压低音乐。

---

## 13. 性能预算

目标：Steam Deck 上 60 帧。

| 项 | 预算 |
|---|---|
| 战场地块 | 一个网格，约 150 格（含边缘），一次绘制 |
| 战场精灵 | ≤ 150（小妖 ≤ 10、浊 ≤ 40、装饰 ≤ 80、特效另算） |
| 点光 | ≤ 16，阴影只给太阳 |
| 粒子 | 同屏 ≤ 1500 |
| 星球视图 | 480×270，很便宜 |
| 战斗模拟 | 30 Hz，每步 ≤ 1 毫秒 |
| 转场加载战场 | ≤ 0.3 秒 |

---

## 14. 测试与工具

| 类别 | 内容 |
|---|---|
| 单元测试 | 六边格球、落点生成、浊潮、战场生成（模板选择、镜像、动态通行图）、伤害公式、经济、合流、传承、存档迁移 |
| 模板校验 | 全部战场模板通过 [data/战场模板](data/战场模板.md) 第 2 节的规则 |
| 模拟测试 | 固定种子的战斗和整局，结果和「金标准」比对 |
| 美术测试 | 每个字符画都能导入；导入结果逐像素一致；已确认的版本哈希没变 |
| 调试面板 | 改星相、改时辰、立刻胜利、加露水、显示格子坐标和动态路线、显示光源范围、直接打开某个模板 |
| 截图脚本 | 按种子、模板、时辰批量截战场和星球，用来对比画面改动（必须有窗口运行） |
