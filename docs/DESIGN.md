# 《Star Game》设计方案

> 一款**固定斜俯视 3D**、低多边形画风的农场生活模拟游戏（星露谷物语 like）
> 版本：**v3.0（由 2D 像素改为 3D 低多边形）** ｜ 日期：2026-10-07 ｜ 状态：**待评审**
> 仓库：`git@github.com:zzp-x/star-game.git`

---

## 0. TL;DR（30 秒版）

| 维度 | 结论 |
| --- | --- |
| 引擎 | **Godot 4.7.2 标准版 + GDScript** |
| 画面 | **固定斜俯视 3D**（可 90° 分步旋转）· 低多边形风格 |
| 渲染器 | **Forward+**（仅桌面，换取全局光照/SSR 等全特性） |
| 物理 | **Jolt Physics**（Godot 4.6 起已是 3D 默认） |
| 首版范围 | **核心农场闭环**：种植 + 时间/季节 + 工具 + 体力 + 背包 + 经济 + 存档。**NPC / 钓鱼 / 矿洞移到 v2** |
| 导出目标 | Windows / macOS / Linux（**不做 Web**，理由见 §2.4） |
| 美术 | **低多边形 CC0 素材包**：Kenney + Quaternius 为主，全部可商用、免署名 |
| 预计工期 | 单人业余 ≈ **11–13 周**，拆成 6 个里程碑，每个里程碑都"可玩" |
| 最大风险 | ① 3D 手感与相机调校 ② 范围蔓延（3D 下加系统成本翻倍） |
| 环境待办 | **只需装 Godot 标准版（~70MB）+ GUT**，无需 .NET SDK |

> **v2 → v3 变更摘要**：整体由 2D 像素转为 **3D 低多边形 + 固定斜俯视**。
> 架构分层（L1–L4）**原样保留**，其中 L2 领域逻辑层**一行代码都不用改**（它用 `Vector2i` 表示格位，与维度无关）。
> 重写的是：美术与素材（§6）、渲染与相机（§5.1）、地形与土地（§5.2）、玩家控制（§5.3）、光照与季节（§5.5）、性能预算（§5.6）、里程碑（§7）。
> 附带收益：**素材授权红线消失**——3D 顶级素材源几乎全是 CC0，可商用免署名。

---

## 1. 项目定位与设计目标

### 1.1 一句话定位

> 一个「慢节奏、有温度、可自洽循环」的**立体小农场** —— 比起"打赢"，玩家更想"再种一天"。

### 1.2 三条体验支柱（Pillars）

所有设计取舍都回到这三条上，凡是不服务于它们的系统一律砍掉：

1. **节奏感（Rhythm）** —— 一天的边界清晰：早起 → 干活 → 体力见底 → 睡觉 → 新的一天。这是整个游戏的心跳。
2. **积累感（Accumulation）** —— 每一个动作都在变强：土地从荒芜到整齐、金币从零到够买新种子。
3. **惊喜感（Discovery）** —— 作物冒出新芽、季节把整片山谷染成另一种颜色，是短周期的多巴胺。

> **3D 化对体验的加分点**：2D 里做不到的"季节换装"在 3D 里非常直观——光照角度、天空颜色、植被色调会整体变化，**"时间流逝"这件事从数字变成可见的画面**。这是选 3D 最值得换来的东西，所以排进 M5 打磨重点。

### 1.3 Demo 边界（做什么 / 不做什么）

**首版做（3D 核心农场闭环）：**

- 一个农场区域（含可耕田地 + 一小片可探索环境）
- **5 种可种作物**，覆盖 3 个季节
- 完整日循环：翻地 → 播种 → 浇水 → 睡觉 → 收获
- 4 种工具（锄头 / 水壶 / 斧 / 镐）+ 快捷栏
- 体力、背包、金币、种子店（买卖）
- 完整存档（3 个档位）
- 会随时间移动的太阳 + 季节视觉变化 + 一套低多边形美术
- **Windows / macOS / Linux 可执行包**

**首版不做（移到 v2 规划，防止范围蔓延）：**

- ⏭ NPC / 对话 / 好感度 → **v2**
- ⏭ 钓鱼小游戏 → **v2**
- ⏭ 矿洞 / 战斗 → **v2**
- ❌ 畜牧（鸡舍 / 牛棚）→ v2
- ❌ 节日、任务板、社区中心
- ❌ 多人联机
- ❌ 手柄支持（只做键鼠，但 Input Map 留好抽象）
- ❌ **自定义建模 / 绑骨**（一律用 CC0 素材包，这条是 3D 版的工期生命线）

> **为什么收窄？** 3D 化之后，每个系统的成本都会上升：2D 里"加一张立绘"的事，3D 里可能意味着建模 + 绑骨 + 动画 + 光照适配。**先把 3D 的手感与工程链路彻底跑通，比堆玩法重要得多**——因为手感不对，后面所有内容都要返工。

---

## 2. 技术选型

### 2.1 结论

```
引擎      ：Godot Engine 4.7.2-stable（标准版，无需 .NET）
语言      ：GDScript（静态类型标注 + @export 注解）
渲染器    ：Forward+（桌面全特性）
3D 物理   ：Jolt Physics（4.6 起为默认，无需插件）
编辑器   ：Godot 内置脚本编辑器（首选）或 VS Code + godot-tools
测试      ：GUT 9.7.1（Godot Unit Test）
版本控制  ：Git + GitHub，3D 模型文件建议启用 Git LFS（见 §8.2）
```

**版本选择说明（截至 2026-10-07 核实）：**

| 版本 | 状态 | 说明 |
| --- | --- | --- |
| **4.7.2** | ✅ **当前最新稳定版** | 2026-08-18 发布。**本项目采用这个** |
| 4.7 / 4.7.1 | 已被 4.7.2 取代 | 官方在一个系列里只支持最新的补丁版 |
| 4.6.3 | 仍在维护 | 老项目可留，新项目没必要 |
| 4.5.x | 仅安全补丁 | — |
| 4.8-dev | 🚫 **开发中，禁止用于本项目** | 预计 2026 Q4 发布。dev 快照会改 API、随时可能崩 |

**三条版本纪律：**

1. **认准 4.7.x 系列，不要碰 4.8-dev。** 官方对预发布版的定位是"仅供测试，不建议用于生产"。
2. **补丁版（4.7.3、4.7.4…）出来可以放心升。** 官方政策明确它们"向后兼容、只修 bug 和安全问题"，不破坏 API。
3. **小版本（升到 4.8）要谨慎。** 官方承认小版本"在个别领域可能有兼容性破坏"，**3D 项目尤其敏感**（渲染管线改动会直接影响画面观感），升级前必须逐场景回归。

> 把引擎版本写进 `README.md`，并在 `.gitignore` 里忽略 `.godot/`（缓存目录，但 `*.import` 文件要提交）。

### 2.2 为什么这次 3D 反而"更划算"

换 3D 通常意味着成本暴涨，但对我们**这个具体的项目**，有几条反向的收益：

| 维度 | 2D 像素（v2） | **3D 低多边形（v3 采用）** |
| --- | --- | --- |
| **素材授权** | ⚠️ Sprout Lands 免费版**仅限非商用**，商用要买 | ✅ **Kenney / Quaternius / KayKit 全部 CC0**，可商用免署名 |
| **素材内容量** | 每种作物每个生长阶段都要一张图 | ✅ **一次建模，任意角度**；且角色自带骨骼与动画 |
| **资源制作** | 逐帧像素动画，画一张用一张 | ✅ 素材包**自带动画库**（Quaternius 有通用动画库，Mixamo 可补齐） |
| **季节表现** | 需要重画整套 tile 的换色版 | ✅ **换光照 + 换材质色调**即可，可程序化驱动 |
| **深度排序** | 要靠 `y_sort` 手工排序，容易出错 | ✅ **深度缓冲自动处理**（代价见 §5.7 的透明材质坑） |
| **引擎吃力度** | 极低 | ⚠️ 中，需要做性能预算（§5.6） |
| **相机穿模** | 无此问题 | ✅ **固定斜俯视天然规避**（第三人称才需要做防穿模） |
| **工期** | 基准 | ⚠️ **约 1.3–1.5 倍**（但有素材包兜底，不是 2 倍） |

**关键判断：3D 的成本上涨，主要来自"自己造模型"。而我们把这条彻底排除了**——§1.3 明确写了"不做自定义建模/绑骨"。有 CC0 素材包兜底，3D 的增量成本从"翻倍"压到"多三成"。

而换来的是**一个 2D 永远做不到的东西**：把"一天在流逝"和"季节在更替"变成玩家一眼能看到的画面。对一个以"节奏感"为第一支柱的游戏，这个收益值得。

### 2.3 为什么 GDScript（沿用 v2 结论）

星露谷确实用 **C# + XNA** 开发（Eric Barone 单人作品），后期迁到 **MonoGame**。但那是 2012 年的技术选择，XNA 早已停维护；而且**语言的选择和游戏类型、维度都无关，和团队规模、发布目标有关**。

| 维度 | C# | **GDScript（采用）** |
| --- | --- | --- |
| Web 导出 | ❌ 完全不支持 | ✅ 支持（**本项目暂不需要**，见 §2.4） |
| 环境安装 | Godot .NET 版 + .NET SDK 8 | **Godot 标准版，一步到位** |
| 迭代速度 | 改代码要编译 | **保存即生效，零编译等待** |
| IDE 体验 | 内置编辑器很弱，必须外挂 Rider | **内置编辑器就够用** |
| 引擎 API 贴合度 | 有语义差异要绕 | **一等公民**，文档示例可直接抄 |
| 类型安全 | ✅ 编译期检查 | ⚠️ 需靠**全量类型标注**自建纪律（§4.7） |
| 性能 | 较快 | 够用 —— **3D 的瓶颈在 GPU 和渲染管线，不在脚本语言** |

官方文档原话：

> *"GDScript 代码本身执行起来并没有 C# 或 C++ 等编译型语言快，而大多数脚本代码又都是在调用 Godot 引擎的 C++ 代码中的快速算法。**在大多数情况下，使用 GDScript、C#、C++ 编写游戏逻辑并不会呈现出明显的性能差异。**"*

> **3D 场景下这条尤其成立**：3D 的性能开销集中在渲染（draw call、阴影、三角面）和物理（Jolt，C++ 实现），脚本每帧跑的只是"读输入 → 设速度 → 调 `move_and_slide()`"这几行。**语言不会是瓶颈。**

### 2.4 ⚠️ 渲染器与导出目标的绑定关系（**必须在 M0 就定死**）

这是 3D 版里**唯一一个选错就要大面积返工**的决策，所以放在最显眼的位置。

Godot 的三个渲染器**不是"画质档位"，而是特性集完全不同的三条管线**：

| 渲染器 | 后端 | 特性 | 适用 |
| --- | --- | --- | --- |
| **Forward+** | Vulkan / D3D12 / Metal | 最全：SDFGI、VoxelGI、SSR、体积雾、集群光照 | **桌面平台默认 → 本项目采用** |
| Mobile | Vulkan / D3D12 / Metal | 砍掉重型 GI，保温度与续航 | 移动端 / XR |
| Compatibility | OpenGL 3.3 / WebGL2 | 特性最少，兼容性最广 | 老设备 / **Web（唯一可选项）** |

**我们选了"只做桌面"，因此锁定 Forward+。** 但有两个连带事实必须知道：

**① 不做 Web 版的真正原因。** Godot 的 Web 导出**只支持 Compatibility 渲染器**——因为 Godot 目前**不支持 WebGPU**，而 WebGPU 是 Forward+/Mobile 在浏览器里运行的前提（这是官方文档的原话，4.7 也没有改变）。

如果硬要 3D 上 Web，代价是：
- 渲染器必须降级到 Compatibility ⇒ 没有 SDFGI / VoxelGI / SSR / 体积雾
- 低多边形场景能跑，但光照要重做一遍（Compatibility 的光照模型不同）
- 浏览器端性能受限，手机浏览器基本别想

**结论：本项目只做桌面。** 如果将来真的需要 Web 版，参见 §9 风险 10 的降级预案（需要专门做一次"Compatibility 材质适配"的分支）。

**② 切换渲染器的代价。** 后期从 Forward+ 切到 Compatibility，**不是改个下拉框就完事**——材质、光照强度、色调映射、反射的表现全都会变，需要逐场景重调。**这就是为什么它必须在 M0 定死。**

> 顺带两条 4.7 时代的默认值变化，别信默认：
> - **Godot 4.6 起，Windows 上新项目默认后端变为 D3D12**（Vulkan 仍在菜单里）。跨平台驱动一致性更好。
> - **Godot 4.6 起，Jolt 成为 3D 物理默认引擎**，无需再手动切换或装插件。

### 2.5 环境准备（本机现状 + 待办）

已检测到的本机情况：

| 项目 | 状态 |
| --- | --- |
| Git | ✅ 已装（PortableGit） |
| Git 身份 | ✅ `李白 <1833801754@qq.com>` |
| Git LFS | ✅ 3.5.1 已装（**3D 项目建议尽早启用**，见 §8.2） |
| Godot | ❌ **未安装** |
| .NET SDK | ✅ 不需要（GDScript 方案已省去） |

**待办清单：**

