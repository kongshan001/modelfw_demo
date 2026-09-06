# CModel harness 一键链路: build -> test / bench -> verify
# 退出码即门禁: make verify 全绿 = 构建可复现 + 回归通过 + 性能达标。
PYTHON ?= python3

.PHONY: build test bench bench-ci verify clean

build:
	cd cpp && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
		-Dpybind11_DIR=$$($(PYTHON) -m pybind11 --cmakedir) \
		&& cmake --build build -j

test: build
	$(PYTHON) -c "import cmodel_fast"   # 冒烟: 早期暴露 cpython-* 产物不匹配
	$(PYTHON) -m pytest

bench: build
	$(PYTHON) -c "import cmodel_fast"
	$(PYTHON) benchmark.py
	$(PYTHON) compare.py --check --json bench_results/latest.json

# CI 专用: 只断言不写快照(CI 机器数据不入本地趋势线)
bench-ci: build
	$(PYTHON) -c "import cmodel_fast"
	$(PYTHON) benchmark.py
	$(PYTHON) compare.py --check

verify: test bench

clean:
	rm -rf cpp/build .pytest_cache __pycache__
