# Star Game

3D 低多边形农场生活模拟（星露谷 like）。固定斜俯视相机，桌面平台。

> **当前状态：M0.5 已完成** —— 骨架 + 核心农场闭环 + 手感/观感补完（星露谷风格 HUD、程序化场景）。
> 完整设计方案见 [`docs/DESIGN.md`](docs/DESIGN.md)（v3.0），进度见 [`docs/ROADMAP.md`](docs/ROADMAP.md)。

---

## 环境要求

| 项 | 版本 | 说明 |
| --- | --- | --- |
| **Godot Engine** | **4.7.2 stable（标准版）** | ⚠️ **不是** `.NET` 版。GDScript 项目用标准版即可 |
| Git | 任意近期版本 | |
| Git LFS | ≥ 3.0 | 3D 模型/音频走 LFS，首次克隆后执行 `git lfs install --local` |

**下载**：<https://godotengine.org/download/windows/> → 选 **Godot Engine**（zip 约 70MB，解压即用，绿色免安装）。

**不要用 Steam / itch.io 上的 Godot**；也**不要碰 4.8-dev**（开发快照，官方明确"不建议用于生产"）。

> **版本纪律**：补丁版（4.7.3、4.7.4…）向后兼容，可放心升级；
> 小版本（4.8）可能有兼容性破坏，**项目进行中不要中途换**。
> 请把引擎版本写进团队约定，避免"你能跑我跑不了"。

---

## 快速开始

### 方式一：一键脚本（推荐）

```bash
git clone git@github.com:zzp-x/star-game.git
cd star-game
git lfs install --local
```

克隆完，按需要挑一个：

| 想要 | Windows（双击） | macOS / Linux |
| --- | --- | --- |
| **运行游戏** | **`run.bat`** | `./run.sh` |
| 打开编辑器 | `editor.bat` | `./run.sh editor` |
| 跑测试 | `test.bat` | `./run.sh test` |
| 导入检查 + 测试 | — | `./run.sh check` |
| 只看引擎在哪 | — | `./run.sh where` |

脚本替你做了三件事：

1. **自动找到 Godot** —— 依次查找 `-GodotPath` 参数 → 环境变量 `SG_GODOT` →
   仓库根目录的 `.godot-path` 文件 → `D:\Godot` 等常见目录 → `PATH`
2. **首次运行自动导入资源** —— 全新克隆时 `.godot/` 不存在，会先跑一次 `--import`（约 10～40 秒）
3. **额外参数原样转发** —— 例如 `run.bat --headless`、`./run.sh play --quit-after 120`

找不到引擎时，`run.bat` 会询问是否**自动下载**官方 4.7.2 标准版。

> **Windows 上执行策略禁止运行 `.ps1` 也不影响使用** —— `.bat` 内部走
> `powershell -ExecutionPolicy Bypass -File`，无需改系统设置。
> 若你所在环境由组策略强制禁用脚本，请改用下面的方式二。

环境变量（可选）：

| 变量 | 作用 |
| --- | --- |
| `SG_GODOT` | 直接指定 Godot 可执行文件绝对路径 |
| `SG_NO_PAUSE` | 置 1 则脚本结束时不"按任意键"（供 CI 调用） |
| `SG_NO_DOWNLOAD` | 置 1 则禁止自动下载 Godot |

结束时的暂停规则：`run.bat` / `editor.bat` **只在失败时**暂停（成功时窗口直接关掉，
游戏和编辑器有各自的窗口）；`test.bat` **总是**暂停，因为测试报告就是要看的。

### ⚠️ 改 `.bat` 前必读：这些文件必须保持「纯 ASCII + CRLF」

`.bat` 里**一个非 ASCII 字符都不能有** —— 包括 `rem` 注释。原因不是显示乱码那么简单：

> **cmd.exe 按「字节」跟踪自己在批处理文件里读到哪，却按「代码页」解码字符。**
> 文件里只要出现多字节字符（中文即 UTF-8 三字节），两者就会**错位**，
> 后续行被从中间截断、`rem` 注释被当命令执行，报一堆"不是内部或外部命令"。

所以：**所有中文提示都写在 `tools/godot.ps1` 里**（它是 UTF-8 带 BOM，PowerShell 能正确解码），
`.bat` 只做一层极薄的壳。同理行尾必须是 CRLF（`.gitattributes` 里已用
`*.bat text eol=crlf` 强制，别把它删掉）。

这条约束有**两道自动检查**兜底，正常运行时无感，一旦违规就会告警：

- `tools/godot.ps1` —— Windows 侧，每次启动前扫一遍仓库根目录的 `*.bat`
- `run.sh` —— 同一份检查，方便 Linux / macOS 上的 CI 提前拦住