- [ ] **1. 装 Godot 4.7.2 标准版**
      下载 <https://godotengine.org/download/windows/> → 选 **Godot Engine**（**不是** `.NET` 那个，x86_64，zip 约 70MB）
      绿色免安装，解压即用。建议解压到 `D:\Godot\`，并把该目录加进 PATH：
      ```bash
      godot --path "D:/WorkBuddy-work-space/star-game" --editor   # 开编辑器
      godot --path "D:/WorkBuddy-work-space/star-game"            # 直接跑游戏
      ```

- [ ] **2. 装测试框架 GUT 9.7.1**
      编辑器内 → **Asset Store** 标签页 → 搜 "GUT" → 安装
      或从 GitHub 下载：<https://github.com/bitwes/Gut>（选对应 Godot 4.7 的 `9.7.1`）
      然后 Project → Project Settings → Plugins → 启用 **GUT**

- [ ] **3. 编辑器选择**
      - **Godot 内置脚本编辑器**（首选）：补全、断点、单步调试齐全
      - **VS Code**：装 `godot-tools` 扩展，再加 `gut-extension` 可在 VS Code 里直接跑测试

- [ ] **4. 验证**
      ```bash
      godot --version        # 应输出 4.7.2.stable.official
      ```

**可选工具（3D 特有，用到再装）：**

| 工具 | 用途 | 是否必需 |
| --- | --- | --- |
| **Blender** | 微调 CC0 模型、烘焙、改材质、导出 GLB | 推荐装，但**不是必需**——素材包直接能用 |
| **Mixamo** | 免费自动绑骨 + 动捕动画库（网页版） | NPC/角色动画不足时的补充 |
| glTF 查看器 | 预览 `.glb` 内容、确认动画名 | 可选 |

### 2.6 Godot 3D 适配度自评（诚实版）

> 结论：**Godot 4.7 对本项目不是"勉强够用"，而是"正合适"。**
> 但这不是因为 Godot 的 3D 强，而是因为**我们的需求正好避开了它所有的弱项**。

选引擎不是选"哪个好"，而是选"哪个的短板不在我的必经之路上"。Godot 4 的 3D 短板是**公开且明确**的，逐条对照本项目：

| Godot 3D 的公认弱项 | 对本项目的影响 |
| --- | --- |
| **无内置地形系统**（需 Terrain3D 社区插件） | ❌ 无关：农场是平坦网格，`GridMap` 足够 |
| **无 Nanite / Lumen 级几何与实时光追** | ❌ 无关：低多边形，全场三角形以千计 |
| **SDFGI 弱于 Lumen**（室内、密集小物件时） | ❌ 无关：开阔室外场景，且以白天为主 |
| **大世界流式加载无内建方案** | ❌ 无关：地图就是一个农场 |
| **无主机原生导出**（需第三方移植商） | ❌ 无关：本期只做桌面 |
| **资产库体量小于 Unity Asset Store** | ❌ 已规避：走 CC0 素材包，无需购买资产 |
| **粒子系统弱于 VFX Graph / Niagara** | ⚠️ 轻微：雨雪、水花需手写 `GPUParticles3D` + 着色器 |
| **后处理不够精细**（运动模糊 / SSR / 体积雾） | ⚠️ 轻微：低多边形风格本就不依赖这些 |
| **AnimationTree 在复杂动画图上不如 Control Rig** | ⚠️ 轻微：本作角色动画需求简单（走 / 用工具 / 挥手） |
| **3D 相关中文教程偏少** | ⚠️ 真实存在：靠官方文档 + 纯逻辑层单测兜底（见 §4） |

**6 项"完全不相关"，4 项"轻微"，0 项"致命"。** 这就是它适合的原因。

#### 真正会踩到的三个坑（务必提前防范）

**坑 1：骨骼动画重定向。**
免费 CC0 素材包里，**不同作者的骨架不通用**——Quaternius 的走跑动画套不到 KayKit 的角色上。Godot 4 有动画重定向，但比 Unity 的 Humanoid 要手动配映射。

- **对策**：**首版角色统一用 Quaternius 一家**，需要额外动作时经 Mixamo 重定向，不要混用多来源骨架。

**坑 2：天气与粒子 VFX。**
Godot 没有 Niagara 那种可视化粒子图，雨、雪、水花都要自己搭 `GPUParticles3D` + 着色器。

- **对策**：首版天气只做"**光照 + 色调 + 简单粒子**"三件套（雨天变暗变灰、地面反光、下落粒子），把炫技留到 v2。

**坑 3：生态里没有现成的"农场系统"插件。**
Unity Asset Store 里能买到 farming sim 模板，Godot 没有，得自己写。

- **对策**：这正是 §4 那套"**L2 纯逻辑层 + GUT 测试**"要解决的问题——自己写的农场规则反而完全可控、可测、可改。**我们不是被迫自己写，而是本来就应该自己写。**

#### 唯一一个"该考虑换 Unity"的条件 ⚠️

如果出现以下任一条，方案就该重估：

1. **"必须把游戏搬到主机（Switch / PS / Xbox）"** —— Godot 需走第三方移植商，Unity 是原生支持
2. **"必须在 3 个月内出货，且要靠买现成资产堆出来"** —— Unity 的农场类模板与美术资产能直接压缩工期
3. **"要招人 / 组 3 人以上团队"** —— Unity 的 C# 人才池大一个量级

以上都不成立的话，**Godot 是更优解**：MIT 协议零抽成、编辑器 70MB 秒开、纯逻辑层可单测、GDScript 迭代零编译等待。

#### Godot 4.7 里对我们有直接好处的三个新特性

| 特性 | 为什么要谢它 |
| --- | --- |
| **MeshLibrary 编辑器**（4.7 新增） | 本作 M1 的核心工序就是做 `GridMap` 的瓦片库，终于有专用界面，不用逐个翻 Inspector |
| **AreaLight3D**（4.7 新增） | 谷仓窗口的暖光、门口挂灯、招牌光——不用再拿"自发光材质 + GI"硬凑 |
| **HDR 输出**（4.7 新增，支持 Forward+） | 黄昏暖橙、清晨冷蓝能真正投到屏幕上。注意 Compatibility / Web / Android **不支持**（本项目不涉及） |

另外 **3D 视口 nearest-neighbor 缩放**、**顶点吸附**、**3D 标尺向量**三条编辑便利，在手工摆场景时会实实在在省时间。

---

## 3. 核心玩法设计

### 3.1 核心循环

游戏的"心跳"是一条日循环，所有系统都挂在它上面：

```
        ┌─────────────────────────────────────────────┐
        │                                             │
        ▼                                             │
   ┌─────────┐    ┌──────────┐    ┌──────────┐   ┌──────────┐
   │ 06:00   │───▶│  农场劳作 │───▶│ 体力消耗 │──▶│ 外出探索 │
   │  起床   │    │ 翻地/播种 │    │ 逐渐见底 │   │ 逛店/采买 │
   │ 体力回满 │    │ 浇水/收获 │    │          │   │          │
   └─────────┘    └──────────┘    └──────────┘   └──────────┘
        ▲                                             │
        │                                             ▼
        │          ┌──────────┐    ┌──────────┐  ┌──────────┐
        └──────────│  存档    │◀───│  结算    │◀─│ 02:00    │
                   │ 自动保存 │    │ 作物+1天 │  │ 强制昏睡 │
                   │ 进入次日 │    │ 金币入账 │  │ 或主动睡 │
                   └──────────┘    └──────────┘  └──────────┘
```

**关键设计点：**

- **体力是唯一的软约束**：它逼玩家做取舍（今天种地还是去采买？），这是"节奏感"的来源。没有体力，游戏就会退化成无脑刷。
- **睡眠是唯一的存档点**：让"结束一天"这个动作变得有仪式感，也天然地给存档一个合理的时机。
- **睡觉 → 次日结算** 是全局状态推进的唯一入口：作物生长、季节推进、天气重掷，全部发生在这里。这让状态变更可预测、可复现、好调试。

> **3D 化的强化**：日循环在 3D 里有了视觉锚点——**太阳在天空划过的弧线就是时钟**。玩家不需要看 HUD 也能感觉到"天要黑了"。所以"太阳随时间移动"被提到 M1 就做，而不是拖到打磨期。

### 3.2 系统清单与优先级

| # | 系统 | 优先级 | 里程碑 | 说明 |
| --- | --- | --- | --- | --- |
| 1 | 时间 / 日历 / 季节 / 天气 | P0 | M1 | 全局心跳，最先做 |
| 2 | 玩家控制 + 相机 | P0 | M1 | 3D 手感的地基 |
| 3 | 3D 地形 + 碰撞 | P0 | M0 | 世界基础 |
| 4 | 农场与种植 | P0 | M2 | **核心闭环** |
| 5 | 工具系统 | P0 | M2 | 承载一切农场操作 |
| 6 | 体力 | P0 | M3 | 节奏控制 |
| 7 | 物品 / 背包 | P0 | M3 | 承载一切产出 |
| 8 | 经济 / 商店 | P1 | M3 | 让金币有意义 |
| 9 | 存档 | P0 | M4 | 从第一天就要有 |
| 10 | 光照 / 季节表现 | P1 | M5 | **3D 的加分项** |
| 11 | UI / HUD / 菜单 | P0 | M1 起 | 贯穿全程 |
| 12 | 音频 | P2 | M5 | 打磨期补 |
| 13 | 打包导出 | P1 | M5 | 交付物 |
| — | NPC / 对话 / 好感度 | — | **v2** | 首版不做 |
| — | 钓鱼 | — | **v2** | 首版不做 |
| — | 矿洞 / 战斗 | — | **v2** | 首版不做 |

### 3.3 相机与操作（★ 3D 新增，决定手感）

**相机形态：固定斜俯视（Fixed Oblique Top-Down）**

```
                 ☀️ 太阳
                  ╲
                   ╲          Camera3D
                    ╲          ○
                     ╲        ╱│ 俯角 52°
                      ╲      ╱ │
                       ╲    ╱  │
    ┌───────────────────╲──╱───┼───────────────┐
    │  固定斜俯视：相机悬在玩家后上方固定角度    │
    │  可 90° 分步旋转（Q / E），俯角锁定       │
    │                                          │
    │      🌱  🌱        🏠         🌳         │
    │                                          │
    └──────────────────────────────────────────┘
```

| 参数 | 值 | 理由 |
| --- | --- | --- |
| 投影 | **透视（Perspective）**，FOV **40°** | 低 FOV 削弱边缘透视变形（接近正交的整洁感），又保留"近大远小"的纵深。**纯正交会让低模场景显得很扁** |
| 俯角（Pitch） | **-52°** | 能看清格子与作物的立体形态，又不会像第一人称那样看不到前方 |
| 偏航（Yaw） | 初始 **0°**，按 **90° 分步旋转** | 轴对齐 ⇒ **格子与屏幕对齐**，鼠标点选、建造对齐都直观。45° 斜角虽有等距视角的味道，但格子会变菱形，交互复杂度明显上升 |
| 距离 | 固定 **18m**（透视下"缩放"= 改距离） | 保持透视透视关系一致，避免改 FOV 带来的鱼眼/压缩 |
| 跟随 | 平滑跟随玩家 + **边缘平移（看远处）** + **限制最大偏移** | 避免相机被玩家"甩来甩去"，也避免玩家看不见自己在哪 |

**为什么固定斜俯视是"最省力"的选择：**

1. **相机穿模问题消失** —— 第三人称要写防穿模（墙体推挤、拉近、透明化处理），固定角度几乎不需要。
2. **角色动画要求大幅降低** —— 不需要转身平滑、不需要镜头跟随骨骼，8 方向移动动画足够。
3. **关卡设计可复用 2D 思路** —— 田地格子、NPC 站位、建造对齐，本质还是"平面上的格子"。
4. **性能友好** —— 固定角度可以精确做**视锥剔除**与**预烘焙阴影**。

**操作映射：**

| 操作 | 键 | 说明 |
| --- | --- | --- |
| 移动 | `W A S D` | **相对相机方向**（按 A 永远是"屏幕左"，见 §5.3） |
| 跑步 | `Shift` | 消耗体力 |
| 使用工具 / 交互 | `鼠标左键` | 对**鼠标指向的格子**生效（射线拾取，见 §5.4） |
| 切换工具 | `1–5` / `滚轮` | 快捷栏 |
| 旋转相机 | `Q` / `E` | 90° 分步 |
| 边缘平移 | `鼠标移到屏幕边缘` | 临时看向远处，松手回到玩家 |
| 背包 | `Tab` | |
| 暂停 | `Esc` | |

### 3.4 时间 / 日历 / 季节 / 天气

**时间模型**（采用星露谷式的"非线性时钟"，手感比真实比例好）：

```
1 游戏分钟 = 0.7 真实秒（可配）
一天：06:00 ──────────────────────────▶ 02:00（次日，强制昏睡）
      起床                              极限
      06:00–12:00 上午（正常）
      12:00–18:00 下午（正常）
      18:00–02:00 夜晚（光照转冷、变暗）
