// CModel<T> —— 纯原生 C++ 版,用于性能上限对照 (Q5: 模板 + 习惯用法等价保真)。
//
// 与 Python 版的关系:
//   - 复刻热路径语义:字段写入 -> 变更检测 -> fire 该字段的回调;按字段防环;回调异常吞掉。
//   - 丢弃 Python 仅为动态类型而做的簿记(无 type-hash 分支、无 _declared 集、无未声明警告)。
//   - _changed 统一用值相等 (!=):C++ 值语义没有 Python "同一对象原地改" 的概念,无需 is 分支。
#pragma once

#include <functional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

template <typename T>
class CModel {
public:
    using Callback = std::function<void(CModel<T>&)>;

    // 字段写入(等价 Python 的 __setattr__)
    void set(const std::string& field, const T& value) {
        auto it = fields_.find(field);
        bool changed;
        if (it == fields_.end()) {
            fields_.emplace(field, value);
            changed = true;                 // 首次赋值算变更
        } else {
            changed = !(it->second == value);   // _changed: 值不等才算变更
            if (changed) it->second = value;
        }
        if (changed) fire(field);
    }

    const T& get(const std::string& field) const { return fields_.at(field); }

    // 注册回调: {field: {tag: cb}}。同 (tag, field) 覆盖(原生 bench 省略警告)。
    void SetModifyCB(const std::string& tag, const std::string& field, Callback cb) {
        callbacks_[field][tag] = std::move(cb);
    }

private:
    std::unordered_map<std::string, T> fields_;
    std::unordered_map<std::string, std::unordered_map<std::string, Callback>> callbacks_;
    std::unordered_set<std::string> firing_;   // 按字段防环

    void fire(const std::string& field) {
        auto it = callbacks_.find(field);
        if (it == callbacks_.end() || it->second.empty()) return;
        if (firing_.count(field)) return;       // 防环:已在自身回调链 -> 中断
        firing_.insert(field);
        for (auto& kv : it->second) {
            try { kv.second(*this); }            // 回调签名: cb(CModel<T>&)
            catch (...) { /* 吞掉(原生 bench 无 logger,堆栈日志省略)*/ }
        }
        firing_.erase(field);
    }
};
