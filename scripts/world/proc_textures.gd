class_name ProcTextures
extends RefCounted
## 程序化生成的贴图（零外部素材）。
##
## 【层级】L4 表现层 —— 只产出「画什么」，不含任何游戏规则。
##
## 【为什么用程序化而不是贴图文件】
##   1. 纪律：M0/M1 要保证「克隆下来就能跑」，不引入任何美术资源依赖
##   2. 附带好处：参数化了就能几秒钟换一套配色，试风格极快
## 【M2 会替换】届时把调用点改成 load("res://assets/...") 即可，接口不变。

## 生成一张可平铺的草地贴图。
##
## 【为什么要"可平铺"】地面是 200×200 的大平面，贴图靠 UV 重复铺满。
## 如果边缘不接续，成品会出现一条条明显的重复接缝。
## 做法是画斑点时对坐标取模（见 _speckle），越界的部分自动绕回另一边。
static func grass_tile(size: int = 96, rng_seed: int = 20261007) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed

	var img: Image = Image.create_empty(size, size, true, Image.FORMAT_RGBA8)
	# 底色：偏黄绿的草地，比纯绿更耐看、也更像"有点枯"的农场
	img.fill(Color(0.36, 0.52, 0.26, 1.0))

	# 大块色斑：制造"深浅不均"的观感，避免整片死板
	var patch_colors: Array[Color] = [
		Color(0.31, 0.46, 0.22, 1.0),
		Color(0.42, 0.58, 0.30, 1.0),
		Color(0.38, 0.55, 0.24, 1.0),
	]
	for _i: int in 26:
		var c: Color = patch_colors[rng.randi_range(0, patch_colors.size() - 1)]
		_speckle(img, rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), rng.randi_range(6, 13), c, 0.30)

	# 细碎草粒：近距离看才不会是一块平滑的色板
	for _i: int in 320:
		var light: bool = rng.randf() > 0.5
		var c: Color = Color(0.46, 0.63, 0.33, 1.0) if light else Color(0.27, 0.40, 0.19, 1.0)
		_speckle(img, rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), rng.randi_range(0, 1), c, 0.45)

	return ImageTexture.create_from_image(img)


## 生成农田范围的网格覆盖贴图（透明背景，只有线）。
##
## 【为什么需要】农田是 16×16 格，但地面是一整片草地 ——
## 玩家根本看不出「哪儿能种」。这块网格就是可耕作范围的视觉边界。
## 【为什么网格线是对称的】这样就不用关心 PlaneMesh 的 UV 朝向，
## 转 90° 也不会错位。
static func field_grid(cells: int, px_per_cell: int, line_px: int = 3) -> ImageTexture:
	var size: int = cells * px_per_cell
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var line: Color = Color(0.13, 0.19, 0.10, 0.28)
	var edge: Color = Color(0.23, 0.15, 0.07, 0.55)

	# 内部网格线。线宽给到 3 像素：贴图会被 mipmap 逐级降采样，
	# 1 像素的线在稍远处会整条糊掉。
	for i: int in range(cells + 1):
		var p: int = mini(i * px_per_cell, size - 1)
		for t: int in line_px:
			var q: int = mini(p + t, size - 1)
			for k: int in size:
				img.set_pixel(q, k, line)
				img.set_pixel(k, q, line)

	# 外圈加粗：一眼看出田地边界
	var w: int = 5
	for k: int in size:
		for t: int in w:
			img.set_pixel(t, k, edge)
			img.set_pixel(size - 1 - t, k, edge)
			img.set_pixel(k, t, edge)
			img.set_pixel(k, size - 1 - t, edge)

	return ImageTexture.create_from_image(img)


# ── 绘制小工具 ───────────────────────────────────────────

## 画一个带"环绕"的实心圆点。坐标越界时绕到另一侧 —— 这是可平铺的关键。
static func _speckle(img: Image, cx: int, cy: int, radius: int, color: Color, alpha: float) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + radius:
				continue
			var x: int = ((cx + dx) % w + w) % w
			var y: int = ((cy + dy) % h + h) % h
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(color, alpha))
