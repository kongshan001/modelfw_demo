# bench_dll_split —— 用可复现数据验证「拆成多个 DLL 性能下降」的论点。
# macOS 上以 dylib 等价演示(GOT/PLT 间接调用、无跨界内联、LTO 边界、独立代码映射);
# 同一份 C 源码在 Windows 用 MSVC/MinGW 产出真正的 .dll, 机制一一对应(IAT/LTCG)。
#
#   用法: make run    (构建 + 跑全部用例, 输出 markdown 表格)
#         make clean
CC      ?= clang
CFLAGS  := -O2 -Wall -Wextra -I.
BUILD   := build
DYLIB   := -dynamiclib -fvisibility=hidden -Wl,-install_name,@rpath/libsplit.dylib
THIN    := $(foreach i,0 1 2 3 4 5 6 7 8 9,$(BUILD)/libthin$(i).dylib)
GEN_DYLIBS := $(BUILD)/libfat.dylib $(BUILD)/libcold.dylib $(THIN)
GEN_SRCS   := $(GEN_DYLIBS:.dylib=.c)

# 生成源由 gen.py 一次性产出(build/*.c): 空规则让 make 能把缺失的 .c 解析掉
# (目标失期时先跑 gen 补源)。不加这条, 首编 / make -j 会因 .c 无规则而报错。
$(GEN_SRCS): gen
	@:

.PHONY: all run gen clean

all: $(BUILD)/libsplit.dylib $(BUILD)/bench_O2 $(BUILD)/bench_LTO $(GEN_DYLIBS)

gen:
	python3 gen.py

# 生成的测试 dylib(fat/thin/cold): -O1 保代码体积; gen.py 作普通前置:
# gen.py 改动 → dylib 失期 → 重跑 gen 刷新源 → 自动重链(幂等 gen 内容不变则
# 源 mtime 不动, 但 gen.py 变更本身即触发重链)。生成源 %.c 是 order-only:
# 只在 dylib 失期时补跑 gen, 不参与日常新鲜度判断, 无改动时 make 保持静默。
$(GEN_DYLIBS): %.dylib: gen.py | gen %.c
	$(CC) -O1 $(DYLIB) -o $@ $(patsubst %.dylib,%.c,$@)

# 被测 dylib: 两端都 -flto —— 专门证明「LTO 跨不过模块边界」
$(BUILD)/libsplit.dylib: libsplit.c
	$(CC) -O2 -flto -Wall -Wextra $(DYLIB) -o $@ $<

# -O2 形态: M1 内联 / M2 直接调用 / S1 PLT / S2-S4 / CF / LD
# | libsplit.dylib: 只排序不触发 —— 链接需要它先存在, 但 dylib 变更不该重链 bench
# (运行期动态加载)。缺这条时 make -j 干净构建会竞态: bench 先于 libsplit 链接失败。
$(BUILD)/bench_O2: bench.c | $(BUILD)/libsplit.dylib
	$(CC) -O2 $(CFLAGS) -o $@ $< -L$(BUILD) -lsplit -Wl,-rpath,@executable_path

# -flto 形态: 增加 M3(跨TU LTO 内联), 与 S1 对照 → LTO 边界
$(BUILD)/bench_LTO: bench.c scale_lto.c | $(BUILD)/libsplit.dylib
	$(CC) -O2 -flto $(CFLAGS) -DLTO_FLAVOR -o $@ $^ -L$(BUILD) -lsplit -Wl,-rpath,@executable_path

run: all
	@echo "===== bench_O2 ====="
	@$(BUILD)/bench_O2
	@echo ""
	@echo "===== bench_LTO (M3: LTO 跨TU 内联; S1 复测) ====="
	@$(BUILD)/bench_LTO

clean:
	rm -rf $(BUILD)
