// pybind11 版 CModel —— phase 2b: 从 Python 调用的"换层"实现。
//
// 字段装 py::object(任意 Python 对象),因此必须完整复刻 Python 的 _changed 逻辑:
//   - 不可哈希(可变, type.__hash__ is None) -> 用 is(同一性)
//   - 可哈希(不可变)                      -> 用 !=(值相等),异常退回 is
// 这样行为与纯 Python 版一致,只是热路径跑在 C++ 里、每次写入/回调跨界。
//
// 支持 m.field = v 属性写入(走 C++ __setattr__),以便和纯 Python 版用同一个 harness 驱动。

#include <pybind11/pybind11.h>

#include <string>
#include <unordered_map>
#include <unordered_set>

namespace py = pybind11;

class CModel {
    std::unordered_map<std::string, py::object> fields_;
    std::unordered_map<std::string, std::unordered_map<std::string, py::object>> cbs_;
    std::unordered_set<std::string> firing_;

    bool changed(const py::object& old, const py::object& neu) {
        py::handle t = py::type::handle_of(neu);
        py::object h = py::getattr(t, "__hash__", py::none());
        if (h.is_none()) {
            return old.ptr() != neu.ptr();        // 可变 -> is not
        }
        try {
            return !old.equal(neu);               // 不可变 -> !=
        } catch (py::error_already_set&) {
            return old.ptr() != neu.ptr();        // __eq__ 抛异常 -> 退回 is
        }
    }

    void fire(const std::string& field) {
        auto it = cbs_.find(field);
        if (it == cbs_.end() || it->second.empty()) return;
        if (firing_.count(field)) return;         // 按字段防环
        firing_.insert(field);
        py::object self = py::cast(this);         // 回调签名 cb(oModel)
        for (auto& kv : it->second) {
            try {
                kv.second(self);
            } catch (py::error_already_set&) {    // 吞掉(日志省略,与 Python 版语义一致)
            }
        }
        firing_.erase(field);
    }

public:
    void setattr(const std::string& name, py::object value) {
        if (!name.empty() && name[0] == '_') {    // 内部: 直接存, 不 fire
            fields_[name] = std::move(value);
            return;
        }
        auto it = fields_.find(name);
        bool ch;
        if (it == fields_.end()) {
            fields_.emplace(name, value);
            ch = true;                            // 首次赋值算变更
        } else {
            ch = changed(it->second, value);
            if (ch) it->second = value;
        }
        if (ch) fire(name);
    }

    py::object getattr(const std::string& name) {
        auto it = fields_.find(name);
        if (it != fields_.end()) return it->second;
        throw py::attribute_error(name);
    }

    void SetModifyCB(const std::string& tag, const std::string& field, py::object cb) {
        cbs_[field][tag] = std::move(cb);
    }
};

PYBIND11_MODULE(cmodelpb, m) {
    py::class_<CModel>(m, "CModel")
        .def(py::init<>())
        .def("__setattr__", &CModel::setattr)
        .def("__getattr__", &CModel::getattr)
        .def("SetModifyCB", &CModel::SetModifyCB);
}