### 方式二：手动命令

```bash
godot --path . --editor                               # 打开编辑器（会自动导入资源）
godot --path .                                        # 直接跑游戏
godot --headless -s addons/gut/gut_cmdln.gd -gexit    # 跑全部测试
```

---

## 操作

| 操作 | 键 |
| --- | --- |
| 移动 | `W A S D`（**相对相机方向**） |
| 跑步 | `Shift`（按住） |
| 使用手持物 | `鼠标左键`（作用于鼠标指向的格子） |
| 旋转相机 | `Q` / `E`（90° 分步） |
| 缩放 | `鼠标滚轮` |
| 边缘平移 | 鼠标移到屏幕边缘 |
| 手持格位 | `1`–`9`、`0`、`-`、`=`（共 12 格） |
| 菜单 / 退出 | `ESC`（也可点右上角「菜单」按钮） |
| 过夜 | `F10` |
| 存档 / 读档 | `F5` / `F9` |

> 移动是**相对相机**的：`W` 永远是"朝屏幕上方走"，不是"朝世界 −Z 走"。
> 这是固定斜俯视相机的必然要求 —— 否则转过 90° 后 `W` 就会变侧向。
>
> ⚠️ **朝向约定**：Godot 里节点的"正前方"是局部 **−Z**（不是 +Z）。
> 让角色面朝移动方向必须用 `atan2(−dir.x, −dir.z)`；写成 `atan2(dir.x, dir.z)`
> 会把角色的**背面**对着前进方向 —— 表现为"倒着走"，而且很容易看漏。

> ⚠️ **输入映射表就是事实来源**：`tool_1`…`tool_12` 这些动作定义在 `project.godot` 的
> `[input]` 段，代码通过 `InputMap` 读它们，**不要**图省事直接在代码里比 `Key` 常量。
> 那样映射表会变成摆设 —— 别人照着它改键，游戏里毫无变化，排查到怀疑人生。
> 这个项目已经真的踩过两次：先是只有 `tool_1`~`tool_5`，扩到 12 格后
> `tool_10`~`tool_12` 又一次成为缺口（`test/integration/test_input_map.gd` 会拦住你）。


**核心闭环**（手持什么，就只能做什么）：

```
按 1（锄头）    左键点草地 → 翻地
按 4（芜菁种子）左键点已翻土 → 播种
按 2（洒水壶）  左键点已播种的土 → 浇水（土壤变深色）
F10             → 过夜（下雨天会自动浇水）
重复 4 次       → 芜菁成熟（变成金色发光）
按 3（镰刀）    左键点成熟作物 → 收获，金币增加
```

> 快捷栏布局：**前 3 格是工具（锄头 / 洒水壶 / 镰刀），后 9 格是种子**。
> 拿错工具时不会"顺便帮你做了"，而是明确提示该换哪件 ——
> 这是刻意的：M0 的「左键智能操作」虽然上手快，但快捷栏形同虚设，
> 玩家的选择没有任何意义。

---

## 单元测试（GUT）