```

**日历：**

| 单位 | 数值 | 说明 |
| --- | --- | --- |
| 一天 | 28 小时游戏时间 | 06:00–02:00 |
| 一季 | **28 天** | 春 / 夏 / 秋 / 冬 |
| 一年 | 4 季 = 112 天 | |

**季节影响：**

- 可种作物（`CropData.seasons` 白名单）
- 天气权重表（冬天不下雨只下雪；春天雨天多）
- 商店库存（季节限定种子）
- **视觉（3D 特有，见 §5.5）**：太阳高度角范围、天空色调、环境光颜色、植被色调

**天气系统：**

| 天气 | 效果 |
| --- | --- |
| ☀️ 晴 | 无 |
| 🌧️ 雨 | **自动浇水**（省一次体力）、NPC 对话变化（v2） |
| ⛈️ 暴风 | 雨 + 雷电（随机劈倒树/作物） |
| ❄️ 雪 | 冬季专属，自动浇水 |
| 🌫️ 雾 | 能见度下降（3D 用 `Environment` 的深度雾，效果比 2D 更好） |

天气在**每天清晨随机重掷**，季节权重表决定概率。

**信号（通过 `EventBus` 广播，不直接调用）：**

```gdscript
EventBus.minute_tick       # (total_minutes: int)  每游戏分钟
EventBus.hour_changed      # (hour: int)           整点
EventBus.day_ended         # (day, season, weather) ★ 一天结束，日历推进之前发射
EventBus.day_changed       # (day: int, season: int)  跨天（日历已推进）
EventBus.season_changed    # (season: int)         跨季
EventBus.year_changed      # (year: int)           跨年
EventBus.weather_rolled    # (weather: int)        天气重掷
```

> ⚠️ **为什么必须有 `day_ended`（M0 实战教训）**
> 最初的 `sleep()` 顺序是「推进日历 → 掷新天气 → 发 `day_changed`」，
> 而作物生长挂在 `day_changed` 上读 `TimeManager.weather` —— 于是拿到的是
> **新一天**的天气。结果：**"明天要下雨" 变成了 "今晚不浇水也长"**。
>
> 这个 bug 单元测试抓不到（`FarmGrid` 的逻辑完全正确），手动玩也很难碰上
> （要恰好"明天雨 + 今天没浇水"）。是**集成测试**抓出来的。
>
> 正确顺序：`day_ended(旧日期, 旧天气)` → 推进日历 → 掷新天气 → `weather_rolled` → `day_changed`。
> **作物生长挂 `day_ended`，UI/资源刷新挂 `day_changed`，两者职责不同，不要合并。**

> **设计原则**：`TimeManager` 只负责"推进 + 广播"，绝不直接去改作物、商店、光照。
> 光照、UI、作物各自订阅信号自己响应。这样时间系统永远不需要知道游戏里有多少系统。

### 3.5 农场与种植 ★核心

**土地格子状态机：**

```
   ┌──────────┐  锄头   ┌──────────┐  水壶   ┌──────────┐
   │ Untilled │───────▶│  Tilled  │───────▶│ Watered  │
   │  荒草/泥  │        │  已翻土   │        │  已浇水   │
   └──────────┘        └──────────┘        └──────────┘
        ▲                    │                    │
        │                  播种                   │ 播种
        │                    ▼                    ▼
        │              ┌──────────────────────────────┐
        │              │      Growing（按阶段生长）    │
        │              └──────────────────────────────┘
        │                            │ 生长完成
        │                            ▼
        │              ┌──────────────────────────────┐
        │  镰刀/时间流逝 │     Harvestable（可收获）      │
        └──────────────└──────────────────────────────┘
                                     │ 收获
                                     ▼
                            ┌──────────────┐
                            │  Tilled（回归）│  ← 或枯萎变回 Untilled
                            └──────────────┘
```

**生长规则：**

- 每天 `day_changed` 信号触发一次生长判定
- **只有 `WATERED` 状态才 +1 生长进度**（这是"浇水"的意义所在）
- 下雨/下雪天自动视为已浇水
- 跨季时，不在新季节白名单里的作物 → **枯萎**（回到 `UNTILLED` + 枯苗外观）
- 可循环作物（如蓝莓）：收获后不退到 `TILLED`，而是退一个阶段重新长，`regrow_days` 天后再次可收

> **3D 落地要点**：这套规则**全部写在 L2 的 `FarmGrid` 里，用 `Vector2i` 表示格位**（x = 东西，y = 南北）。它不知道自己是 2D 还是 3D。**从 2D 换到 3D，这个文件一行都不用改**——这正是 §4.1 分层设计的直接回报。

**工具：**

| 工具 | 作用 | 作用范围 | 体力 |
| --- | --- | --- | --- |
| 锄头 Hoe | 翻土 / 破坏作物 | 1 格 | -2 |
| 水壶 WateringCan | 浇水（有容量，需在水边补水） | 1 格 | -2 |
| 镐 Pickaxe | 挖石 / 破坏已翻土 | 1 格 | -2 |
| 斧 Axe | 砍树 / 劈木 | 1 格 | -2 |
| 镰刀 Scythe | 割草 / 除草（**不耗体力**） | 1 格 | 0 |

**工具升级**（种子店购买，用金币 + 等待天数）：基础 1 格 → 铜 1×3 → 铁 3×3 → 金 3×5 → 铱 5×5。
> 首版 Demo 只做到**基础级**，升级系统留接口。

**可种作物（5 种，覆盖 3 季）：**

| 作物 | 季节 | 生长天数 | 循环 | 种子价 | 售价 | 收益/天 |
| --- | --- | --- | --- | --- | --- | --- |
| 防风草 Parsnip | 春 | 4 | — | 20 | 35 | 3.75 |
| 土豆 Potato | 春 | 6 | — | 50 | 80 | 5.0 |
| 蓝莓 Blueberry | 夏 | 13 | 每 4 天 | 80 | 50×3 | 高 |
| 玉米 Corn | 夏/秋 | 14 | 每 4 天 | 150 | 50 | 中 |
| 南瓜 Pumpkin | 秋 | 13 | — | 100 | 320 | 16.9 |

*（数值为草案，M2 阶段用实际手感调整）*

> ⚠️ **3D 特有的坑：作物生长阶段模型很难找。** 2D 素材包习惯提供"5 个生长阶段各一张图"，**3D 素材包几乎不提供"同一株作物的多个生长阶段模型"**。方案里的对策见 §6.4。

### 3.6 体力系统

| 项目 | 数值 |
| --- | --- |
| 体力上限 | 270（星露谷同值，手感经过验证） |
| 工具使用 | -2 |
| 挥空工具 | -0（避免误操作惩罚过重） |
| 跑步 | 0.5/秒（持续缓慢消耗） |
| 吃食物 | 即时恢复（20–80，见 `ItemData.energy_restore`） |

**状态机：**

```
Normal (体力 > 0)
   │ 体力归零
   ▼
Exhausted 疲惫 ── 移速 ×0.5，无法跑步，动作耗体力翻倍
   │ 继续做耗体力动作
   ▼
Collapse 昏倒 ── 黑屏 → 强制次日 06:00 起床，体力只恢复到 50%
```

### 3.7 物品与背包

**物品数据模型（`ItemData`，Resource + `@export`）：**

```
item_id         String      唯一 ID，如 "seed_parsnip"
display_name    String      显示名
description     String      描述
icon            Texture2D   UI 图标（3D 项目里仍需 2D 图标）
world_mesh      PackedScene 掉落物/手持物的 3D 模型（可选）
category        int         种子/作物/矿物/工具/食物/其它（enum）
stack_size      int         最大堆叠（99 或不可堆叠）
sell_price      int         售价
energy_restore  int         食用回复体力（0 = 不可食）
edible          bool
```

> **3D 项目里 UI 图标仍是 2D 图片**。这是很多人第一次做 3D 会困惑的点：背包里的"土豆"是一个 `Texture2D` 图标，而不是 3D 模型。3D 模型只在世界里出现（掉在地上、拿在手上）。

**背包设计：**

- **主背包**：24 格（6×4），`Tab` 打开
- **快捷栏**：12 格（`1–9`、`0`、`-`、`=`），常驻 HUD 底部
- **工具槽**：专门放工具，不占背包格
- 拖拽：`Control` 节点 + `_get_drag_data` / `_can_drop_data` / `_drop_data`（Godot 原生 API）

### 3.8 经济与商店

- **货币**：金币（Gold），HUD 常驻显示
- **收入**：卖出作物（通过**出货箱 Shipping Bin**，或直接找商家卖）
- **支出**：买种子、买工具升级、买食物

**商店（`ShopData`，Resource + `@export`）：**

```
shop_id        String
display_name   String
open_hours     Vector2i     营业时间（起, 止）
items          Array[ShopEntry]   { item_id, price, stock_per_day, season_filter }
```

首版只有一家：**种子店**（09:00–17:00，周三休息）。

### 3.9 存档

**时机：**

- 睡觉时**自动保存**（唯一的自动保存点）
- 手动保存（暂停菜单）

**档位**：3 个（显示角色名 / 游戏内日期 / 总游戏时长 / 金币）

**存储位置**：Godot 的 `user://` 目录，Windows 上是
`%APPDATA%\Godot\app_userdata\Star Game\saves\slot_1.json`

**格式：JSON + 版本号**（不用 Godot 的 `.tres` 序列化，理由见 §4.5）

```jsonc
{
  "version": 4,
  "meta": { "player_name": "李白", "save_time": "2026-10-07T16:40:00", "play_seconds": 3600 },
  "time": { "year": 1, "season": "Spring", "day": 5, "minute": 480, "weather": "Sunny" },
  "player": {
    "gold": 500, "stamina": 270, "hp": 100,
    // ★ 3D：位置从 {x, y} 变为 {x, y, z}
    "position": { "map": "Farm", "x": 20.0, "y": 0.0, "z": 30.0 },
    "rotation_y": 1.57,
    "inventory": [ { "slot": 0, "item_id": "seed_parsnip", "count": 15 } ],
    "hotbar": ["hoe", "watering_can", "axe", "pickaxe", "scythe"],
    "flags": { "met_shopkeeper": true }
  },
  "world": {
    // ★ 格位仍用 "x,z" 二维键 —— 因为田地是平面，没有高度概念
    "farm": {
      "tiles": {
        "12,8":  { "state": "WATERED", "crop_id": "parsnip", "growth": 2, "day_planted": 3 }
      }
    }
  }
}
```

**版本迁移**：`SaveMigrator` 逐级升级（`v1 → v2 → v3 → v4`）。
**从第一天就带 `version` 字段** —— 这是补救成本最低、最容易被忽略的一条。

> **v3 存档变更**：玩家位置由 `Vector2` 变为 `Vector3`，并新增 `rotation_y`。因为本项目还没上线，**直接 bump 到 `version: 4`，不需要写迁移代码**——但 `SaveMigrator` 的骨架要留着。

### 3.10 数值草案速查

| 项 | 值 | 项 | 值 |
| --- | --- | --- | --- |
| 初始金币 | 500 | 体力上限 | 270 |
| 一天时长 | 06:00–02:00 | 一季天数 | 28 |
| 初始背包 | 24 格 | 一季作物数 | 5 |
| 走路速度 | 4.5 m/s | 跑步速度 | 7.0 m/s |
| 1 游戏分钟 | 0.7 真实秒 | 相机俯角 | -52° |
| 相机距离 | 18 m | 相机 FOV | 40° |

---

## 4. 架构设计

### 4.1 分层

> **好消息：这套分层从 2D 原样搬到 3D，一行都不用改。** 这正是它存在的意义。

```
┌──────────────────────────────────────────────────────────────┐
│  L4  表现层（Godot 3D 场景 + 节点脚本）                        │
│      player.gd / crop.gd / hud.gd / camera_rig.gd ...         │
│      只负责：显示、动画、输入采集。不含游戏规则。                │
└───────────────────────────┬──────────────────────────────────┘
                            │ 读状态 / 发信号
┌───────────────────────────▼──────────────────────────────────┐
│  L3  单例层（Autoload，全局唯一）                              │
│      EventBus · GameManager · TimeManager · SaveManager        │
│      SceneRouter · InventoryManager · AudioManager             │
│      职责：编排、广播、跨场景共享状态。                          │
└───────────────────────────┬──────────────────────────────────┘
                            │ 调用
┌───────────────────────────▼──────────────────────────────────┐
│  L2  领域逻辑层（纯 GDScript，extends RefCounted）★可 GUT 单测  │
│      clock.gd · farm_grid.gd · inventory.gd · save_model.gd    │
│      职责：全部游戏规则与状态计算。零节点依赖、零维度依赖。        │
└───────────────────────────┬──────────────────────────────────┘
                            │ 读取
┌───────────────────────────▼──────────────────────────────────┐
│  L1  数据层（Godot Resource，编辑器可视化配置）                  │
│      item_data.gd · crop_data.gd · shop_data.gd                │
│      职责：纯数据，无逻辑。可在 Inspector 里直接改。              │
└──────────────────────────────────────────────────────────────┘
```

**为什么要把 L2 和 L3 分开？（3D 时代这条更重要了）**

Godot 的节点和场景很难做单元测试（需要引擎上下文、要 `add_child` 到树上）。如果把"作物几天长成""浇水加多少生长"这类规则写在 3D 节点脚本里，你就只能靠手点着玩来验证——**而在 3D 里"手动验证一遍"的成本比 2D 高得多**（要走到田里、要等太阳升起、要看动画）。

