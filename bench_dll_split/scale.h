// 被「被测方」: scale.c 同时编译进 mono 可执行文件与 libsplit.dylib
#pragma once
#include "common.h"

API double scale(double x);        // 极小的数学函数(高频调用的典型)
API double get(double i);          // 细粒度 accessor
API double bulk_sum(const double* a, uint64_t n);  // 粗粒度: 一次跨界做整件事
