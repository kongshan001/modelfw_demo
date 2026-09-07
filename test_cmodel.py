"""CModel 回归测试 —— 同一套用例对【纯 Python】与【C++ 平替】两实现各跑一遍, 证明平替。

运行: python3 -m pytest test_cmodel.py -v
"""

import logging
import warnings

import pytest


@pytest.fixture(params=["py", "cpp"])
def ModelCls(request):
    """参数化模型基类: py=纯 Python cmodel.PyCModel, cpp=C++ 平替 cmodel_fast.CModel。"""
    if request.param == "py":
        from cmodel import PyCModel as Base      # 显式纯 Python, 不受无感替换影响
    else:
        from cmodel_fast import CModel as Base

    class UserModel(Base):
        def __init__(self):
            super().__init__()
            self.sName = ""
            self.nAge = 0
            self.lstTags = []      # 可变字段
            self.sUpper = ""       # 连锁用

    return UserModel


@pytest.fixture(autouse=True)
def _warn_always():
    """所有 UserWarning 都触发, 不被默认 'default' 过滤器按代码位置去重。"""
    with warnings.catch_warnings():
        warnings.simplefilter("always")
        yield


# ---------------------------------------------------------------------- #
#  决策 3 / 4:赋值触发 cb(oModel);值相等不触发
# ---------------------------------------------------------------------- #
def test_change_fires_callback_receiving_model(ModelCls):
    received = []
    m = ModelCls()
    m.SetModifyCB("t", "sName", lambda mm: received.append(mm))
    m.sName = "test"
    assert received == [m]                       # 签名 cb(oModel): 收到 model 本身


def test_no_fire_when_immutable_value_unchanged(ModelCls):
    fired = []
    m = ModelCls()
    m.sName = "init"
    m.SetModifyCB("t", "sName", lambda mm: fired.append(1))
    m.sName = "init"                             # 不可变、同值 -> 不触发
    assert fired == []


def test_fire_when_value_actually_changes(ModelCls):
    fired = []
    m = ModelCls()
    m.SetModifyCB("t", "sName", lambda mm: fired.append(mm.sName))
    m.sName = "a"
    m.sName = "b"
    assert fired == ["a", "b"]


# ---------------------------------------------------------------------- #
#  决策 4:可变类型用 is
# ---------------------------------------------------------------------- #
def test_mutable_reassign_same_object_does_not_fire(ModelCls):
    fired = []
    m = ModelCls()
    m.SetModifyCB("t", "lstTags", lambda mm: fired.append(1))
    m.lstTags = m.lstTags                        # 同一对象(is)-> 不算变更
    assert fired == []


def test_mutable_reassign_new_object_fires_even_if_equal(ModelCls):
    fired = []
    m = ModelCls()
    m.SetModifyCB("t", "lstTags", lambda mm: fired.append(1))
    m.lstTags = []                               # 新 list 对象, 内容相等 -> 仍 fire(is)
    assert fired == [1]


def test_mutable_inplace_mutation_then_notifychange(ModelCls):
    fired = []
    m = ModelCls()
    m.lstTags = ["a"]
    m.SetModifyCB("t", "lstTags", lambda mm: fired.append(list(mm.lstTags)))
    m.lstTags.append("b")                        # 原地改 -> 盲区, 不触发
    assert fired == []
    m.NotifyChange("lstTags")                    # 手动补刀
    assert fired == [["a", "b"]]


# ---------------------------------------------------------------------- #
#  决策 2:注册表 / 覆盖警告 / 多 tag
# ---------------------------------------------------------------------- #
def test_setmodifycb_overwrite_warns_and_replaces(ModelCls):
    m = ModelCls()
    calls = []
    m.SetModifyCB("t", "sName", lambda mm: calls.append("first"))
    with pytest.warns(UserWarning, match="overwrite"):
        m.SetModifyCB("t", "sName", lambda mm: calls.append("second"))
    m.sName = "x"                                # 覆盖后只有 second 生效
    assert calls == ["second"]


def test_multiple_tags_on_same_field_all_fire(ModelCls):
    fired = []
    m = ModelCls()
    m.SetModifyCB("t1", "sName", lambda mm: fired.append("t1"))
    m.SetModifyCB("t2", "sName", lambda mm: fired.append("t2"))
    m.sName = "x"
    assert fired == ["t1", "t2"]


# ---------------------------------------------------------------------- #
#  决策 7:未声明字段警告;已声明不警告
# ---------------------------------------------------------------------- #
def test_undeclared_field_warns_but_still_works(ModelCls):
    m = ModelCls()
    with pytest.warns(UserWarning, match="not declared"):
        m.sExtra = "x"
    assert m.sExtra == "x"


def test_declared_field_does_not_warn(ModelCls, recwarn):
    m = ModelCls()
    m.sName = "hello"                            # 已声明 -> 无警告
    assert [str(w.message) for w in recwarn.list] == []


