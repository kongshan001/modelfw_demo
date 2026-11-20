#!/usr/bin/env bash
# 纸偶工坊一键验收：
#   启动无错误 / smoke / 真机截图 / Intel 帧率 / MP4+GIF 时长。
# 用法：bash tools/verify.sh
#      SKIP_GPU=1 bash tools/verify.sh   # 无显示器环境只跑 headless 部分
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$(mktemp -d)"
FAIL=0

cleanup() { rm -rf "$LOG_DIR"; }
trap cleanup EXIT

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }

echo "== 1/5 headless 启动（600 帧） =="
if "$GODOT_BIN" --path "$ROOT" --headless --quit-after 600 >"$LOG_DIR/headless.log" 2>&1; then
	if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:' "$LOG_DIR/headless.log"; then
		fail "headless 日志含脚本/解析错误"
		grep -E 'SCRIPT ERROR|Parse Error|^ERROR:' "$LOG_DIR/headless.log" | head -10
	else
		pass "无 SCRIPT ERROR / Parse Error"
	fi
else
	fail "headless 进程返回非零"
	tail -20 "$LOG_DIR/headless.log"
fi

echo "== 2/5 数据与渲染 smoke =="
if out=$("$GODOT_BIN" --path "$ROOT" --headless -s tools/smoke_paperdoll.gd 2>&1); then
	if echo "$out" | grep -q 'PAPERDOLL_SMOKE_OK'; then
		pass "$(echo "$out" | grep 'PAPERDOLL_SMOKE_OK' | tail -1)"
	else
		fail "smoke 未输出 PAPERDOLL_SMOKE_OK"
		echo "$out" | tail -20
	fi
else
	fail "smoke 返回非零"
	echo "$out" | tail -20
fi

if [ "${SKIP_GPU:-0}" = "1" ]; then
	echo "== 3/5 Intel 帧率（SKIP_GPU=1，跳过） =="
	echo "== 4/5 真机截图（SKIP_GPU=1，跳过） =="
else
	# 先测 FPS 再做截图：截图工具会创建 1280×720 SubViewport 并连续读回 7 张 PNG，
	# 退出后的 GPU/WindowServer 清理会污染紧随其后的帧率采样（T-010 实测 min 28–29）。
	echo "== 3/5 Intel 帧率（要求 min ≥30） =="
	if out=$("$GODOT_BIN" --path "$ROOT" --resolution 1280x720 -s tools/perf_paperdoll.gd 2>&1); then
		if echo "$out" | grep -q 'PAPERDOLL_FPS_OK'; then
			pass "$(echo "$out" | grep 'PAPERDOLL_FPS' | tail -2 | tr '\n' ' ')"
		else
			fail "帧率低于 30"
			echo "$out" | grep 'PAPERDOLL_FPS' | tail -3
		fi
	else
		fail "帧率工具返回非零（低于 30 或 GPU 不可用）"
		echo "$out" | grep 'PAPERDOLL_FPS' | tail -3
	fi

	echo "== 4/5 真机 1280x720 截图 =="
	if out=$("$GODOT_BIN" --path "$ROOT" --resolution 1280x720 -s tools/screenshot_paperdoll.gd 2>&1); then
		if echo "$out" | grep -q 'PAPERDOLL_SHOTS_OK'; then
			shots=$(find docs/shots -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')
			if [ "$shots" -ge 5 ]; then
				pass "PAPERDOLL_SHOTS_OK · ${shots} 张 PNG"
			else
				fail "截图只有 ${shots} 张（要求 ≥5）"
			fi
		else
			fail "截图工具未输出 PAPERDOLL_SHOTS_OK"
			echo "$out" | tail -20
		fi
	else
		fail "截图工具返回非零"
		echo "$out" | tail -20
	fi
fi

echo "== 5/5 媒体文件 =="
for file in docs/paperdoll.mp4 docs/paperdoll.gif; do
	if [ -s "$file" ]; then
		pass "存在 $file ($(du -h "$file" | cut -f1))"
	else
		fail "缺少 $file（可运行 tools/record_paperdoll.sh）"
	fi
done

if command -v ffprobe >/dev/null 2>&1; then
	for file in docs/paperdoll.mp4 docs/paperdoll.gif; do
		[ -s "$file" ] || continue
		dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file")
		if awk -v d="$dur" 'BEGIN { exit !(d >= 6.0 && d <= 10.0) }'; then
			pass "$file 时长 ${dur}s（6–10s）"
		else
			fail "$file 时长 ${dur}s 不在 6–10s"
		fi
	done
else
	echo "  SKIP ffprobe 不可用，未校验视频时长"
fi

echo
if [ "$FAIL" -eq 0 ]; then
	echo "PAPERDOLL_VERIFY_OK"
	exit 0
fi
echo "PAPERDOLL_VERIFY_FAILED"
exit 1
