# 《清欢小星》统一美术与界面重设计提案

2026-10-22。基于官方资料研究与当前实机问题分析。**这是方案，不是新实机截图，也不是已验收成品。**

## 推荐组合

**露光苔湾 + 林湾环抱式 HUD。**

- 世界：从完整悬浮方盘改成自然延伸的林间空地。逻辑仍是 11×7 自由方格，水湾、树石和高台不把通路夹成固定车道。
- 美术：晨光、苔绿、陶土、青蓝水面，心灯为暖色焦点。前中后景靠大形、遮挡和明暗层次，不靠模糊滤镜。七只小妖先区分剪影和材质，再做局部逐帧动作。
- 界面：场景连续铺底。顶角心灯与时间控制，底部完整七人托盘，右下露水和灯照组合；入口威胁、睡眠和部署合法性在场景中表达。无选择时收起详情，避免说明书排版。
- 星球：保留真三维全向旋转；先聚焦一个落点，再显示一张信息卡并确认。地图和战场地貌色一致。
- 小院：让现有永久升级、选伙伴和出发入口依附场景物件，而不是管理面板；不新增经营玩法。

## 为什么这样改

原画面的问题不是素材少，而是均匀方台、围圈摆树、相似亮度的细节与等权信息框。继续加树或放大棋盘，不能建立地点感和阅读顺序。新版先解决整幅构图与操作空间，再增加细节。

## 研究依据

- [Eastward Octopia](https://store.steampowered.com/app/2305370/Eastward__Octopia/)：参考生活材质与画面疏密，不复制房屋、角色和布局。
- [Sea of Stars](https://seaofstarsgame.co/)：参考材质形状和局部光，不照搬渲染管线。
- [Octopath II 开发者访谈](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style?lang=en-US)：参考二维角色与三维场景协调，舍弃重景深。
- [Dorfromantik 开发日志](https://toukana.itch.io/dorfromantik-prototype/devlog/198346/devlogromantik-2-biomes-boats-and-more-big-news-soon)：开发者将部分清单信息移回世界内；本作据此把可定位的战况提示放回场景。
- [Into the Breach](https://store.steampowered.com/app/590380/Into_the_Breach/)：参考威胁与对象信息的归位，不采用回合制规则。

各来源的官方陈述、实际截图观察与本项目设计推论，已在两份详稿分别标明。

## 文件怎么读

1. art_direction.md：美术推荐方案与备选「月白苔庭」、七只角色、空间材质光照及验收标准。
2. ui_layout.md：推荐布局与备选「底座式战术台」、双窗口坐标、全流程交互与规则边界。
3. ui_wireframes.png、ui_wireframes_1180.png：大/小窗口战斗布局示意。
4. planet_wireframe.png：星球聚焦布局示意。
5. 同名 SVG：可编辑线框源文件。圆圈、色块只表示占位与空间，不是最终像素美术。

## 下一步

先按推荐组合做一张同种子、七人完整 HUD 的森林战场样片及短动作片段，用户确认整幅效果后再推广到星球、小院与其他地貌。本轮没有修改原 docs 或游戏代码，没有把参考图片导入工程。仅做像素风，继续遵守 ENDESGA32、代码生成资产和整数最近邻显示。