# ---------------------------------------------------------------------- #
#  决策 5:连锁 + 按字段防环
# ---------------------------------------------------------------------- #
def test_chaining_fires_other_field(ModelCls):
    m = ModelCls()
    m.SetModifyCB("chain", "sName",
                  lambda mm: setattr(mm, "sUpper", mm.sName.upper()))
    fired = []
    m.SetModifyCB("upper", "sUpper", lambda mm: fired.append(mm.sUpper))
    m.sName = "abc"
    assert m.sUpper == "ABC"
    assert fired == ["ABC"]


def test_loop_protection_breaks_cycle(ModelCls):
    calls = []
    m = ModelCls()

    def loop_cb(mm):
        calls.append(1)
        mm.sName = mm.sName + "x"                # 再次触发 sName 自身回调 -> 环

    m.SetModifyCB("loop", "sName", loop_cb)
    with pytest.warns(UserWarning, match="loop detected"):
        m.sName = "a"
    assert calls == [1]                          # 没有无限递归


# ---------------------------------------------------------------------- #
#  决策 2 续:回调期内修改注册表(防回归)
#
#  修复前 CModel 3/3 SIGSEGV: C++ fire() 直接以引用迭代回调表
#  (cpp/cmodel_pybind.cpp CbList& vec = it->second), 回调内 SetModifyCB /
#  ClearModifyCB 改动注册表 → vector 迭代器失效 → 段错误(3/3 复现)。
#  修复后先做本地快照拷贝, 语义与 Python 版 _fire 的 list(field_cbs.items())
#  一致: 本轮派发不受影响, 增删注册项从下一轮起生效。
# ---------------------------------------------------------------------- #
def test_callback_registers_new_tag_same_field_within_fire(ModelCls):
    """(a) 回调内对同字段 SetModifyCB 新 tag —— 新回调本轮不派发, 下轮生效。
    修复前 CModel 3/3 SIGSEGV: 回调期 vector 插入(重分配)使迭代器失效。"""
    m = ModelCls()
    calls = []
    done = []
    m.SetModifyCB("first", "sName", lambda mm: calls.append("first"))

    def cb_reg(mm):
        calls.append("reg")
        if not done:                               # 只注册一次, 避免覆盖警告噪音
            done.append(1)
            m.SetModifyCB("second", "sName", lambda mm: calls.append("second"))

    m.SetModifyCB("reg", "sName", cb_reg)

    m.sName = "x"
    assert calls == ["first", "reg"]               # 快照: 本轮不派发新注册的 second
    m.sName = "y"
    assert calls == ["first", "reg", "first", "reg", "second"]   # 下轮两个都在


def test_callback_clears_tag_within_fire(ModelCls):
    """(b) 回调内 ClearModifyCB(tag=...) —— 当场注销自身, 本轮后续 tag 仍派发。
    修复前 CModel 3/3 SIGSEGV: 迭代中 erase 当前元素 → 迭代器失效。"""
    m = ModelCls()
    calls = []

    def cb_a(mm):
        calls.append("A")
        m.ClearModifyCB(tag="tA")                  # 删除正在派发本回调的注册项

    m.SetModifyCB("tA", "sName", cb_a)
    m.SetModifyCB("tB", "sName", lambda mm: calls.append("B"))

    m.sName = "x"
    assert calls == ["A", "B"]                     # 快照: tB 本轮仍派发(与 Python 一致)
    m.sName = "y"
    assert calls == ["A", "B", "B"]                # tA 已注销, 只剩 tB


def test_callback_clears_all_within_fire(ModelCls):
    """(c) 回调内 ClearModifyCB() 无参清空 —— 本轮快照内剩余回调仍派发, 之后再不触发。
    修复前 CModel 3/3 SIGSEGV: cbs_.clear() 析构正在被迭代的 vector → 悬垂迭代。"""
    m = ModelCls()
    calls = []

    def cb_clear(mm):
        calls.append("clear")
        m.ClearModifyCB()                          # 全清注册表

    m.SetModifyCB("t1", "sName", cb_clear)
    m.SetModifyCB("t2", "sName", lambda mm: calls.append("t2"))
    m.SetModifyCB("t3", "nAge", lambda mm: calls.append("t3"))

    m.sName = "x"
    assert calls == ["clear", "t2"]                # 快照: 本轮 t2 仍派发
    m.sName = "y"
    m.nAge = 1
    assert calls == ["clear", "t2"]                # 清空后不再有任何回调


# ---------------------------------------------------------------------- #
#  决策 8:回调异常吞掉 + 带堆栈日志
# ---------------------------------------------------------------------- #
def test_callback_exception_swallowed_and_logged(ModelCls, caplog):
    m = ModelCls()
    fired_after = []
    m.SetModifyCB("boom", "nAge",
                  lambda mm: (_ for _ in ()).throw(ValueError("boom")))
    m.SetModifyCB("ok", "nAge", lambda mm: fired_after.append(1))

    with caplog.at_level(logging.ERROR, logger="cmodel"):
        m.nAge = 1                               # 不应抛出

    assert fired_after == [1]                    # 异常被吞掉, 后续回调照常
    errors = [r for r in caplog.records if r.levelno == logging.ERROR]
    assert errors and any("callback error" in r.getMessage() for r in errors)
    err = errors[0]
    assert err.exc_info is not None              # 带堆栈
    assert err.exc_info[0] is ValueError


