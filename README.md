# Star Game

3D 低多边形农场生活模拟（星露谷 like）。固定斜俯视相机，桌面平台。

> **当前状态：M0 已完成** —— 项目骨架 + 可跑通的核心农场闭环 + 单元测试全绿。
> 完整设计方案见 [`docs/DESIGN.md`](docs/DESIGN.md)（v3.0）。

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

```bash
# 1. 克隆（含 LFS 资源）
git clone git@github.com:zzp-x/star-game.git
cd star-game
git lfs install --local

# 2. 用 Godot 打开项目目录（会自动导入资源、生成 .godot/）
godot --path . --editor

# 3. 直接跑游戏
godot --path .
```

首次打开需要在编辑器里安装测试框架（见下）。

---

## 操作

| 操作 | 键 |
| --- | --- |
| 移动 | `W A S D`（**相对相机方向**） |
| 跑步 | `Shift` |
| 使用工具 / 交互 | `鼠标左键`（作用于鼠标指向的格子） |
| 旋转相机 | `Q` / `E`（90° 分步） |
| 缩放 | `鼠标滚轮` |
| 边缘平移 | 鼠标移到屏幕边缘 |
| 切换种子 | `1` – `5` |
| 过夜 | `F10` |
| 存档 / 读档 | `F5` / `F9` |

**M0 的核心闭环**（一个键跑通）：

```
左键点草地 → 翻地
再左键     → 播种
再左键     → 浇水（土壤变深色）
F10        → 过夜（下雨天会自动浇水）
重复 4 次  → 芜菁成熟（变成金色发光）
左键       → 收获，金币增加
```

---

## 单元测试（GUT）

测试框架：[GUT](https://github.com/bitwes/Gut) **9.7.1**（对应 Godot 4.7）。

**已经随仓库提供**（`addons/gut/`，259 个文件已入库），克隆后**无需安装**，
只需在编辑器里 **Project → Project Settings → Plugins** 勾选启用 **Gut** 即可。

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

**当前状态：4 个测试脚本 · 56 个测试 · 171 条断言 · 全部通过。**

> **这些测试不启动场景树、不渲染任何东西、不需要任何素材。**
> 因为游戏规则全部写在 `scripts/core/` 的纯逻辑类里。这是架构最重要的一条回报。
>
> `test/unit/` 验证「规则对不对」，`test/integration/` 验证「接线通不通」——
> 后者抓到过一个单元测试永远发现不了的 bug：作物生长用了错一天的天气
> （详见 `docs/DESIGN.md` §3.4 的 `day_ended` 说明）。

---

## 目录结构

```
star-game/
├─ project.godot          # ★ 渲染器 / 物理 / 输入映射 / 警告等级都在这里
├─ .gitattributes         # Git LFS 规则（*.glb / *.wav / *.hdr …）
├─ .gutconfig.json        # GUT 测试配置
├─ docs/
│  ├─ DESIGN.md           # ★ 完整设计方案 v3.0（1844 行）
│  └─ ROADMAP.md          # 里程碑进度 + v2 待办
├─ assets/                # 所有素材（3D 模型统一用 GLB/glTF）
│  └─ CREDITS.md          # ★ 素材授权与来源
├─ data/                  # 数据驱动：Resource 实例（.tres）
├─ scenes/                # Godot 场景（.tscn）
├─ scripts/
│  ├─ autoload/           # L3 单例：EventBus / GameManager / TimeManager / SaveManager
│  ├─ core/               # ★ L2 纯逻辑：规则都在这里，可 GUT 直接测
│  ├─ data/               # L1 数据：CropData / CropDatabase
│  ├─ actors/  world/  ui/
└─ test/unit/             # GUT 单元测试
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

## 3D 项目的三个「别信默认」

1. **渲染配置和 2D 是反的** —— 2D 用 `Stretch Mode = viewport` + 关抗锯齿；
   **3D 必须 `disabled`**（渲染到低分辨率再放大只会糊）**且必须开 MSAA**
   （低模硬边极多，关掉就是满屏爬行的锯齿）。
2. **`GridMap.cell_size` 一旦铺了格子就绝不能改** —— 它不会更新已有格子。
3. **鼠标拾取格子用 `Plane.intersects_ray()`**，不要射线查询物理世界 ——
   农田是水平面，数学求交更快更稳，还省掉每格的碰撞体。

---

## 已知限制

- **本项目锁定 Forward+ 渲染器，因此无法导出 Web 版**。
  Godot 的 Web 导出只支持 Compatibility 渲染器（因为 Godot 尚不支持 WebGPU）。
  这是 M0 就定死的决策，见 DESIGN.md §2.4 —— 若将来需要 Web 版，需要专门做一次材质适配分支。
- M0 的土地与作物用**代码生成的简易网格**渲染（纯色方块 + 圆锥），
  不依赖任何素材。M1 会替换为 GridMap + MeshBuilder + 真实 CC0 模型。
