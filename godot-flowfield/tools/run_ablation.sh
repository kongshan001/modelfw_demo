#!/bin/bash
# 审计级消融复测入口：1280×720 真实窗口（1000 + 500 + 图层归因）+ 1920×1080 离屏。
# 运行：bash tools/run_ablation.sh
# 产物：docs/perf/ablation_*.csv、runs_raw.json、bench_*.log、env_log.txt
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs/perf

{
	echo "=== env before $(date '+%Y-%m-%d %H:%M:%S') ==="
	sw_vers
	echo "CPU: $(sysctl -n machdep.cpu.brand_string)"
	echo "logical_cpus: $(sysctl -n hw.ncpu)"
	echo "loadavg: $(sysctl -n vm.loadavg)"
	pmset -g therm
	echo
} | tee docs/perf/env_log.txt

# 冷启动前让上一轮编译/索引/热负载沉一会儿；轮次之间也留冷却，减小热漂移。
sleep 15

# 1280×720：真实窗口，1000 全矩阵 + 500 对照 + 图层归因。
caffeinate -dimsu godot --path . --resolution 1280x720 -s tools/bench_ablation.gd -- \
	--tag 1280x720 --viewport window --agents 1000,500 --runs 5 --layers 2>&1 \
	| tee docs/perf/bench_1280x720.log

sleep 20

# 1920×1080：本机屏幕 1440×900，macOS 会夹窗口；用离屏 SubViewport 全分辨率渲染。
caffeinate -dimsu godot --path . --resolution 1280x720 -s tools/bench_ablation.gd -- \
	--tag 1920x1080 --viewport sub --agents 1000 --runs 5 2>&1 \
	| tee docs/perf/bench_1920x1080.log

{
	echo "=== env after $(date '+%Y-%m-%d %H:%M:%S') ==="
	echo "loadavg: $(sysctl -n vm.loadavg)"
	pmset -g therm
	echo
} | tee -a docs/perf/env_log.txt