# ---------------------------------------------------------------------- #
#  决策 2 续:ClearModifyCB 四种姿势
# ---------------------------------------------------------------------- #
def test_clearmodifycb_variants(ModelCls):
    m = ModelCls()
    fired = []
    m.SetModifyCB("tA", "sName", lambda mm: fired.append("sName-A"))
    m.SetModifyCB("tB", "sName", lambda mm: fired.append("sName-B"))
    m.SetModifyCB("tA", "nAge", lambda mm: fired.append("nAge-A"))

    # 精确 (field, tag)
    m.ClearModifyCB(tag="tA", field="sName")
    m.sName = "x"
    assert fired == ["sName-B"]                  # 只剩 tB

    # 按 field: 清该字段全部
    m.ClearModifyCB(field="sName")
    m.sName = "y"
    assert fired == ["sName-B"]                  # sName 已无回调

    # 按 tag: 清所有字段下 tA
    fired.clear()
    m.ClearModifyCB(tag="tA")
    m.nAge = 1
    assert fired == []                           # nAge 的 tA 也被清了

    # 全清
    m.SetModifyCB("tZ", "nAge", lambda mm: fired.append("nAge-Z"))
    m.ClearModifyCB()
    m.nAge = 2
    assert fired == []


# ---------------------------------------------------------------------- #
#  transaction: 批量写入, 批末每字段只 fire 一次
# ---------------------------------------------------------------------- #
def test_transaction_coalesces_to_one_fire_per_field(ModelCls):
    m = ModelCls()
    calls = []
    m.SetModifyCB("t", "sName", lambda mm: calls.append(mm.sName))
    with m.transaction():
        m.sName = "a"
        m.sName = "b"
        m.sName = "c"                            # 同字段多次, 批末只 fire 1 次(用终值)
    assert calls == ["c"]


def test_transaction_rollback_on_exception(ModelCls):
    m = ModelCls()
    calls = []
    m.SetModifyCB("t", "sName", lambda mm: calls.append(mm.sName))
    with pytest.raises(ValueError):
        with m.transaction():
            m.sName = "x"
            raise ValueError("boom")
    assert calls == []                           # 异常回滚, 不 fire
    assert m.sName == "x"                        # 值已更新, 只是没通知


# ---------------------------------------------------------------------- #
#  契约:_ 属性不触发/不警告;_declared 快照;构造期不警告
# ---------------------------------------------------------------------- #
def test_internal_underscore_attr_does_not_fire_or_warn(ModelCls, recwarn):
    fired = []
    m = ModelCls()
    m.SetModifyCB("t", "sName", lambda mm: fired.append(1))
    m._something = 5
    assert fired == []
    assert [str(w.message) for w in recwarn.list] == []


def test_declared_snapshot_captured_after_init(ModelCls):
    m = ModelCls()
    assert m._declared == frozenset({"sName", "nAge", "lstTags", "sUpper"})


def test_construction_does_not_warn_on_declared_fields(ModelCls, recwarn):
    ModelCls()                                   # 构造期赋值已声明字段 -> 无未声明警告
    msgs = [str(w.message) for w in recwarn.list]
    assert not any("not declared" in x for x in msgs)


# ---------------------------------------------------------------------- #
#  set_many(仅 C++ 实现提供): 参数 py::list → py::sequence,
#  兼容 list / tuple / numpy 一维数组(每元素经序列协议取值)
# ---------------------------------------------------------------------- #
def test_set_many_accepts_list_and_tuple(ModelCls):
    m = ModelCls()
    if not hasattr(m, "set_many"):
        pytest.skip("纯 Python 实现无 set_many(批量写入是 C++ 热路径专属)")
    fired = []
    m.SetModifyCB("t", "nAge", lambda mm: fired.append(mm.nAge))
    m.set_many("nAge", [1, 2, 3])                # list(原有)
    assert fired == [1, 2, 3]
    fired.clear()
    m.set_many("nAge", (4, 5))                   # tuple(py::sequence 兼容)
    assert fired == [4, 5]
    assert m.nAge == 5


def test_set_many_accepts_numpy_1d(ModelCls):
    np = pytest.importorskip("numpy")
    m = ModelCls()
    if not hasattr(m, "set_many"):
        pytest.skip("纯 Python 实现无 set_many(批量写入是 C++ 热路径专属)")
    fired = []
    m.SetModifyCB("t", "nAge", lambda mm: fired.append(int(mm.nAge)))
    m.set_many("nAge", np.array([6, 7, 8]))      # numpy 一维数组(py::sequence 兼容)
    assert fired == [6, 7, 8]
    assert int(m.nAge) == 8