把规则抽到 **继承 `RefCounted` 的纯逻辑类**（L2）之后：

- GUT 可以直接 `FarmGrid.new()` 然后断言，**不需要启动场景树、不需要渲染任何东西**
- 存档序列化天然只需要 `SaveModel`，不用遍历整个 3D 场景树
- 将来如果真要换引擎或换维度，L2 整层可以搬走

> **GDScript 特有优势**：因为不用编译，`RefCounted` 逻辑类的迭代是"改完存盘即可"，做 TDD 的体验很好。

### 4.2 目录结构

> **GDScript 命名规范**：文件/文件夹 `snake_case`，`class_name` 用 `PascalCase`，函数/变量/信号 `snake_case`，常量 `CONSTANT_CASE`，私有成员前缀 `_`。

```
star-game/
├─ .gitignore
├─ .gitattributes
├─ README.md                         # 记引擎版本 + 操作说明
├─ project.godot                     # Godot 项目配置（入版本库）
├─ export_presets.cfg                # 导出配置（见 §8.1）
├─ icon.svg
│
├─ docs/
│  ├─ DESIGN.md                      # 本文档
│  ├─ ROADMAP.md                     # 里程碑进度 + v2 待办清单
│  └─ BALANCE.md                     # 数值表（策划改动记录）
│
├─ addons/
│  └─ gut/                           # 单元测试框架（GUT 9.7.1）
│
├─ assets/                           # ★ 所有素材
│  ├─ models/                        # ★ 3D：统一用 GLB/glTF
│  │  ├─ nature/                     # 树/岩石/花草（Kenney Nature Kit）
│  │  ├─ farm/                       # 农具/栅栏/出货箱/木箱
│  │  ├─ crops/                      # 作物模型（含生长阶段或缩放基准）
│  │  ├─ buildings/                  # 房子/商店/场景建筑
│  │  ├─ characters/                 # 玩家 + NPC（含骨骼动画）
│  │  └─ props/                      # 杂项道具
│  ├─ materials/                     # PBR 材质 / 贴图（ambientCG 等）
│  ├─ sky/                           # HDRI 天空盒（Poly Haven）
│  ├─ art/                           # 2D 素材：UI 图标、立绘、字体图
│  │  └─ icons/                      # 物品图标（背包里显示的是 2D 图）
│  ├─ audio/
│  │  ├─ bgm/
│  │  └─ sfx/
│  ├─ fonts/
│  └─ CREDITS.md                     # ★ 素材授权与来源（见 §6.5）
│
├─ data/                             # ★ 数据驱动：Resource 实例（.tres）
│  ├─ items/                         # item_seed_parsnip.tres ...
│  ├─ crops/                         # crop_parsnip.tres ...
│  ├─ shops/                         # shop_seed_store.tres
│  └─ dialogue/                      # （v2 用）
│
├─ scenes/                           # ★ Godot 场景（.tscn）
│  ├─ boot/
│  │  ├─ boot.tscn                   # 启动入口
│  │  ├─ main_menu.tscn
│  │  └─ save_slot_menu.tscn
│  ├─ world/
│  │  ├─ farm.tscn                   # 主农场（含地形 GridMap）
│  │  └─ town.tscn                   # 小型商业区（种子店）
│  ├─ actors/
│  │  └─ player.tscn                 # CharacterBody3D
│  ├─ props/
│  │  ├─ crop.tscn                   # 单株作物（按生长阶段换模型/缩放）
│  │  ├─ shipping_bin.tscn
│  │  ├─ tree.tscn
│  │  └─ rock.tscn
│  └─ ui/
│     ├─ hud.tscn
│     ├─ inventory_panel.tscn
│     ├─ shop_panel.tscn
│     ├─ pause_menu.tscn
│     └─ settings_panel.tscn
│
├─ scripts/
│  ├─ autoload/                      # L3 单例（Project Settings → Globals 注册）
│  │  ├─ event_bus.gd
│  │  ├─ game_manager.gd
│  │  ├─ time_manager.gd
│  │  ├─ save_manager.gd
│  │  ├─ scene_router.gd
│  │  ├─ inventory_manager.gd
│  │  └─ audio_manager.gd
│  ├─ core/                          # L2 纯逻辑（extends RefCounted）★
│  │  ├─ clock.gd
│  │  ├─ farm_grid.gd                # ★ 与维度无关，2D/3D 通用
│  │  ├─ crop_growth.gd
│  │  ├─ inventory.gd
│  │  └─ save_model.gd
│  ├─ data/                          # L1 Resource 定义
│  │  ├─ item_data.gd
│  │  ├─ crop_data.gd
│  │  └─ shop_data.gd
│  ├─ actors/
│  │  ├─ player.gd
│  │  └─ state_machine/              # 玩家状态机
│  │     ├─ state.gd
│  │     └─ state_machine.gd
│  ├─ world/
│  │  ├─ camera_rig.gd               # ★ 固定斜俯视相机
│  │  ├─ farm_view.gd                # ★ 射线拾取 + GridMap 刷新
│  │  └─ sun_controller.gd           # ★ 时间驱动太阳
│  ├─ props/
│  │  └─ crop.gd
│  ├─ systems/
│  │  └─ season_visuals.gd           # ★ 季节视觉切换
│  └─ ui/
│
└─ test/                             # ★ GUT 单元测试
   ├─ unit/
   │  ├─ test_farm_grid.gd
   │  ├─ test_clock.gd
   │  └─ test_inventory.gd
   └─ integration/
      └─ test_save_load.gd
```

### 4.3 关键类与职责

| 层 | 脚本 | 职责 | 明确不做 |
| --- | --- | --- | --- |
| L3 | `event_bus.gd` | 跨场景信号的唯一出口（只声明 `signal`，无逻辑） | 不含业务逻辑 |
| L3 | `game_manager.gd` | 游戏生命周期、暂停、当前存档槽、全局状态机 | 不管具体系统 |
| L3 | `time_manager.gd` | 推进游戏时间，到点发信号 | **绝不直接改作物/光照** |
| L3 | `save_manager.gd` | 收集 `SaveModel` → JSON 写 `user://`；读取 + 迁移 | 不持有游戏状态 |
| L3 | `scene_router.gd` | 场景切换 + 过场淡入淡出 + 传递参数 | 不管场景内容 |
| L3 | `inventory_manager.gd` | 持有当前 `Inventory` 实例，桥接 UI 与逻辑 | 堆叠规则在 L2 |
| L3 | `audio_manager.gd` | BGM 交叉淡入、SFX 池化播放、音量总线 | — |
| L2 | `clock.gd` | 时间数值推进、季节换算、格式化 | 不发信号（由 TimeManager 发） |
| L2 | `farm_grid.gd` | 土地格子的状态字典 + 查询/修改 API（**`Vector2i` 键**） | 不管渲染、不管 3D |
| L2 | `crop_growth.gd` | 单株作物的生长进度计算 | — |
| L2 | `inventory.gd` | 格子数组、增删查、堆叠合并 | 不管 UI |
| L2 | `save_model.gd` | 纯数据容器，`to_dict()` / `from_dict()` | 不含逻辑 |
| L4 | `camera_rig.gd` | 固定斜俯视：俯角/距离/90° 旋转/跟随/边缘平移 | 不读游戏状态 |
| L4 | `player.gd` | 输入 → 意图 → 调用 L2/L3；播放动画 | 不写规则 |
| L4 | `farm_view.gd` | 鼠标射线 → 格位；订阅信号刷新 GridMap 与作物 | 不写规则 |
| L4 | `sun_controller.gd` | 按时间设太阳角度/颜色/强度 | 不推进时间 |
| L4 | `crop.gd` | 根据 `CropGrowth` 状态换模型或缩放 | 不写规则 |

### 4.4 事件通信：局部信号还是 EventBus？

**不要一刀切，按范围选：**

| 场景 | 用什么 | 理由 |
| --- | --- | --- |
| 同一场景树内，一个发射者 N 个监听者 | **局部 `signal`** | 最轻、最直观，编辑器里能直接连 |
| 发射者和监听者在**互不相关的场景** | **`EventBus` 单例** | 避免 `get_node("/root/Main/Player")` 这种脆弱路径 |
| 向一组动态增删的节点广播 | **`add_to_group` + `get_tree().call_group()`** | 听众来去自由，无需连接管理 |
| 父子固定关系、需要拖拽连线 | **编辑器里直接连** | 可视化 |

**判断口诀**：*能局部就局部，跨场景才上 EventBus。*

**EventBus 只放这些（跨场景的）：**

- 时间推进（`day_changed` 等）—— 光照、HUD、作物、商店都要知道
- 经济与物品（`gold_changed` / `item_added`）—— HUD、商店、存档都要知道
- 农场操作（`land_tilled` / `crop_harvested`）—— 农场视图、音效都要知道

**不要放进 EventBus 的**：粒子播放、按钮点击、单株作物的模型切换 —— 这些用局部信号。

### 4.5 数据驱动：Resource 还是 JSON？

| | **静态定义数据** | **运行时存档数据** |
| --- | --- | --- |
| 例子 | 作物属性、物价、物品定义 | 玩家金币、农场格子状态 |
| 格式 | Godot `Resource`（`.tres`） | **JSON** |
| 存哪 | `data/` 目录，**入版本库** | `user://saves/`，**不入版本库** |
| 为什么 | Inspector 可视化编辑，改完即生效；`@export` 字段有类型与范围校验；**能直接引用 3D 模型资源（`PackedScene`）** | ① 可读、可 diff、可手改 ② 跨版本迁移容易 ③ 不启动场景树就能单测 ④ 不受 Godot 版本升级影响 |
| 反面 | — | ❌ **不要**用 `ResourceSaver` 存存档：`.tres` 反序列化存在代码执行风险，格式也随引擎版本变动 |

> **3D 化的额外好处**：`CropData` 里可以直接 `@export var stages: Array[PackedScene]` 挂 3D 模型，在 Inspector 里**拖拽即用**，比 2D 时代挂贴图更直观。

### 4.6 关键代码骨架

**EventBus（`scripts/autoload/event_bus.gd`）—— 只声明信号，零逻辑：**

```gdscript
extends Node
## 全局事件总线。只放跨场景信号；场景内部通信请用局部 signal。

# ── 时间 ───────────────────────────────
signal minute_tick(total_minutes: int)
signal hour_changed(hour: int)
signal day_changed(day: int, season: int)
signal season_changed(season: int)
signal year_changed(year: int)
signal weather_rolled(weather: int)

# ── 经济与物品 ─────────────────────────
signal gold_changed(delta: int, total: int)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)

# ── 农场 ───────────────────────────────
signal land_tilled(cell: Vector2i)          # ★ 逻辑层用 Vector2i，与 3D 无关
signal crop_planted(cell: Vector2i, crop_id: String)
signal crop_harvested(crop_id: String, count: int)
```

*用法：*

```gdscript
EventBus.day_changed.emit(day, season)                   # 发
EventBus.day_changed.connect(_on_day_changed)            # 收
```

**TimeManager（`scripts/autoload/time_manager.gd`）—— 只推进 + 广播：**

```gdscript
extends Node
## 游戏时间推进器。唯一的"进入次日"入口就在这里。

@export var seconds_per_game_minute: float = 0.7

const DAY_START_MINUTE := 6 * 60    # 06:00
const DAY_END_MINUTE := 26 * 60     # 次日 02:00

var clock := Clock.new()
var _acc: float = 0.0

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	_acc += delta
	while _acc >= seconds_per_game_minute:
		_acc -= seconds_per_game_minute
		clock.advance_minute()
		EventBus.minute_tick.emit(clock.total_minutes)

		if clock.minute == 0:
			EventBus.hour_changed.emit(clock.hour)

		if clock.total_minutes >= DAY_END_MINUTE:
			sleep(true)
			return

## 唯一的"进入次日"入口。所有跨天结算都挂在这个信号链上。
func sleep(forced: bool) -> void:
	if forced:
		EventBus.player_collapsed.emit()    # 昏倒：体力只恢复 50%

	clock.next_day()                        # 推进日期 / 季节
	clock.weather = WeatherRoller.roll(clock)

	EventBus.day_changed.emit(clock.day, clock.season)
	if clock.is_season_start():
		EventBus.season_changed.emit(clock.season)
	if clock.is_year_start():
		EventBus.year_changed.emit(clock.year)

	SaveManager.save_auto()                 # 唯一的自动存档点
	SceneRouter.warp_home()
```

> 注意 `TimeManager` 里**没有任何一行关于太阳、UI、作物**的代码。它们各自订阅 `minute_tick` / `day_changed` 自行响应——这就是分层的价值。

**FarmGrid（`scripts/core/farm_grid.gd`）—— ★ 从 2D 原样保留，一行不改：**

