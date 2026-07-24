// pybind11 版 CModel —— C++ 核心, 配 cmodel_fast.py 薄壳组成 Python 版的完整平替。
//
// 字段装 py::object, 完整复刻 Python cmodel.py 的全部语义(8 条决策):
//   - _changed: 不可哈希(可变) -> is; 可哈希(不可变) -> !=, 异常退回 is
//   - _ 前缀内部属性不触发; 未声明字段(在 _declared 就位后)赋值警告
//   - 回调注册表 {field: [(tag, cb), ...]} 用 vector 保插入顺序(与 Python dict 一致),
//     同 (tag, field) 覆盖警告
//   - ClearModifyCB 四向清理 / NotifyChange 强制触发
//   - 按字段防环; 回调异常吞掉并用 logging 带 exc_info 堆栈日志
//   - __init_subclass__ 快照由 Python 薄壳负责; 这里提供 _field_names() 供快照,
//     并拦截 self._declared 赋值填充 C++ declared_ 集供热路径快速查未声明。

#include <pybind11/pybind11.h>

#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace py = pybind11;

class CModel {
    using CbList = std::vector<std::pair<std::string, py::object>>;
    std::unordered_map<std::string, py::object> fields_;
    std::unordered_map<std::string, CbList> cbs_;   // 保插入顺序
    std::unordered_set<std::string> firing_;
    std::unordered_set<std::string> declared_;
    bool declared_set_ = false;

    static void warn(const std::string& msg) {
        py::module_::import("warnings").attr("warn")(msg, py::arg("stacklevel") = 2);
    }

    static void erase_tag(CbList& vec, const std::string& tag) {
        for (auto it = vec.begin(); it != vec.end(); ++it) {
            if (it->first == tag) { vec.erase(it); return; }
        }
    }

    // 把当前 Python 异常取出三元组, 用 exc_info 显式交给 logger.error(带完整堆栈)。
    // 必须显式传: 从 C++ 调 logger.exception 时不在 Python except 帧里, sys.exc_info() 为空。
    static void log_cb_error(const std::string& field, const std::string& tag) {
        PyObject* t = nullptr;
        PyObject* v = nullptr;
        PyObject* tb = nullptr;
        PyErr_Fetch(&t, &v, &tb);                  // 取走并清空当前异常
        auto wrap = [](PyObject* o) -> py::object {
            return o ? py::reinterpret_borrow<py::object>(o) : py::none();
        };
        py::tuple exc_info = py::make_tuple(wrap(t), wrap(v), wrap(tb));
        try {
            py::module_::import("logging")
                .attr("getLogger")("cmodel")
                .attr("error")("CModel: callback error on field '%s' tag '%s'",
                               field, tag, py::arg("exc_info") = exc_info);
        } catch (py::error_already_set&) {
            PyErr_Clear();
        }
        Py_XDECREF(t);
        Py_XDECREF(v);
        Py_XDECREF(tb);
    }

    bool changed(const py::object& old, const py::object& neu) {
        py::handle t = py::type::handle_of(neu);
        py::object h = py::getattr(t, "__hash__", py::none());
        if (h.is_none()) {
            return old.ptr() != neu.ptr();            // 可变 -> is not
        }
        try {
            return !old.equal(neu);                   // 不可变 -> !=
        } catch (py::error_already_set&) {
            return old.ptr() != neu.ptr();
        }
    }

    void fire(const std::string& field) {
        auto it = cbs_.find(field);
        if (it == cbs_.end() || it->second.empty()) return;
        if (firing_.count(field)) {                   // 按字段防环
            warn("CModel: loop detected on field '" + field + "', break callback chain");
            return;
        }
        firing_.insert(field);
        py::object self = py::cast(this);             // 回调签名 cb(oModel)
        CbList& vec = it->second;
        for (auto& kv : vec) {
            try {
                kv.second(self);
            } catch (py::error_already_set& e) {      // 吞掉 + 带堆栈日志
                e.restore();                          // 把异常放回 PyErr, 供 PyErr_Fetch 取
                log_cb_error(field, kv.first);
            }
        }
        firing_.erase(field);
    }

