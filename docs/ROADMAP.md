# ROADMAP

> **铁律：每个里程碑结束时，游戏都必须是「可玩」的。**
> 不允许出现"这块做了一半，下块先做着"的状态 —— 那是 3D 项目失控的头号原因。

---

## M0 · 骨架与核心闭环 ✅ 已完成

**目标**：项目能打开、能跑、能玩通一条种植循环、测试全绿。

- [x] `project.godot`：Forward+ 渲染器、Jolt 物理、MSAA 4x、输入映射
- [x] GDScript 警告设为 Error（`untyped_declaration` / `unsafe_*`），`addons/` 豁免
- [x] 四层目录结构 + `.gitignore` / `.gitattributes`（含 Git LFS 规则）
- [x] L3 单例：`EventBus` / `GameManager` / `TimeManager` / `SaveManager`
- [x] L2 纯逻辑：`Clock` / `Weather` / `FarmTile` / `FarmGrid` / `CropGrowth`
- [x] L1 数据：`CropData` / `CropDatabase`（9 种作物）
- [x] L4 表现：`Player`（相对相机移动）/ `CameraRig`（固定斜俯视）/ `FarmView`（射线拾取）/ `SunController` / `Hud`
- [x] GUT 单元测试：`test_farm_grid` / `test_clock` / `test_crop_growth`
- [x] 占位渲染：代码生成的纯色土地与作物，零素材依赖

**M0 的关键决策（不要推翻）**
- 渲染器锁 **Forward+** ⇒ **不做 Web 版**
- 相机锁 **固定斜俯视 −52° / FOV 40° / 90° 分步旋转**
- 农田格位用 `Vector2i` ⇒ L2 层与维度无关

---

## M1 · 素材与视觉

**目标**：把占位方块换成真实低多边形素材，画面第一次"像个游戏"。

- [ ] 下载并归类 CC0 素材（Kenney Nature Kit / Quaternius / KayKit），生成 `assets/CREDITS.md`
- [ ] 建立 `MeshLibrary` + 用 `GridMap` 替换 `FarmView` 的占位网格
      ⚠️ 三条铁律：`cell_size` 铺格子后不可改 · GridMap 不自动烘焙导航 · MeshLibrary item 必须带碰撞形状
- [ ] 作物模型：优先 `CropData.stage_scenes`，兜底 `stage_scales`
- [ ] 玩家角色替换为带骨骼动画的模型（8 方向移动动画）
- [ ] `WorldEnvironment` 调优：天空盒 HDRI、色调映射、环境光
- [ ] 季节视觉切换 `systems/season_visuals.gd`（植被色调 / 天空 / 太阳高度角）

**出口标准**：能截一张"看起来像成品"的图。

---

## M2 · 系统补全

- [ ] 背包系统（24 格）`core/inventory.gd` + `ui/inventory_panel.tscn`
- [ ] 工具切换与快捷栏（锄头 / 水壶 / 镰刀 / 斧头 / 镐）
- [ ] 商店与买卖 `core/shop.gd` + `ui/shop_panel.tscn`
- [ ] 出货箱
- [ ] 存档/读档菜单（替换 M0 的 F5/F9 调试快捷键）
- [ ] 主菜单 + 存档槽选择 `scenes/boot/`
- [ ] 音效与 BGM `autoload/audio_manager.gd`

---

## M3 · 内容与打磨

- [ ] 建筑与建造（鸡舍 / 谷仓 / 栅栏）
- [ ] 畜牧
- [ ] 节日与事件
- [ ] 成就与统计
- [ ] 性能预算核对（见 DESIGN.md §5.6）

---

## v2 待办（**故意排在最后，防止悄悄插队**）

3D 首版刻意砍掉的三个系统。**加回来的顺序就是下面这个顺序** —— 矿洞永远最后。

1. **NPC 与好感度** —— 对话系统、送礼、日程表。风险：日程表是一张巨大的状态机
2. **钓鱼** —— 小游戏 + 鱼类表 + 季节/天气/时间绑定。风险：手感需要在真机上反复调
3. **矿洞与战斗** —— 程序化生成 + 战斗。**风险最高**（层级生成 + 掉落 + 战斗手感 + 存档体积），
   所以排在最后：**砍掉它游戏依然完整**。

---

## 已明确否决的方向（不要再提）

| 方案 | 否决理由 |
| --- | --- |
| **导出 Web 版** | 与 Forward+ 渲染器互斥。Godot 的 Web 导出只支持 Compatibility，改回去要重做全部材质与光照 |
| **做主机版** | Godot 无原生主机导出，需第三方移植商。真要做就该重估引擎选型 |
| **中途升到 Godot 4.8** | 官方承认小版本可能有兼容性破坏 |