测试框架：[GUT](https://github.com/bitwes/Gut) **9.7.1**（对应 Godot 4.7）。

**已经随仓库提供**（`addons/gut/`，259 个文件已入库），克隆后**无需安装**，
只需在编辑器里 **Project → Project Settings → Plugins** 勾选启用 **Gut** 即可。

最省事的方式：**双击 `test.bat`**（Windows）或 **`./run.sh test`**（macOS / Linux）。
等价的原始命令如下：

```bash
# 命令行跑全部测试（可接 CI）
godot --headless -s addons/gut/gut_cmdln.gd -gexit

# 只跑单元测试（纯逻辑，约 1 秒）
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

# 只跑集成测试（跨 autoload / EventBus 的接线验证）
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/integration -gexit

# 单个文件
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_farm_grid.gd -gexit
```

**当前状态：8 个测试脚本 · 106 个测试 · 463 条断言 · 全部通过。**

> **单元测试的测试对象不启动场景树、不渲染任何东西、不需要任何素材。**
> 因为游戏规则全部写在 `scripts/core/` 的纯逻辑类里。这是架构最重要的一条回报。
>
> `test/unit/` 验证「规则对不对」，`test/integration/` 验证「接线通不通」——
> 后者抓到过两个单元测试永远发现不了的 bug：
> ① 作物生长用了错一天的天气（详见 `docs/DESIGN.md` §3.4 的 `day_ended` 说明）；
> ② 玩家**根本无法移动** —— `farm.tscn` 的地面只有网格没有碰撞体，角色一直在下坠。
>
> ⚠️ **教训**：第 ② 个 bug 在「解析通过 + 单元测试全绿 + 无头冒烟通过」三种检查下
> 全部通过，因为三者都不包含「玩家 + 物理 + 地面」这三样同时在场的东西。
> **涉及"手感"的东西必须在集成测试或实机里验证，不能靠单元测试兜底。**
>
> 另外 `test_player_movement.gd` 里特意留了一条**反证用例**
> （把地面碰撞体删掉，玩家必须掉下去）—— 一条不可能失败的测试等于没测。


---

## 目录结构

```
star-game/
├─ run.bat / editor.bat / test.bat   # ★ Windows 一键脚本（双击即用）
│                                    #   ⚠ 必须保持纯 ASCII + CRLF，见上文
├─ run.sh                            # ★ macOS / Linux 等价脚本
├─ tools/godot.ps1                   # 启动器本体：定位 Godot + 分发动作
│                                    #   ⚠ 必须保持 UTF-8 带 BOM，否则中文乱码
├─ project.godot          # ★ 渲染器 / 物理 / 输入映射 / 警告等级都在这里
├─ .gitattributes         # Git LFS 规则（*.glb / *.wav / *.hdr …）
├─ .gutconfig.json        # GUT 测试配置
├─ .godot-path            # 可选：固定 Godot 路径（一行绝对路径，不提交也可）
├─ docs/
│  ├─ DESIGN.md           # ★ 完整设计方案 v3.0（1973 行）
│  ├─ ROADMAP.md          # 里程碑进度 + v2 待办
│  └─ BALANCE.md          # 数值表与改动纪律
├─ assets/                # 所有素材（3D 模型统一用 GLB/glTF）
│  └─ CREDITS.md          # ★ 素材授权与来源
├─ data/                  # 数据驱动：Resource 实例（.tres）
├─ scenes/                # Godot 场景（.tscn）；`_debug_shot.*` 只用于实机截图验收
├─ scripts/
│  ├─ autoload/           # L3 单例：EventBus / GameManager / TimeManager / SaveManager
│  ├─ core/               # ★ L2 纯逻辑：规则都在这里，可 GUT 直接测
│  │                      #   含 Hotbar / HotbarEntry（快捷栏布局）
│  ├─ data/               # L1 数据：CropData / ToolData 及各自数据库（含 icon_color）
│  ├─ actors/
│  │  ├─ player.gd        #   角色移动 + 朝向（−Z 约定）+ 走路动画（绕关节摆动）
│  │  └─ camera_rig.gd    #   固定斜俯视相机，Q/E 90° 分步旋转
│  ├─ world/
│  │  ├─ farm_view.gd     #   射线拾取格子 + 按状态刷新作物外观
│  │  ├─ proc_textures.gd #   程序化草地/农田格线贴图（零图片依赖）
│  │  └─ scenery.gd       #   树/灌木/石头/栅栏，固定种子可复现
│  └─ ui/
│     ├─ ui_theme.gd      #   星露谷 UI 主题：三层木框 9-slice + 烤进贴图的硬投影
│     │                   #   + 立体格子（落影高光）+ 选中格金色辉光 + 按钮三态
│     ├─ ui_icon.gd       #   全部图标用 _draw() 手绘（作物/金币/天气/季节/工具）
│     ├─ hud.gd           #   HUD 装配 + 按 1080p 基准缩放 + 日期木牌横幅
│     ├─ hud_status.gd    #   右上：日期 / 时钟 / 天气 / 金币（图标带"勋章"圆底衬）
│     ├─ hud_hotbar.gd    #   底部居中：12 格快捷栏 + 悬挑名称木牌 + 圆形按键徽章
│     ├─ hud_energy.gd    #   右下：厚木框体力条
│     ├─ pause_menu.gd    #   独立 CanvasLayer：ESC 呼出，继续/保存/退出
│     └─ hud_toast.gd     #   浮动提示（自己管生命周期）
└─ test/
   ├─ unit/               # GUT 单元测试（规则对不对）
   └─ integration/        # GUT 集成测试（接线通不通）
```

---

## 四层架构（**改动代码前请先读这一节**）

```
L4  表现层        scripts/actors/ world/ ui/ props/
    └ 只负责：显示、动画、输入采集。不含任何游戏规则。
L3  单例层        scripts/autoload/
    └ 职责：编排、广播、跨场景共享状态。
L2  领域逻辑层    scripts/core/          ★ 纯 RefCounted，零节点依赖，可 GUT 单测
    └ 职责：全部游戏规则与状态计算。
L1  数据层        scripts/data/
    └ 职责：纯数据，可在 Inspector 里改。
```

**为什么要这样切？** 把「作物几天长成」「浇水加多少生长」写在 3D 节点脚本里，
就只能靠"点着玩"验证 —— 而在 3D 里手动验证一遍的成本远高于 2D
（要走到田里、要等太阳升起、要看动画）。抽到 L2 之后，GUT 可以 0.01 秒断言完。

**L2 的两条硬纪律：**
1. **不引用 EventBus**（那是 L3 的事）。操作成功与否用 `bool` / `int` 返回。
2. **不引用任何 Node / GridMap / 模型**。表现层订阅信号后自行刷新。

---

## GDScript 编码纪律

`project.godot` 里已经把这些警告**设成了 Error**，写错会直接报错拦住你：

```
debug/gdscript/warnings/untyped_declaration    = 2
debug/gdscript/warnings/unsafe_property_access = 2
debug/gdscript/warnings/unsafe_method_access   = 2
debug/gdscript/warnings/unsafe_cast            = 2
```

> `addons/` 目录已通过 `exclude_addons=true` 豁免，不会误伤第三方插件。

```gdscript
# ── 类型标注：每个变量、参数、返回值都要有 ──────
var speed: float = 4.5
var enemies: Array[Node3D] = []
func heal(amount: int) -> void: ...

# ── 类型推断用 := ─────────────────────────────
var velocity := Vector3.ZERO
@onready var _cam: Camera3D = $Camera3D

# ── 成员声明顺序（官方 style guide）────────────
# class_name/extends → 文档注释 → signal → enum → const
# → @export 变量 → 普通变量 → @onready 变量
# → _init → _ready → 其它虚函数 → 公开方法 → 私有方法

# ── 命名 ─────────────────────────────────────
# 文件/文件夹 snake_case · class_name PascalCase
# 函数/变量/信号 snake_case · 常量 CONSTANT_CASE · 私有成员前缀 _
# 缩进用 Tab

# ── 3D 特有提醒 ──────────────────────────────
# Vector3 的 y 是"上"，不是"里"。地面用 x/z，高度用 y。
# 把 Vector3 当 Vector2 用是最常见的 3D 新手 bug。
```

---

## 3D 项目的五个「别信默认」

前三条是 M0 的结论，后两条是 M0.5 被 bug 教出来的。

1. **渲染配置和 2D 是反的** —— 2D 用 `Stretch Mode = viewport` + 关抗锯齿；
   **3D 必须 `disabled`**（渲染到低分辨率再放大只会糊）**且必须开 MSAA**
   （低模硬边极多，关掉就是满屏爬行的锯齿）。
2. **`GridMap.cell_size` 一旦铺了格子就绝不能改** —— 它不会更新已有格子。
3. **鼠标拾取格子用 `Plane.intersects_ray()`**，不要射线查询物理世界 ——
   农田是水平面，数学求交更快更稳，还省掉每格的碰撞体。
4. **`MeshInstance3D` 不参与物理** —— 它只负责"画出来"。
   地面若只挂 `MeshInstance3D`，角色会**无限下坠**，而画面看起来只是"按了键没反应"
   （相机跟随角色一起掉，所以屏幕上一切正常）。
   地面必须额外挂 `StaticBody3D` + `CollisionShape3D`。
5. **节点的"正前方"是局部 `−Z`，不是 +Z** —— 也是摄像机的朝向。
   让角色面朝移动方向要用 `atan2(−dir.x, −dir.z)`；
   写成 `atan2(dir.x, dir.z)` 会让角色**倒着走**。两处约定必须一致，
   凡是暴露"我在朝哪"的接口（如 `facing_direction()`）都要按 −Z 写。

---

## 已知限制

- **本项目锁定 Forward+ 渲染器，因此无法导出 Web 版**。
  Godot 的 Web 导出只支持 Compatibility 渲染器（因为 Godot 尚不支持 WebGPU）。
  这是 M0 就定死的决策，见 DESIGN.md §2.4 —— 若将来需要 Web 版，需要专门做一次材质适配分支。
- M0 / M0.5 的**全部美术资源都是代码生成的** —— 草地贴图、农田格线、树/灌木/石头、
  玩家模型、HUD 面板与图标，没有任何 `.png` / `.glb`。
  好处是「clone 下来就能跑」；代价是观感上限有限。
  M1 会替换为 GridMap + 真实 CC0 低模，程序化版本作为素材缺失时的兜底保留。
- 玩家角色目前是**方块拼的静态小人 + 走路起伏**，没有骨骼动画、没有 8 方向动画。
  同样属于 M1 的替换范围。
