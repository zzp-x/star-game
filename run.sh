#!/usr/bin/env bash
# ===========================================================
#  Star Game · 一键运行（macOS / Linux）
#
#  用法：
#      ./run.sh                    运行游戏
#      ./run.sh editor             打开 Godot 编辑器
#      ./run.sh test               跑单元 + 集成测试
#      ./run.sh check              导入检查 + 测试
#      ./run.sh import             只导入资源
#      ./run.sh where              只显示定位到的 Godot 路径
#      ./run.sh play --headless    额外参数原样透传给 Godot
#
#  查找 Godot 的顺序（先命中者优先）：
#      1. 环境变量 SG_GODOT
#      2. 仓库根目录的 .godot-path 文件（里面写一行绝对路径）
#      3. PATH 里的 godot / godot4
#      4. /Applications/Godot.app/... 及常见安装目录
#
#  找不到时请从官网下载 Godot 4.7.2 标准版（不要 .NET 版）：
#      https://godotengine.org/download/
# ===========================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$PROJECT_ROOT/project.godot"
IMPORT_MARKER="$PROJECT_ROOT/.godot/global_script_class_cache.cfg"
PIN_FILE="$PROJECT_ROOT/.godot-path"

# ── 颜色（非终端环境自动关闭）────────────────────────────
if [ -t 1 ]; then
	C_HEAD=$'\033[36m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'
	C_FAIL=$'\033[31m'; C_DIM=$'\033[90m'; C_OFF=$'\033[0m'
else
	C_HEAD=''; C_OK=''; C_WARN=''; C_FAIL=''; C_DIM=''; C_OFF=''
fi

head_() { printf '%s\n' "${C_HEAD}$*${C_OFF}"; }
ok_()   { printf '%s\n' "${C_OK}$*${C_OFF}"; }
warn_() { printf '%s\n' "${C_WARN}$*${C_OFF}"; }
fail_() { printf '%s\n' "${C_FAIL}$*${C_OFF}" >&2; }
dim_()  { printf '%s\n' "${C_DIM}$*${C_OFF}"; }
rule()  { printf '%s\n' "${C_DIM}──────────────────────────────────────────────────────────${C_OFF}"; }

# ── 解析动作 ─────────────────────────────────────────────
ACTION="play"
case "${1:-}" in
	play | editor | test | import | check | where)
		ACTION="$1"
		shift
		;;
esac
# 剩余参数原样透传给 Godot（有意保留词分割）
EXTRA_ARGS="$*"

