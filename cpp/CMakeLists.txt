cmake_minimum_required(VERSION 3.14)
project(cmodel_bench CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 性能基准必须用优化构建
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# 苹果 clang: Release 默认 -O2; 显式加 -O3 让上限更干净
add_compile_options($<$<CXX_COMPILER_ID:AppleClang,Clang,GNU>:-O3>)

add_executable(bench_native bench_native.cpp)

# pybind11 扩展模块 cmodelpb(从 Python import)
find_package(pybind11 3.0 CONFIG REQUIRED)
pybind11_add_module(cmodelpb cmodel_pybind.cpp)