    // 单次写入的核心逻辑(setattr 与 set_many 共用)。
    void set_impl(const std::string& name, py::object value) {
        if (name == "_declared") {                    // 拦截: 填 C++ declared_ 集
            declared_.clear();
            for (py::handle h : value) declared_.insert(h.cast<std::string>());
            declared_set_ = true;
            return;
        }
        if (!name.empty() && name[0] == '_') {        // 内部: 直接存, 不 fire
            fields_[name] = std::move(value);
            return;
        }
        if (declared_set_ && !declared_.count(name)) {  // 未声明警告
            warn("CModel: field '" + name + "' not declared in __init__, assigning dynamically");
        }
        auto it = fields_.find(name);
        bool ch;
        if (it == fields_.end()) {
            fields_.emplace(name, value);
            ch = true;                                // 首次赋值算变更
        } else {
            ch = changed(it->second, value);
            if (ch) it->second = value;
        }
        if (ch) fire(name);
    }

public:
    void setattr(const std::string& name, py::object value) {
        set_impl(name, std::move(value));
    }

    // 批量写入: N 次写入只 1 次 Python->C++ 跨界(循环在 C++ 内)。
    // 无回调(W1)时几乎贴近 native; 有 Python 回调(W2)时回调跨界仍在, 收益受限。
    void set_many(const std::string& field, py::list values) {
        for (py::handle h : values) {
            set_impl(field, py::reinterpret_borrow<py::object>(h));
        }
    }

    py::object getattr(const std::string& name) {
        if (name == "_declared") {                    // 暴露为 frozenset, 与 Python 版一致
            py::list l;
            for (const auto& s : declared_) l.append(py::str(s));
            return py::frozenset(l);
        }
        auto it = fields_.find(name);
        if (it != fields_.end()) return it->second;
        throw py::attribute_error(name);
    }

    void SetModifyCB(const std::string& tag, const std::string& field, py::object cb) {
        CbList& vec = cbs_[field];
        for (auto& p : vec) {
            if (p.first == tag) {
                warn("CModel: overwrite callback for field '" + field + "' tag '" + tag + "'");
                p.second = std::move(cb);
                return;
            }
        }
        vec.emplace_back(tag, std::move(cb));
    }

    void ClearModifyCB(py::object tag, py::object field) {
        bool has_tag = !tag.is_none(), has_field = !field.is_none();
        if (has_field && has_tag) {
            auto it = cbs_.find(field.cast<std::string>());
            if (it != cbs_.end()) erase_tag(it->second, tag.cast<std::string>());
        } else if (has_field) {
            cbs_.erase(field.cast<std::string>());
        } else if (has_tag) {
            std::string t = tag.cast<std::string>();
            for (auto& kv : cbs_) erase_tag(kv.second, t);
        } else {
            cbs_.clear();
        }
    }

    void NotifyChange(const std::string& field) { fire(field); }

    py::list _field_names() {
        py::list l;
        for (const auto& kv : fields_)
            if (!kv.first.empty() && kv.first[0] != '_') l.append(py::str(kv.first));
        return l;
    }
};

PYBIND11_MODULE(cmodelpb, m) {
    py::class_<CModel>(m, "CModel")
        .def(py::init<>())
        .def("__setattr__", &CModel::setattr)
        .def("__getattr__", &CModel::getattr)
        .def("SetModifyCB", &CModel::SetModifyCB)
        .def("ClearModifyCB", &CModel::ClearModifyCB,
             py::arg("tag") = py::none(), py::arg("field") = py::none())
        .def("NotifyChange", &CModel::NotifyChange)
        .def("set_many", &CModel::set_many)
        .def("_field_names", &CModel::_field_names);
}