```gdscript
class_name FarmGrid
extends RefCounted
## 农场土地状态。零节点依赖、零维度依赖，可在没有场景树的情况下单测。
## 格位用 Vector2i 表示（x = 东西方向，y = 南北方向），与 2D/3D 无关。

enum TileState { UNTILLED, TILLED, WATERED }

class FarmTile extends RefCounted:
	var state: TileState = TileState.UNTILLED
	var crop_id: String = ""
	var growth: int = 0
	var regrown: bool = false
	var day_planted: int = 0

var _tiles: Dictionary = {}     # Vector2i -> FarmTile

func get_tile(cell: Vector2i) -> FarmTile:
	return _tiles.get(cell)

func get_or_create(cell: Vector2i) -> FarmTile:
	if not _tiles.has(cell):
		_tiles[cell] = FarmTile.new()
	return _tiles[cell]

## 每天醒来推进一次。只有浇过水（或下雨下雪）的格子才生长。
func advance_day(weather: int, crop_lookup: Callable) -> void:
	var auto_watered: bool = weather in [Weather.RAIN, Weather.STORM, Weather.SNOW]

	for cell: Vector2i in _tiles:
		var tile: FarmTile = _tiles[cell]

		if tile.crop_id.is_empty():
			tile.state = TileState.UNTILLED
			continue

		var watered: bool = tile.state == TileState.WATERED or auto_watered
		if watered:
			var crop: CropData = crop_lookup.call(tile.crop_id)
			if not (tile.regrown and tile.growth >= crop.total_growth_days()):
				tile.growth += 1

		tile.state = TileState.TILLED     # 浇水状态每天重置
```

**CropData（`scripts/data/crop_data.gd`）—— ★ 3D 版：挂模型而非贴图：**

```gdscript
class_name CropData
extends Resource
## 作物静态数据。在 Inspector 里配置，一处改动全局生效。

@export var item_id: String = ""
@export var display_name: String = ""

## 首选：各生长阶段的完整模型场景（若素材包提供）
@export var stage_scenes: Array[PackedScene] = []
@export var days_per_stage: Array[int] = []

## 兜底：素材包不提供多阶段模型时，用同一模型 + 缩放模拟生长（见 §6.4）
@export var base_scene: PackedScene
@export var stage_scales: Array[float] = [0.35, 0.55, 0.8, 1.0]

@export var seasons: Array[int] = []
@export var regrowable: bool = false
@export var regrow_days: int = 0
@export var yield_item_id: String = ""
@export var yield_count: int = 1

func total_growth_days() -> int:
	var total := 0
	for d: int in days_per_stage:
		total += d
	return total
```

**CameraRig（`scripts/world/camera_rig.gd`）—— ★ 3D 新增：固定斜俯视相机：**

```gdscript
class_name CameraRig
extends Node3D
## 固定斜俯视相机。俯角锁死，仅允许 90° 分步旋转 + 边缘平移。
## 这是 3D 版最省事的一种相机 —— 不需要防穿模。

const PITCH_DEG: float = -52.0
const DISTANCE: float = 18.0
const YAW_STEP: float = 90.0
const PAN_SPEED: float = 14.0
const FOLLOW_LERP: float = 6.0
const PAN_LIMIT: float = 8.0

@export var target: Node3D
@onready var _cam: Camera3D = $Camera3D

var _yaw_deg: float = 0.0      # 不取模，避免补间绕远路
var _offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("camera_rig")
	rotation_degrees = Vector3(PITCH_DEG, _yaw_deg, 0.0)
	_cam.position = Vector3(0.0, 0.0, DISTANCE)

func _unhandled_input(event: InputEvent) -> void:
	var step := 0.0
	if event.is_action_pressed("camera_rotate_cw"):
		step = YAW_STEP
	elif event.is_action_pressed("camera_rotate_ccw"):
		step = -YAW_STEP
	if step != 0.0:
		_yaw_deg += step
		var t := create_tween()
		t.tween_property(self, "rotation_degrees:y", _yaw_deg, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	# 边缘平移：临时看向远处，松手回中
	var pan := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if pan != Vector2.ZERO:
		var flat := Basis(Vector3.UP, deg_to_rad(_yaw_deg))
		_offset = (_offset + flat * Vector3(pan.x, 0.0, pan.y) * PAN_SPEED * delta) \
			.limit_length(PAN_LIMIT)
	else:
		_offset = _offset.lerp(Vector3.ZERO, FOLLOW_LERP * delta)

	if target == null:
		return
	var desired := target.global_position + _offset
	desired.y = 0.0
	global_position = global_position.lerp(desired, FOLLOW_LERP * delta)
```

**Player（`scripts/actors/player.gd`）—— ★ 3D：相机相对移动：**

```gdscript
class_name Player
extends CharacterBody3D

@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var accel: float = 24.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rig: CameraRig = null

func _ready() -> void:
	_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3.ZERO

	if input != Vector2.ZERO:
		# ★ 关键：把输入按相机 yaw 旋转，让 W 永远是"屏幕上方"
		var yaw: float = _rig.rotation.y if _rig != null else 0.0
		dir = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw).normalized()
		# 角色转向移动方向
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.25)

	var speed: float = run_speed if Input.is_action_pressed("run") else walk_speed
	var target_vel := dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	move_and_slide()
```

**FarmView（`scripts/world/farm_view.gd`）—— ★ 3D 新增：鼠标射线拾取格位：**

```gdscript
class_name FarmView
extends Node3D
## 把「鼠标点击」翻译成「农场格位」，并负责把 FarmGrid 的状态画出来。

@export var ground_y: float = 0.0

@onready var _soil: GridMap = %SoilGridMap

var _farm_grid: FarmGrid

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Variant = _pick_cell()
		if cell != null:
			EventBus.cell_clicked.emit(cell)

## 鼠标 → 世界坐标 → 网格坐标。
## 农场是水平面，用 Plane 求交比射线查询物理世界更快更稳。
func _pick_cell() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null

	var mpos := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mpos)
	var normal := cam.project_ray_normal(mpos)

	var hit: Variant = Plane(Vector3.UP, ground_y).intersects_ray(origin, normal)
	if hit == null:
		return null

	# ★ GridMap 的 local_to_map 需要本地坐标，先 to_local
	var map_pos: Vector3i = _soil.local_to_map(_soil.to_local(hit))
	if map_pos.y != 0:
		return null
	return Vector2i(map_pos.x, map_pos.z)

## 订阅 land_tilled / crop_planted / day_changed，重绘相关格子
func refresh_cell(cell: Vector2i) -> void:
	var tile: FarmGrid.FarmTile = _farm_grid.get_tile(cell)
	if tile == null:
		_soil.set_cell_item(Vector3i(cell.x, 0, cell.y), -1)   # -1 = 清空
		return

	var item_id: int = FarmGrid.TileState.UNTILLED
	match tile.state:
		FarmGrid.TileState.UNTILLED: item_id = 0    # 荒草
		FarmGrid.TileState.TILLED:   item_id = 1    # 翻过土
		FarmGrid.TileState.WATERED:  item_id = 2    # 浇过水（深色）
	_soil.set_cell_item(Vector3i(cell.x, 0, cell.y), item_id)
```

**SunController（`scripts/world/sun_controller.gd`）—— ★ 3D 新增：太阳即时钟：**

```gdscript
extends Node3D
## 订阅时间信号，驱动太阳角度与颜色。太阳的弧线就是玩家看到的时钟。

@export var sun: DirectionalLight3D
@export var sunrise_color: Color = Color(1.0, 0.74, 0.5)
@export var noon_color: Color = Color(1.0, 0.98, 0.92)
@export var sunset_color: Color = Color(1.0, 0.6, 0.4)

const SUNRISE_MIN := 6 * 60
const SUNSET_MIN := 20 * 60

func _ready() -> void:
	EventBus.minute_tick.connect(_on_minute_tick)

func _on_minute_tick(total_minutes: int) -> void:
	var t: float = clampf(
		float(total_minutes - SUNRISE_MIN) / float(SUNSET_MIN - SUNRISE_MIN), 0.0, 1.0)

	# 俯仰：日出时贴近地平线，正午最高
	sun.rotation_degrees.x = lerpf(-15.0, -80.0, sin(t * PI))
	# 方位：东 → 西
	sun.rotation_degrees.y = lerpf(90.0, 270.0, t)

	# 颜色：两端偏暖，正午偏白
	sun.light_color = sunrise_color.lerp(noon_color, sin(t * PI) if t < 0.5 else 1.0) \
		if t < 0.5 else noon_color.lerp(sunset_color, (t - 0.5) * 2.0)
```

**SaveManager（`scripts/autoload/save_manager.gd`）—— JSON + 版本迁移：**

```gdscript
extends Node
## 存档读写。JSON 格式 + version 字段 + 逐级迁移。

const CURRENT_VERSION := 4

func slot_path(slot: int) -> String:
	return "user://saves/slot_%d.json" % slot

func save_game(slot: int) -> void:
	var model := SaveModel.collect()
	model.version = CURRENT_VERSION

	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(model.to_dict(), "\t"))
	f.close()

func load_game(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		push_error("存档损坏: %s" % path)
		return {}

	# 逐级迁移
	while int(data.get("version", 1)) < CURRENT_VERSION:
		data = SaveMigrator.migrate(data)

	return data

func save_auto() -> void:
	if GameManager.current_slot > 0:
		save_game(GameManager.current_slot)
```

**GUT 单元测试（`test/unit/test_farm_grid.gd`）—— ★ 完全不启动 3D 场景：**

```gdscript
extends GutTest
## FarmGrid 单元测试。注意：不依赖场景树、不依赖 3D 渲染。

var _grid: FarmGrid

func before_each() -> void:
	_grid = FarmGrid.new()

func _fake_crop() -> CropData:
	var c := CropData.new()
	c.item_id = "parsnip"
	c.days_per_stage = [1, 1, 1, 1]     # 共 4 天
	return c

func _lookup(_id: String) -> CropData:
	return _fake_crop()

# ── 翻地 ───────────────────────────────
func test_new_tile_is_untilled() -> void:
	var tile := _grid.get_or_create(Vector2i(3, 4))
	assert_eq(tile.state, FarmTile.State.UNTILLED, "新格子应该是未翻土")

# ── 生长：核心规则 ──────────────────────
func test_unwatered_crop_does_not_grow() -> void:
	var tile := _grid.get_or_create(Vector2i(3, 4))
	tile.crop_id = "parsnip"
	tile.state = FarmTile.State.TILLED
	_grid.advance_day(Weather.SUNNY, _lookup)
	assert_eq(tile.growth, 0, "没浇水不应该生长")

func test_watered_crop_grows_one_day() -> void:
	var tile := _grid.get_or_create(Vector2i(3, 4))
	tile.crop_id = "parsnip"
	tile.state = FarmTile.State.WATERED
	_grid.advance_day(Weather.SUNNY, _lookup)
	assert_eq(tile.growth, 1, "浇过水应该生长 1 天")

func test_rain_auto_waters() -> void:
	var tile := _grid.get_or_create(Vector2i(3, 4))
	tile.crop_id = "parsnip"
	tile.state = FarmTile.State.TILLED
	_grid.advance_day(Weather.RAIN, _lookup)
	assert_eq(tile.growth, 1, "下雨应该自动浇水")

func test_watering_resets_each_day() -> void:
	var tile := _grid.get_or_create(Vector2i(3, 4))
	tile.crop_id = "parsnip"
	tile.state = FarmTile.State.WATERED
	_grid.advance_day(Weather.SUNNY, _lookup)
	assert_eq(tile.state, FarmTile.State.TILLED, "第二天浇水状态应重置")
```

> **状态枚举定义在 `FarmTile.State`，不是 `FarmGrid.TileState`。**
> 理由：格位状态属于「格子」这个概念，放在 `FarmTile` 里才不会有
> `FarmGrid` ↔ `FarmTile` 的循环依赖。本文件早期草稿写的是 `FarmGrid.TileState`，
> **以实现为准**。

*跑测试：*

```bash
# 编辑器里：底部 GUT 面板点运行
# 命令行（可接 CI）：
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

### 4.7 GDScript 编码纪律（贴到 README）

```gdscript
# ── 类型标注：每个变量、参数、返回值都要有 ──────
var speed: float = 4.5
var enemies: Array[Node3D] = []          # 类型化数组
var stats: Dictionary[String, int] = {}  # 类型化字典（4.4+）

func heal(amount: int) -> void:
	...

# ── 类型推断用 := ─────────────────────────────
var velocity := Vector3.ZERO
@onready var _cam: Camera3D = $Camera3D

# ── 成员声明顺序（按官方 style guide）──────────
# class_name/extends → 文档注释 → signal → enum → const
# → @export 变量 → 普通变量 → @onready 变量
# → _init → _ready → 其它虚函数 → 公开方法 → 私有方法

# ── 场景引用 ─────────────────────────────────
$Path/To/Node              # 固定路径可接受
%UniqueName                # 推荐：场景唯一名，改名/挪位置都不怕
const CropScene := preload("res://scenes/props/crop.tscn")   # 静态路径用 preload

# ── 3D 特有提醒 ──────────────────────────────
# Vector3 的 y 是"上"，不是"里"。地面用 x/z，高度用 y。
# 拿 Vector3 当 Vector2 用是最常见的 3D 新手 bug。

# ── 缩进用 Tab，字符串默认双引号，软上限 100 字符 ─
```

#### 严格模式的五条实战规则（M0 踩坑总结，务必先读）

项目把 `untyped_declaration` / `unsafe_*` 全部设成了 **Error**。这套严格模式很好用，
但有五条反直觉的地方，不知道会反复撞墙：

**① `@warning_ignore` 只作用于「下一条语句」，不是整个函数。**
要给整个函数豁免，必须把转换写成独立的赋值语句：

```gdscript
# ✗ 无效：注解不会豁免整个函数体
@warning_ignore("unsafe_call_argument")
static func to_int(value: Variant) -> int:
	return int(value)

