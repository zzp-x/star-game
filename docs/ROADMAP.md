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

## M0.5 · 手感与观感补完 ✅ 已完成

**目标**：M0 虽然"能跑通"，但玩家反馈「移动控制不了」+「画面和 UI 太 low」。
先把手感和观感拉到及格线，再谈换素材 —— 否则 M1 换上的素材也救不回一个走不动路的角色。

- [x] **修移动失效**：`farm.tscn` 的 `Ground` 原本只有网格没有碰撞体，玩家一直在下坠。
      补 `StaticBody3D` + `BoxShape3D(200,2,200)`
- [x] **修朝向反向**：`atan2(dir.x, dir.z)` 对齐的是局部 +Z，但 Godot 的正前方是 −Z，
      角色在倒着走。改为 `atan2(−dir.x, −dir.z)`
- [x] **修体力扣减顺序**：`use_tool()` 原为「先扣体力再校验」，季节白名单拒绝时体力已损失。
      改为「先校验 → 再扣 → 再执行」
- [x] 程序化草地贴图 + 农田格线 `scripts/world/proc_textures.gd`（零图片依赖）
- [x] 场景装饰 `scripts/world/scenery.gd`：树/灌木/石头/栅栏，固定种子可复现
- [x] 玩家模型换成方块拼的小人 + 走路起伏动画
- [x] HUD 按星露谷风格重做：`ui_theme` / `ui_icon` / `hud_status` / `hud_hotbar` / `hud_energy` / `hud_toast`
- [x] 集成测试 `test/integration/test_player_movement.gd`（含**反证用例**：无碰撞体时必须下坠）
- [x] **修输入映射表脱节**：`project.godot` 里只定义了 `tool_1`~`tool_5`，
      而代码直接用 `physical_keycode - KEY_1` 自己算 —— 映射表成了摆设。
      补齐 `tool_1`~`tool_9`，代码改为按动作名查找（`GameManager.slot_for_event`），
      并由 `test/integration/test_input_map.gd` 守住

**M0.5 的关键教训（写下来，别再犯）**
- **「解析通过 + 单元测试全绿 + 无头冒烟通过」≠「能玩」**。移动失效这个 bug
  在三种检查下全部通过，因为三者都不同时包含「玩家 + 物理 + 地面」。
  → 涉及"手感"的东西**必须放集成测试或实机**，不能靠单元测试兜底。
- **写测试时要问「这条测试有可能失败吗」**。所以 `test_player_movement.gd` 里
  特意留了一条反证用例 —— 没有它，那 8 条测试可能只是在自说自话。
- **配置文件和代码是两份事实，必须有人守着它们对得上**。输入映射表脱节这个坑
  不会报错、不会崩、测试全绿，只是"你按的键没人听"。
  → 凡是「配置里声明一次、代码里再用一次」的东西（输入动作、资源路径、枚举映射），
  都值得配一条一致性测试。

**顺手清理（M2 会用到的预留）**
- `project.godot` 里另有 `open_inventory`（`Tab`）与 `cancel`（`Esc`）两个动作，
  目前**无代码引用**，是给 M2 的背包/菜单预留的。别当成死配置删掉。

---

## M1 · 素材与视觉

**目标**：把占位方块换成真实低多边形素材，画面第一次"像个游戏"。

> M0.5 的 `proc_textures.gd` / `scenery.gd` 是**程序化占位**，不是终点。
> M1 要用真实 CC0 素材替换它们，并把玩家换成带骨骼动画的角色。
> 保留它们作为"素材缺失时的兜底"，别删。

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