# ── 定位 Godot ───────────────────────────────────────────
find_godot() {
	if [ -n "${SG_GODOT:-}" ] && [ -x "${SG_GODOT}" ]; then
		printf '%s\n' "$SG_GODOT"
		return 0
	fi

	if [ -f "$PIN_FILE" ]; then
		pin=$(head -n 1 "$PIN_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
		case "$pin" in
			'' | '#'*) ;;
			*)
				case "$pin" in
					/*) ;;
					*) pin="$PROJECT_ROOT/$pin" ;;
				esac
				if [ -x "$pin" ]; then
					printf '%s\n' "$pin"
					return 0
				fi
				warn_ ".godot-path 里的路径不可执行，已忽略：$pin"
				;;
		esac
	fi

	for cmd in godot godot4 Godot; do
		if found=$(command -v "$cmd" 2>/dev/null); then
			printf '%s\n' "$found"
			return 0
		fi
	done

	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"/usr/local/bin/godot" \
		"/opt/homebrew/bin/godot" \
		"/usr/bin/godot" \
		"$HOME/Godot"/Godot_v* \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Downloads"/Godot_v*; do
		if [ -x "$candidate" ]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

# ════════════════════════════════════════════════════════
rule
head_ '  Star Game · Godot 启动器'
rule

if [ ! -f "$PROJECT_FILE" ]; then
	fail_ "当前目录看起来不是 Godot 项目（找不到 project.godot）："
	fail_ "  $PROJECT_ROOT"
	exit 2
fi

if ! GODOT="$(find_godot)"; then
	fail_ '没有在本机找到 Godot。'
	echo
	dim_ '请从官网下载「Godot Engine」标准版（不要下 .NET 版，本项目用不到）：'
	dim_ '  https://godotengine.org/download/'
	echo
	dim_ '下载解压后，任意一种方式告诉脚本它在哪：'
	dim_ '  a) 把可执行文件放进 PATH'
	dim_ '  b) export SG_GODOT=/完整/路径/Godot'
	dim_ '  c) 在仓库根目录建 .godot-path 文件，写一行可执行文件绝对路径'
	exit 1
fi

GODOT_VERSION="$("$GODOT" --version 2>/dev/null | head -n 1 || echo '未知')"
printf '引擎：%s\n' "$GODOT"
printf '版本：%s\n' "$GODOT_VERSION"

if [ "$ACTION" = "where" ]; then
	ok_ 'Godot 定位正常。'
	exit 0
fi

# ── 首次运行自动导入 ─────────────────────────────────────
if [ ! -f "$IMPORT_MARKER" ] && [ "$ACTION" != "editor" ]; then
	warn_ '检测到项目尚未导入（全新克隆后首次运行）'
	dim_ '正在导入资源，约 10～40 秒…'
	"$GODOT" --headless --path "$PROJECT_ROOT" --import >/dev/null 2>&1 || true
	if [ -f "$IMPORT_MARKER" ]; then ok_ '资源导入完成'; else warn_ '导入未生成标记文件，继续尝试启动'; fi
	echo
fi

# ── 组装参数 ─────────────────────────────────────────────
case "$ACTION" in
	play)   ARGS="--path \"$PROJECT_ROOT\"" ;;
	editor) ARGS="-e --path \"$PROJECT_ROOT\"" ;;
	import) ARGS="--headless --path \"$PROJECT_ROOT\" --import" ;;
	test)   ARGS="--headless --path \"$PROJECT_ROOT\" -s addons/gut/gut_cmdln.gd -gexit" ;;
	check)  ARGS="--headless --path \"$PROJECT_ROOT\" -s addons/gut/gut_cmdln.gd -gexit" ;;
	*)      ARGS="--path \"$PROJECT_ROOT\"" ;;
esac

if [ "$ACTION" = "check" ]; then
	dim_ '① 导入 / 解析检查…'
	"$GODOT" --headless --path "$PROJECT_ROOT" --import >/dev/null 2>&1 || true
	ok_ '   完成'
	echo
	dim_ '② 单元 + 集成测试…'
fi

dim_ "启动：godot $ARGS $EXTRA_ARGS"
rule

# shellcheck disable=SC2086  # 有意做词分割，以便把参数逐个传给 Godot
set +e
eval "\"\$GODOT\" $ARGS $EXTRA_ARGS"
RC=$?
set -e

rule
case "$ACTION" in
	test | check)
		if [ "$RC" -eq 0 ]; then ok_ '✔ 测试全部通过'; else fail_ "✘ 测试失败（退出码 $RC）"; fi
		;;
	play)
		if [ "$RC" -eq 0 ]; then ok_ '游戏已退出（正常）'; else fail_ "游戏异常退出（退出码 $RC）"; fi
		;;
	editor)
		if [ "$RC" -eq 0 ]; then ok_ '编辑器已关闭'; else fail_ "编辑器异常退出（退出码 $RC）"; fi
		;;
esac

if [ "$ACTION" = "play" ]; then
	echo
	dim_ '操作提示：左键点草地翻地 → 再点播种 → 再点浇水 → F10 过夜（重复 4 次收芜菁）'
	dim_ '          Q/E 转视角 · 滚轮缩放 · 1-5 换种子 · F5 存档 · F9 读档'
fi

exit "$RC"