# ✓ 有效：注解紧贴那一条语句
if value is float:
	@warning_ignore("unsafe_call_argument")
	var converted: int = int(value)
	return converted
```

**② 类型收窄对「直接 return」有效，对「转换构造器」无效。**
`if value is int: return value` 能过；`if value is float: return int(value)` 会被拦。

**③ `or` 会破坏类型收窄。** 这是最容易踩的：

```gdscript
if value is int or value is float:      # ✗ 不收窄，int(value) 仍报 unsafe
	return int(value)

if value is int:                        # ✓ 拆开才收窄
	return value
if value is float:
	...
```

**④ `and` 链不会收窄参数类型。** 别写 `if event is InputEventKey and event.pressed:`
—— 会报 "property not present on type InputEvent"。必须先单独判类型再取强类型引用。

**⑤ 用 `floori()/ceili()/roundi()`，不要 `int(floor())`。**
Godot 全局的 `floor()` 返回签名是 `Variant`，传给 `int()` 会触发 unsafe 警告。

**所有这些"不安全转换"都集中在 `scripts/core/variant_util.gd` 一个文件里**
（JSON 反序列化天生需要它）。其余代码保持 100% 严格 —— 审代码时只需要盯那一个文件。

另外：**容器一律用类型化写法**，这是让严格模式不难受的关键。

```gdscript
var tiles: Dictionary[Vector2i, FarmTile] = {}   # 取出即 FarmTile，不是 Variant
var stats: Dictionary[String, int] = {}
var crops: Array[CropData] = []
```

---

## 5. 关键技术方案（3D）

### 5.1 渲染管线初始配置（**必须在 M0 就配好**）

3D 项目最容易翻车的地方是"画面又糊又闪"。这几项设置一次，全项目受益。

**Project Settings 配置：**

```
Rendering → Renderer
  Rendering Method        = forward_plus        # ★ 桌面全特性（已定死）

Rendering → Anti Aliasing
  MSAA 3D                 = 2x  或  4x          # ★ 低多边形必开！
                                                #   低模硬边极多，关掉会满屏锯齿
  Screen Space AA         = FXAA（可选）        #   补 MSAA 处理不到的透明边缘

Rendering → Environment（也可在 WorldEnvironment 节点里设）
  Tonemap Mode            = Filmic 或 AgX
  Ambient Light Source    = Sky                 # 让阴影里不是死黑
  Reflection Source       = Sky

Rendering → Lights and Shadows
  Directional Shadow Size = 2048 或 4096        # 取决于场景尺度
  Shadow Atlas Size       = 2048
  Soft Shadow Quality     = Medium

Physics → 3D
  Physics Engine          = Jolt Physics 3D     # ★ 4.6 起已是默认，核对一下
```

> ⚠️ **Godot 4.7 改过部分默认值，别信默认。** 尤其是：4.6 起 Windows 新项目默认用 **D3D12** 后端；4.6 起 **Jolt** 成为 3D 物理默认。升级项目时逐项核对。

**为什么 MSAA 在 3D 里比 2D 重要得多？**

| | 2D 像素游戏 | 3D 低多边形 |
| --- | --- | --- |
| 边缘 | 严格对齐像素网格，天然锐利 | 三角形边缘是任意角度，**必然产生锯齿** |
| 抗锯齿 | 通常关掉（要的就是硬像素感） | **必须开**，否则一动起来满屏"爬行"的锯齿 |

**分辨率与窗口：**

```
Display → Window
  Viewport Width  = 1920
  Viewport Height = 1080
  Stretch → Mode  = disabled      # ★ 3D 用 disabled，按原生分辨率渲染
  Stretch → Aspect = expand
```

> **和 2D 方案的关键差别**：2D 像素游戏用 `viewport` 模式（整数缩放、像素锐利），**3D 必须用 `disabled`**——3D 渲染到低分辨率再放大只会糊。3D 项目不需要"像素完美"，需要的是抗锯齿和稳定的帧率。

### 5.2 3D 地形与土地格子

**农田是"平面网格"，地形是"静态网格"。两者分工明确：**

```
Farm (Node3D)
├─ WorldEnvironment                  # 天空/环境光/色调映射/雾
├─ Sun (DirectionalLight3D)          # 太阳，由 SunController 驱动
├─ Terrain (GridMap)                 # 静态地形：草地/泥路/水面
│     cell_size = Vector3(1, 1, 1)   # ★ 一旦设定，绝不在运行中改
│     mesh_library = terrain_library.tres
├─ SoilGridMap (GridMap)             # ★ 耕地土壤：荒草/翻土/浇水 三种 tile
│     mesh_library = soil_library.tres
├─ Crops (Node3D)                    # ★ 作物：每格一个 crop.tscn 实例
│     └─ crop.tscn (Crop instances)  #   需要按生长阶段换模型/缩放
├─ Props (Node3D)                    # 树/岩石/栅栏/出货箱
└─ Player (player.tscn)              # CharacterBody3D
```

**为什么土壤用 `GridMap`，作物用独立实例？**

| | 土壤 | 作物 |
| --- | --- | --- |
| 状态数 | 3 种（荒草/翻土/浇水） | 每株独立（生长进度、品种、是否循环） |
| 变化频率 | 低 | 每天变、要播动画 |
| 用什么 | **`GridMap` + `set_cell_item()`** | **每格一个 `crop.tscn` 实例** |
| 理由 | GridMap 天生就是"网格上放同一批 mesh"，改一格只是一次字典写入，极省 | 作物需要独立模型、独立动画、独立缩放，GridMap 做不到 |

**GridMap 使用要点：**

```gdscript
# 格位坐标 → 世界坐标
var world: Vector3 = soil_grid_map.map_to_local(Vector3i(x, 0, z))
# 世界坐标 → 格位坐标（注意要先 to_local）
var cell: Vector3i = soil_grid_map.local_to_map(soil_grid_map.to_local(world_pos))
# 设置/清空一格
soil_grid_map.set_cell_item(Vector3i(x, 0, z), item_id)   # item_id = -1 表示清空
```

> ⚠️ **GridMap 三条铁律（都是踩过才知道的）**：
> 1. **`cell_size` 一旦开始铺格子就不要再改** —— 改它不会更新已存在的格子，只会让新旧格子错位。要在 M0 就定死。
> 2. **GridMap 不会自动生成导航网格** —— v2 做 NPC 时要手动烘 `NavigationRegion3D`。
> 3. **MeshLibrary 里的 item 必须带碰撞形状** —— 从场景转 MeshLibrary 前，确认 `StaticBody3D` + `CollisionShape3D` 齐全，否则会出现"看得见但会掉下去"的隐形地块。

**逻辑与表现的分工（这条和 2D 版完全一致）：**

| | 存哪 | 谁改 |
| --- | --- | --- |
| **土地/作物的状态** | L2 的 `FarmGrid`（`Vector2i` 字典） | 游戏逻辑 |
| **土地/作物的外观** | `SoilGridMap` / `Crops` 节点 | 订阅信号后刷新 |

**为什么不把状态塞进 GridMap 的自定义数据层？**

GridMap 的 custom data 是为**静态关卡数据**设计的。运行时状态（每格作物长几天、浇没浇水）塞进去会：取一格状态要 `get_cell_item` 再翻字典（绕且慢）、无法单独单元测试、存档要遍历整个 GridMap。用 `FarmGrid` 一个字典存状态、视图只负责重绘，**逻辑和表现彻底解耦**。

**作物生长阶段的表现方案（见 §6.4 的素材问题）：**

```gdscript
# crop.gd —— 优先用分阶段模型，缺了就用缩放兜底
func _apply_stage(stage: int) -> void:
	if not _data.stage_scenes.is_empty():
		# 方案 A：素材包提供了分阶段模型
		_swap_model(_data.stage_scenes[clampi(stage, 0, _data.stage_scenes.size() - 1)])
	else:
		# 方案 B：只有一个模型 → 缩放 + 微调颜色模拟生长
		var s: float = _data.stage_scales[clampi(stage, 0, _data.stage_scales.size() - 1)]
		_model_root.scale = Vector3.ONE * s
		_model_root.position.y = 0.0     # 从地面往上长，不是从中心放大
```

### 5.3 玩家控制器（3D）

**"相机相对移动"是第一原则**：玩家按 `W` 必须永远朝屏幕上方走，而不是朝世界 -Z 走。代码见 §4.6 的 `player.gd`。

**节点结构：**

```
Player (CharacterBody3D)
├─ CollisionShape3D          # CapsuleShape3D（人形首选：过台阶和斜坡最顺）
├─ Visual (Node3D)
│   └─ Model                 # 角色 GLB（含 Skeleton3D 与 AnimationPlayer）
├─ AnimationTree             # idle / walk / run / use_tool 融合
├─ ToolHitbox (Area3D)       # 工具作用范围，默认 disabled
└─ StateMachine
   └─ IdleState / MoveState / UseToolState / ExhaustedState
```

**`CharacterBody3D` 关键属性：**

| 属性 | 建议值 | 说明 |
| --- | --- | --- |
| Motion Mode | `Grounded` | 走路类角色用这个 |
| Up Direction | `(0, 1, 0)` | 默认 |
| Floor Max Angle | `45°` | 超过这个角度视为墙 |
| Floor Stop on Slope | 开 | 斜坡上停下而不是滑下去 |

**碰撞形状用胶囊体**（不要用方块）：胶囊在过台阶和斜坡时不会卡在转角，这是 3D 角色控制最常见的坑。

### 5.4 鼠标拾取与交互（3D 特有）

2D 里 `get_global_mouse_position()` 一句话就能拿到世界坐标；**3D 里没有这么便宜的事**——屏幕上的一个点对应的是一条**射线**。有两种做法：

| 方法 | 适用 | 本项目 |
| --- | --- | --- |
| **与数学平面求交**（`Plane.intersects_ray`） | 目标是**水平面**时 | ✅ **采用**——农田就是一个水平面，最快最稳，不依赖物理体 |
| 射线查询物理世界（`intersect_ray` + `PhysicsRayQueryParameters3D`） | 目标是任意形状的物体 | 留给 v2 的"点击 NPC/箱子" |

```gdscript
# 平面求交才是农场格子的正解，因为它不需要任何碰撞体
var hit: Variant = Plane(Vector3.UP, ground_y).intersects_ray(origin, normal)
```

**点击落在哪一格 → 高亮预览**（M2 做）：用一个半透明的 `MeshInstance3D` 方块贴在指针所指的格子上，能给玩家即时反馈"我要动的是这一格"。**在 3D 里这个视觉反馈比在 2D 里重要得多**——因为 2D 是俯视平铺，玩家天然知道鼠标指着哪格；3D 有透视，不预览就很容易点错。

### 5.5 光照与时间/季节表现（★ 3D 的加分项）

这是 3D 化最值得做的事：**把抽象的"时间"和"季节"变成看得见的画面。**

**一天的叙事（由 `SunController` 驱动，见 §4.6）：**

| 时段 | 太阳 | 画面 |
| --- | --- | --- |
| 06:00 日出 | 贴近地平线、偏东、暖橙色 | 长影子、整体偏暖 |
| 12:00 正午 | 最高、接近垂直、偏白 | 短影子、色彩饱和 |
| 18:00 黄昏 | 降至地平线、偏西、橙红 | 长影子、环境光偏红 |
| 20:00 之后 | 关闭太阳，环境光转冷蓝 | 夜幕 |

**环境光的配合**（`Environment`）：

- `ambient_light_source = Sky`，让天空颜色参与环境光——这样黄昏时整个场景会自然泛红，不需要手动调
- 夜晚把 `ambient_light_energy` 调低，并加一层冷色 tint

**季节表现（M5 做，方案 A 优先）：**

| 季节 | 做法 |
| --- | --- |
| **方案 A（推荐，零 shader 工作）** | **准备 4 套 `MeshLibrary`**，跨季时直接 `terrain.mesh_library = spring_library`。草地/树叶/花卉一次换掉，简单可靠 |
| 方案 B | 给关键材质加一个全局 `season_tint` uniform，跨季时插值过渡。更平滑，但要写 shader |
| 通用 | 调整太阳高度角范围与天空 HDRI（春天更高更亮、冬天更低更灰） |

> 首版先做**方案 A**：跨季瞬间切换虽然"跳"，但工作量为零，且玩家在睡觉后醒来看到全新的世界，这个"跳"反而有仪式感。

### 5.6 性能预算（3D 特有）

3D 的性能开销和 2D 不在一个量级，需要一份明确的预算：

| 指标 | 目标 | 做法 |
| --- | --- | --- |
| 帧率 | **稳定 60 fps**（1080p） | — |
| Draw Call | **< 1000** | 同材质物件合批、`MultiMeshInstance3D` 铺大量重复物 |
| 三角面 | **< 300k**（低模素材包天然满足） | 用 LOD |
| 阴影距离 | 只覆盖玩家附近（约 40m） | `DirectionalLight3D.directional_shadow_max_distance` |
| 阴影贴图 | 2048，2–4 级级联 | 别用 4×4096 |

**具体手段：**

| 问题 | 手段 |
| --- | --- |
| 树/岩石/草丛几百上千个 | **`MultiMeshInstance3D`**：一次 draw call 画完全部同类物件 |
| 远处物件仍在渲染 | **LOD**（`MeshInstance3D` 的 visibility range）+ 距离剔除 |
| 室内/城镇有大量遮挡 | **`OccluderInstance3D`** 手动遮挡剔除 |
| 每帧 `_process` 遍历所有格子 | ❌ 禁止。改**事件驱动**：`day_changed` 时一次性结算（和 2D 版同一条纪律） |
| 每帧 `get_node()` | `@onready` 缓存一次 |

**性能调试工具**：编辑器里的 **Debugger → Monitors**（看 FPS/draw call/顶点数）+ **Profiler**（看 CPU/GPU 各阶段耗时）。**M0 就把这两块看熟，别等到卡了再回头找。**

### 5.7 3D 特有的坑（对照 2D 方案）

换到 3D，一些旧问题消失了，新问题冒出来了：

| | 2D 像素（v2） | **3D 低多边形（v3）** |
| --- | --- | --- |
| **遮挡排序** | 要手写 `y_sort_enabled` + `y_sort_origin`，容易错 | ✅ **深度缓冲自动处理**，不用管 |
| **透明材质** | 无此问题 | ⚠️ **新坑**：树叶/玻璃/水面这类半透明物会互相插错。对策：能不用透明就不用；必须用就调 `render_priority`，或用 alpha-scissor |
| **画面模糊** | 要用 `viewport` + `Nearest` 保像素锐利 | ⚠️ **反过来**：必须开 MSAA，且 `Stretch Mode = disabled` |
| **相机穿模** | 无此问题 | ✅ 固定斜俯视规避了（第三人称才需要处理） |
| **Z-fighting** | 无此问题 | ⚠️ 共面物体闪烁。对策：贴花/路面不要与地面完全同高，抬高 0.001m |
| **素材体积** | 单张 PNG，几十 KB | ⚠️ 单个 GLB 可达几 MB，**建议启用 Git LFS**（§8.2） |

---

## 6. 美术与音频资源

### 6.1 素材包清单（★ 全部 CC0，可商用免署名）

这是 3D 方案最舒服的一处——**顶级 3D 素材源几乎清一色 CC0**。

| 用途 | 素材包 | 作者 | 授权 |
| --- | --- | --- | --- |
| **主素材：地形/树木/岩石/花草** | **Kenney Nature Kit** | Kenney | **CC0** |
| **农场建筑/道具/栅栏** | **Kenney Fantasy Town Kit** / Survival Kit | Kenney | **CC0** |
| 食物 / 作物道具模型 | **Kenney Food Kit** | Kenney | **CC0** |
| 室内家具（如需要） | Kenney Furniture Kit | Kenney | **CC0** |
| **自然与作物（款式更丰富）** | **Quaternius Ultimate Nature Pack** | Quaternius | **CC0** |
| **角色（玩家 + NPC）** | **Quaternius Universal Base Characters** | Quaternius | **CC0** |
| **角色动画库** | **Quaternius Universal Animation Library** | Quaternius | **CC0** |
| 动画补充（自动绑骨） | Mixamo | Adobe | 免费商用 |
| 天空盒 / HDRI | Poly Haven | Poly Haven | **CC0** |
| PBR 材质与贴图 | ambientCG | ambientCG | **CC0** |
| 音效（脚步/UI/工具/自然） | Kenney Audio Packs | Kenney | **CC0** |
| 背景音乐 | OpenGameArt / FreePD | 多位 | CC0 / CC-BY |
| UI 字体 | 缝合像素字体（Fusion Pixel Font）或任意 OFL 字体 | TakWolf 等 | OFL-1.1 |

**推荐组合**：**Kenney Nature Kit + Quaternius Ultimate Nature + Quaternius Base Characters** 这三套，就能覆盖首版的全部美术需求，且**三种资源包的风格都是"干净低多边形"，能融到一起**。

> **风格基准一旦锁定，之后所有素材都要能融进去。** Kenney 和 Quaternius 的色调偏明快饱和，这是我们要的风格基准。

### 6.2 导入规范

| 项 | 规范 |
| --- | --- |
| **模型格式** | **GLB / glTF**（Godot 一等支持，单文件含贴图与动画） |
| ~~FBX~~ | ⚠️ **Godot 不原生支持 FBX**，需要 FBX2glTF 转换或先在 Blender 里导出 GLB。**能不用就不用** |
| 场景导入 | 导入 `.glb` 时在 Import 面板勾选所需内容（mesh / animation / material），别全量导入 |
| 三角面 | 单个道具 < 500 tris，角色 < 5k tris，建筑 < 2k tris |
| 材质 | 优先用素材包自带的共享材质（利于合批） |
| 命名 | `snake_case`，如 `crop_parsnip.glb`、`char_player.glb`、`tree_oak_lod1.glb` |
| 动画 | 统一用 `AnimationPlayer`；多动画用 `AnimationLibrary` 归组 |
| 图标（UI 用） | PNG，**过滤 `Linear`**（3D 项目的 UI 不是像素风，不需要 `Nearest`） |
| 音频 | BGM 用 `.ogg`（可循环），SFX 用 `.wav`（低延迟） |
| `.import` 文件 | ✅ **要提交**（Godot 的导入配置，文本格式） |

> **和 2D 方案的一处反转**：2D 里 UI 图标必须设 `Nearest` 保像素锐利；**3D 项目里 UI 图标用 `Linear`**——低多边形风格配像素化图标会显得廉价。

### 6.3 ⚠️ 授权说明（这次是"好消息"）

**2D 方案里最严重的一条红线，在 3D 方案里消失了：**

| | 2D 方案（v2） | **3D 方案（v3）** |
| --- | --- | --- |
| 主素材 | Sprout Lands，免费版 **仅限非商用** | **Kenney / Quaternius，CC0** |
| 能否商用 | ❌ 要买 $3.99 高级版才行 | ✅ **可以，且免署名** |
| 风险等级 | 🔴 高（容易误用） | 🟢 低 |

**行动要求：**

1. 建 `assets/CREDITS.md`，逐条记录：素材名 / 作者 / 授权 / 来源 URL。
2. **CC0 虽免署名，仍建议署名** —— 这是对创作者的尊重，也让项目看起来更专业。
3. ⚠️ **仍要警惕混入非 CC0 素材**：Sketchfab / CGTrader 上的模型授权各异（很多是 CC-BY 或仅限个人使用）。**只用 Kenney / Quaternius / Poly Haven / ambientCG 这几家，风险几乎为零。**

### 6.4 ⚠️ 3D 特有的素材问题：作物生长阶段

这是 3D 化遇到的**唯一一个"素材包帮不上忙"的地方**，必须提前说清楚。

**问题**：2D 素材包习惯提供"同一种作物的 5 个生长阶段各一张图"。**3D 素材包几乎不提供"同一株作物的多个生长阶段模型"**——因为那意味着设计师要为每种作物建 4–5 个模型。

**三个对策，按推荐度排序：**

| 方案 | 做法 | 优点 | 缺点 |
| --- | --- | --- | --- |
| **A. 缩放模拟（推荐，首版用）** | 用成熟期模型，按阶段改 `scale`（0.35 → 1.0），并从地面往上长 | **零额外素材成本**，当天就能做 | 视觉上"小苗=缩小的大苗"，不如真实生长自然 |
| **B. 自建两阶段** | 只用 Blender 做"幼苗"和"成熟"两个阶段（低模很简单） | 观感明显更好 | 每种作物多 1 个模型的工作量 |
| **C. 找现成的分阶段素材** | 少数素材站（如 itch.io 上的农业包）有此设计 | 最理想 | 免费且 CC0 的极少，多半要付费 |

**结论：首版用方案 A 上线，验证玩法后再逐个换方案 B。** 这个取舍已经写进 `CropData` 的设计里（§4.6 的 `stage_scenes` 优先、`stage_scales` 兜底）。

---

## 7. 开发里程碑

原则：**每个里程碑结束必须是一个"能玩"的状态**，不允许出现"系统都写了一半但什么都玩不了"的阶段。

| # | 里程碑 | 内容 | 出口标准（可玩） |
| --- | --- | --- | --- |
| **M0** | 项目骨架 + 3D 管线 | Godot 项目初始化、**Forward+ 渲染器 + Jolt 物理 + MSAA 配好**、目录结构、Git 忽略规则、GUT 装上、`WorldEnvironment` + 太阳 + 一块地面、相机骨架、`EventBus`/`GameManager`/`SceneRouter` 骨架、主菜单 | 启动 → 主菜单 → 进入空农场 → **能看到天空、阴影，玩家是个胶囊体能走动** → ESC 退出。GUT 能跑通一个空测试 |
| **M1** | 时间 + 玩家 + 相机 | `TimeManager` + `Clock`（含单测）、HUD（时间/日期/金币）、`CameraRig` 固定斜俯视（跟随 + 90° 旋转 + 边缘平移）、`CharacterBody3D` 相机相对移动 + 角色动画、**`SunController` 驱动太阳** | 能在农场跑动，相机可旋转，HUD 时间在走，**太阳在天空移动**，到 02:00 自动进次日 |
| **M2** | **种植闭环** ★ | `FarmGrid`（L2，含单测）、`SoilGridMap` + 土地视觉、**鼠标射线拾取 + 格子高亮预览**、`CropData` + 5 种作物 + `crop.tscn`、工具系统 + 快捷栏、生长/浇水/收获 | **能翻地 → 播种 → 浇水 → 睡觉 → 收获。核心循环成立** |
| **M3** | 背包 + 体力 + 经济 | `Inventory` + 背包 UI + 拖拽、体力系统 + 体力条 + 昏倒、种子店（买卖）、出货箱 | 能种菜赚钱、体力耗尽会昏倒、能买新种子继续种 |
| **M4** | 存档 | `SaveModel`（含 `Vector3` 位置）、`SaveManager`（JSON 存读 + 自动存 + 迁移骨架）、存档槽 UI | 关掉游戏再开，**位置、田地状态、金币全部还在** |
| **M5** | 打磨 + 打包 | BGM/SFX、暂停菜单/设置（音量/按键）、**季节视觉切换（4 套 MeshLibrary）**、主菜单美化、**导出 Windows 包** | **拿到 Windows 可执行包，可以发给朋友玩** |

**投入估算（单人业余，每周 ~10 小时）：**

```
M0 ▏██                                    1.0 周
M1 ▏███                                   1.5 周
M2 ▏███████                               3.5 周   ★ 核心
M3 ▏████                                  2.0 周
M4 ▏██                                    1.0 周
M5 ▏████                                  2.0 周
   └──────────────────────────────────────
   合计 ≈ 11 周（全职 ≈ 2.5–3 周）
```

**与 2D 方案的对比**：2D「小而全」（含 NPC/钓鱼/矿洞）约 17.5 周；**3D「核心闭环」约 11 周**。也就是说：**用"少做三个系统"换来了"画面从 2D 升级到 3D"**，总工期反而更短。

> **如果时间比预期充裕**，按这个顺序加回来（每加一个都必须能独立玩）：
> 1. **NPC + 对话 + 好感度**（给世界注入"人味"，性价比最高）
> 2. **钓鱼**（短周期多巴胺，独立于其他系统，风险低）
> 3. **矿洞 + 战斗**（最重、最容易失控，**永远放最后**）

---

## 8. Git 工作流

### 8.1 `.gitignore`

```gitignore
# ── Godot 4 ──────────────────────────────
.godot/
/android/
export_presets.cfg
*.translation

# ── 构建产物 ──────────────────────────────
/build/
/export/
*.exe
*.pck
*.zip
*.apk
*.aab

# ── 操作系统 ──────────────────────────────
.DS_Store
Thumbs.db
desktop.ini

# ── 编辑器 ────────────────────────────────
.vscode/
.idea/
*.swp

# ── 3D 工具（若在本机用 Blender 微调素材）──
*.blend1
*.blend2
```

> **注意**：Godot 4 的缓存目录是 `.godot/`（不是 Godot 3 的 `.import/`），必须忽略。
> 但素材旁边的 `*.import` **文件要提交**，它们是导入配置，不是缓存。
>
> `export_presets.cfg` 要不要入库有争议：单人项目入库方便，**但只要涉及发布（含签名密钥路径），建议排除并单独保管**。

### 8.2 `.gitattributes`（★ 3D 版有重要变化）

```gitattributes
# 默认：所有文本文件用 LF，提交时统一
* text=auto eol=lf

# GDScript / 场景 / 配置 / 数据 视为文本
*.gd         text
*.tscn       text
*.tres       text
*.import     text
*.godot      text
*.json       text
*.md         text
*.cfg        text

# ── 3D 模型 ──────────────────────────────
# GLB 是二进制（单文件含贴图与动画），GLTF 是文本 + 外部资源
*.glb        binary
*.gltf       text
*.bin        binary
*.fbx        binary
*.obj        text

# 2D 素材（UI 图标、立绘）
*.png        binary
*.jpg        binary
*.webp       binary

# 音频 / 字体
*.wav        binary
*.ogg        binary
*.mp3        binary
*.ttf        binary
*.otf        binary

# ── ★ 强烈建议在 3D 项目里启用 Git LFS ──
# 3D 素材体积比 2D 大一个量级，通常几十 MB 就会到账。
# 开启前先执行一次：git lfs install
*.glb  filter=lfs diff=lfs merge=lfs -text
*.fbx  filter=lfs diff=lfs merge=lfs -text
*.wav  filter=lfs diff=lfs merge=lfs -text
*.ogg  filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
```

> ⚠️ **不要给 `.tscn` / `.tres` / `.gd` 加 LFS** —— 它们是文本格式，LFS 会让 diff 和合并全部失效，出问题时连手改都改不了。
>
> **3D 项目建议尽早开 LFS**：2D 项目素材 <100MB 可以先不开，但**3D 模型很容易冲过这条线**（一个角色的 GLB 带动画就可能 5–10MB，几十个资产就几十 MB）。本机已装 git-lfs 3.5.1，随时可用。
> **注意**：LFS 一旦启用，**所有协作者都必须装 git-lfs**，否则克隆下来的是指针文件而非真实模型。

### 8.3 分支与提交规范

**分支：**

```
main            ← 始终可运行、可玩。每个里程碑结束从这里打 tag
 └─ feat/m2-farming     功能分支
 └─ fix/crop-wither-bug 修复分支
```

**提交信息（Conventional Commits）：**

```
feat(farming): 实现锄头翻地与土地状态机
fix(time): 修复跨季时作物未枯萎的问题
feat(camera): 实现固定斜俯视相机与 90 度分步旋转
feat(world): 接入 GridMap 铺设农田土壤层
art(models): 导入 Kenney Nature Kit 低多边形素材
perf(world): 用 MultiMeshInstance3D 合并树木绘制
docs(design): 补充 3D 相机与射线拾取方案
test(core): 为 FarmGrid 补充浇水生长的单元测试
chore(repo): 启用 Git LFS 管理 GLB 模型
```

**Tag：** 每个里程碑结束打一个，如 `v0.2-farming-loop`。
**建议**：提交前跑一次 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`，测试不过不提交。

---

## 9. 风险与降级预案

| # | 风险 | 概率 | 影响 | 对策 |
| --- | --- | --- | --- | --- |
| 1 | **3D 手感调不好**（相机角度、移动速度、点击拾取别扭） | 🔴 高 | 🔴 高 | 相机与移动**放到 M1 就做**，并且**不接任何玩法先纯跑一段**感受；M0 就定死渲染器与相机参数；宁可多花两天调手感，也不要带着别扭的手感往下堆内容 |
| 2 | **范围蔓延**（"再加个 NPC 吧""再加个矿洞吧"） | 🔴 高 | 🔴 高 | 严格按 §7 推进；**3D 下加系统的成本是 2D 的 1.5 倍**；新想法一律写进 `ROADMAP.md` 的 v2 清单，不插队 |
| 3 | **作物生长阶段素材缺失** | 🔴 高 | 🟡 中 | **已预设方案**：`CropData` 支持"分阶段模型优先、缩放兜底"（§6.4）。首版用缩放，验证玩法后再逐个替换 |
| 4 | **3D 性能不达标**（阴影 + draw call 拖垮帧率） | 🟡 中 | 🟡 中 | M0 就把 Monitors/Profiler 看熟；用 `MultiMeshInstance3D` 合批、LOD、缩短阴影距离；**低多边形素材本身就不吃性能** |
| 5 | **GDScript 动态类型导致低级错误** | 🟡 中 | 🟡 中 | ① **全量类型标注**（§4.7）② 把 `UNTYPED_DECLARATION` / `UNSAFE_*` 警告设为 Error ③ 核心逻辑写 GUT 单测 |
| 6 | **3D 素材风格不统一**（混用多个包的素材） | 🟡 中 | 🟡 中 | 锁 **Kenney + Quaternius** 为基准；新素材必须先做"能否融入"评审；只从 CC0 大站取材 |
| 7 | **逻辑写进节点导致无法测试、难以重构** | 🟡 中 | 🟡 中 | 严守 §4.1 分层：规则放 L2 的 `RefCounted` 类，3D 节点只做表现。**这条在 3D 里比 2D 更重要**，因为 3D 手动验证成本高得多 |
| 8 | **存档格式改动导致老档损坏** | 🟡 中 | 🟡 中 | Day 1 就带 `version` 字段 + `SaveMigrator` 迁移链；每次改 `SaveModel` 都升版本号 |
| 9 | **透明材质排序错误**（树叶/水面互相穿插） | 🟡 中 | 🟢 低 | 能不用透明就不用；必须用时调 `render_priority` 或改 alpha-scissor（§5.7） |
| 10 | **将来想加 Web 版** | 🟢 低 | 🔴 高 | 3D + Web 需要把渲染器从 Forward+ 换到 Compatibility（**材质与光照要全部重调**）。**若这成为硬需求，必须现在就换，别等做完**——这是唯一一个"选错就要大面积返工"的决策（§2.4） |
| 11 | **LFS 未启用导致仓库膨胀** | 🟡 中 | 🟡 中 | 3D 素材过几十 MB 就开 LFS（§8.2）；协作者必须都装 git-lfs |
| 12 | **单人开发动力衰减**（3D 周期更长、正反馈更慢） | 🟡 中 | 🟡 中 | 每个里程碑产出一个"能玩"的包；**M1 就能看到太阳移动的画面**，这种即时视觉反馈在 3D 里比 2D 强得多，善用它 |

---

## 10. 附录

### 10.1 官方参考链接

| 资源 | 链接 |
| --- | --- |
| Godot 下载（Windows） | <https://godotengine.org/download/windows/> |
| Godot 官方文档（中文） | <https://docs.godotengine.org/zh-cn/4.x/> |
| **3D 入门：第一个 3D 场景** | <https://docs.godotengine.org/zh-cn/4.x/getting_started/first_3d_game/index.html> |
| **3D 渲染器对比（Forward+/Mobile/Compatibility）** | <https://docs.godotengine.org/zh-cn/4.x/tutorials/rendering/renderers.html> |
| **GridMap 使用指南** | <https://docs.godotengine.org/zh-cn/4.x/tutorials/3d/using_gridmaps.html> |
| **3D 导航与寻路（v2 用）** | <https://docs.godotengine.org/zh-cn/4.x/tutorials/navigation/navigation_introduction_3d.html> |
| **光照与阴影** | <https://docs.godotengine.org/zh-cn/4.x/tutorials/3d/lights_and_shadows.html> |
| 标准材质（PBR） | <https://docs.godotengine.org/zh-cn/4.x/tutorials/3d/standard_material_3d.html> |
| GDScript 风格指南 | <https://docs.godotengine.org/zh-cn/4.x/tutorials/scripting/gdscript/gdscript_styleguide.html> |
| GDScript 静态类型 | <https://docs.godotengine.org/zh-cn/4.x/tutorials/scripting/gdscript/static_typing.html> |
| GUT 单元测试 | <https://github.com/bitwes/Gut> ／ <https://gut.readthedocs.io/> |
| **Kenney 素材（CC0）** | <https://kenney.nl/assets> |
| **Quaternius 素材（CC0）** | <https://quaternius.com> |
| Poly Haven（HDRI / 材质，CC0） | <https://polyhaven.com> |
| ambientCG（PBR 材质，CC0） | <https://ambientcg.com> |
| Mixamo（免费自动绑骨 + 动画） | <https://www.mixamo.com> |

### 10.2 关键 API 速查（Godot 4.7 3D / GDScript）

| 需求 | 用这个 |
| --- | --- |
| 3D 根节点 | `Node3D`（每个 3D 节点都有 `Transform3D`） |
| 相机 | `Camera3D` —— 透视 `PROJECTION_PERSPECTIVE` / 正交 `PROJECTION_ORTHOGONAL` |
| 屏幕 → 世界射线 | `Camera3D.project_ray_origin()` / `project_ray_normal()` |
| 屏幕点 → 平面交点 | `Plane(Vector3.UP, y).intersects_ray(origin, normal)` |
| 射线查询物理体 | `get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(...))` |
| 角色移动 | `CharacterBody3D` + `move_and_slide()`（放 `_physics_process`） |
| 碰撞形状 | `CollisionShape3D` + `CapsuleShape3D`（人形首选） |
| 网格化关卡 | `GridMap` + `MeshLibrary`（`set_cell_item` / `map_to_local` / `local_to_map`） |
| 大量重复物件 | `MultiMeshInstance3D`（一次 draw call 画完全部） |
| 太阳 / 平行光 | `DirectionalLight3D` |
| 环境 / 天空 / 雾 | `WorldEnvironment` + `Environment` + `Sky` |
| 角色动画 | `AnimationPlayer` + `AnimationTree`（`AnimationNodeStateMachine` 做状态融合） |
| 寻路（v2） | `NavigationRegion3D` + `NavigationAgent3D` |
| 3D 物理引擎 | Project Settings → Physics → 3D → **Jolt**（4.6 起默认） |
| UI 拖拽 | `Control._get_drag_data` / `_can_drop_data` / `_drop_data` |
| 文件读写 | `FileAccess.open()`（`user://` 路径） |
| JSON | `JSON.stringify()` / `JSON.parse_string()` |
| 跨场景单例 | Project Settings → Globals → Autoload |
| 自定义信号 | `signal foo(a: int)` → `foo.emit(1)` / `foo.connect(cb)` |
| 延迟调用 | `await get_tree().create_timer(0.2).timeout` |
| 唯一名引用 | `%NodeName`（把节点标记为 "Access as Unique Name"） |

### 10.3 术语对照

| 中文 | 英文 | 说明 |
| --- | --- | --- |
| 核心循环 | Core Loop | 玩家重复进行的主要行为序列 |
| 纵向切片 | Vertical Slice | 各系统都做到可用程度的完整小样 |
| 固定斜俯视 | Fixed Oblique Top-Down | 相机固定角度俯视，仅允许水平旋转 |
| 数据驱动 | Data-driven | 用数据文件而非硬编码控制行为 |
| 单例 | Autoload / Singleton | 全局唯一、跨场景存在的对象 |
| 事件总线 | Event Bus | 系统间解耦通信的中枢 |
| 网格地图 | GridMap | 3D 版瓦片地图（网格 + MeshLibrary） |
| 网格库 | MeshLibrary | GridMap 可用的模型集合 |
| 导航网格 | Navigation Mesh | 供 AI 计算路径的可行走区域 |
| 骨骼动画 | Skeletal Animation | 通过骨骼驱动的模型动画 |
| 细节层次 | LOD | 按距离切换模型精度 |
| 遮挡剔除 | Occlusion Culling | 不渲染被挡住的物体 |
| 色调映射 | Tonemapping | 把 HDR 颜色映射到屏幕可显示范围 |
| 引用计数对象 | `RefCounted` | 不需手动释放的轻量类，适合纯逻辑 |

---

## 11. 待你决策的问题

1. **要不要现在就开始 M0？** —— 我可以把项目骨架一次性搭好并推到 `star-game`：
   - Godot 项目配置（**Forward+ 渲染器 + Jolt 物理 + MSAA**）
   - 完整目录结构（含 `assets/models/`、`scripts/world/`）
   - `.gitignore` / `.gitattributes`（含 LFS 配置）
   - Autoload 骨架（`EventBus` / `GameManager` / `TimeManager` / `SceneRouter`）
   - `CameraRig`（固定斜俯视）+ `Player`（相机相对移动）可跑通
   - `FarmGrid` 纯逻辑类 + 一套能跑通的 GUT 单元测试
   - 一张能跑起来的空农场场景（地面 + 天空 + 太阳）

2. **Kenney / Quaternius 素材要不要我先下好并整理进 `assets/`？** —— 我可以把 Nature Kit 等几个必需包下载、解压、按目录归类，并生成 `CREDITS.md`。这样 M1 一开工就有画面。

3. **要不要顺带把 v2 规划写进 `ROADMAP.md`？** —— 把 NPC / 钓鱼 / 矿洞拆成可追踪的条目，避免它们"悄悄插队"。

---

## 12. 变更记录

| 版本 | 日期 | 变更 |
| --- | --- | --- |
| v1.0 | 2026-10-07 | 初版，技术栈 Godot 4.7.2 (.NET) + C#，2D 像素 |
| v2.0 | 2026-10-07 | 技术栈改为 Godot 4.7.2 标准版 + GDScript，2D 像素 |
| **v3.0** | 2026-10-07 | **整体由 2D 像素改为 3D 低多边形 + 固定斜俯视**。渲染器锁定 Forward+（仅桌面）；确认 3D 物理默认 Jolt；首版范围收窄至核心农场闭环，NPC/钓鱼/矿洞移至 v2；全部美术方案改为 CC0 低多边形素材（授权红线消失）；新增 §3.3 相机与操作、§5.1 渲染管线、§5.2 3D 地形与土地、§5.3 玩家控制、§5.4 射线拾取、§5.5 光照与季节、§5.6 性能预算、§5.7 3D 特有坑；新增 §6.4 作物生长阶段素材对策；里程碑由 8 个重排为 6 个；代码骨架全部改为 3D（`CameraRig`/`Player`/`FarmView`/`SunController`）；`FarmGrid` 等 L2 领域层**保持不变** |

---

*文档结束 ｜ v3.0 ｜ 有任何一节想展开细化，随时说。*

