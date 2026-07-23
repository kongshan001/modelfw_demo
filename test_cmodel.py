"""CModel 回归测试 —— 把 8 条决策 + 用法契约固化成可回归用例。

运行: python3 -m pytest test_cmodel.py -v
"""

import logging
import warnings

import pytest

from cmodel import CModel


class UserModel(CModel):
    """被测模型:同时含不可变字段、可变字段、连锁用字段。"""

    def __init__(self):
        super().__init__()
        self.sName = ""
        self.nAge = 0
        self.lstTags = []      # 可变字段
        self.sUpper = ""       # 连锁用


@pytest.fixture(autouse=True)
def _warn_always():
    """所有 UserWarning 都触发,不被默认 'default' 过滤器按代码位置去重。"""
    with warnings.catch_warnings():
        warnings.simplefilter("always")
        yield


# ---------------------------------------------------------------------- #
#  决策 3 / 4:赋值触发 cb(oModel);值相等不触发
# ---------------------------------------------------------------------- #
def test_change_fires_callback_receiving_model():
    received = []
    m = UserModel()
    m.SetModifyCB("t", "sName", lambda mm: received.append(mm))
    m.sName = "test"
    assert received == [m]                       # 签名 cb(oModel):收到的是 model 本身


def test_no_fire_when_immutable_value_unchanged():
    fired = []
    m = UserModel()
    m.sName = "init"                             # 先给个初值(此时无回调)
    m.SetModifyCB("t", "sName", lambda mm: fired.append(1))
    m.sName = "init"                             # 不可变、同值 -> 不触发
    assert fired == []


def test_fire_when_value_actually_changes():
    fired = []
    m = UserModel()
    m.SetModifyCB("t", "sName", lambda mm: fired.append(mm.sName))
    m.sName = "a"
    m.sName = "b"
    assert fired == ["a", "b"]


# ---------------------------------------------------------------------- #
#  决策 4:可变类型用 is
# ---------------------------------------------------------------------- #
def test_mutable_reassign_same_object_does_not_fire():
    fired = []
    m = UserModel()
    m.SetModifyCB("t", "lstTags", lambda mm: fired.append(1))
    m.lstTags = m.lstTags                        # 同一对象(is)-> 不算变更
    assert fired == []


def test_mutable_reassign_new_object_fires_even_if_equal():
    fired = []
    m = UserModel()
    m.SetModifyCB("t", "lstTags", lambda mm: fired.append(1))
    m.lstTags = []                               # 新 list 对象,内容相等 -> 仍 fire(is)
    assert fired == [1]


def test_mutable_inplace_mutation_then_notifychange():
    fired = []
    m = UserModel()
    m.lstTags = ["a"]                            # 建立非空 list
    m.SetModifyCB("t", "lstTags", lambda mm: fired.append(list(mm.lstTags)))
    m.lstTags.append("b")                        # 原地改 -> 盲区,不触发
    assert fired == []
    m.NotifyChange("lstTags")                    # 手动补刀
    assert fired == [["a", "b"]]


# ---------------------------------------------------------------------- #
#  决策 2:注册表 / 覆盖警告 / 多 tag
# ---------------------------------------------------------------------- #
def test_setmodifycb_overwrite_warns_and_replaces():
    m = UserModel()
    m.SetModifyCB("t", "sName", lambda mm: None)
    with pytest.warns(UserWarning, match="overwrite"):
        m.SetModifyCB("t", "sName", lambda mm: None)
    assert set(m._callbacks["sName"]) == {"t"}   # 同 (tag, field) 只剩一个


def test_multiple_tags_on_same_field_all_fire():
    fired = []
    m = UserModel()
    m.SetModifyCB("t1", "sName", lambda mm: fired.append("t1"))
    m.SetModifyCB("t2", "sName", lambda mm: fired.append("t2"))
    m.sName = "x"
    assert fired == ["t1", "t2"]                 # 多 tag 都触发


# ---------------------------------------------------------------------- #
#  决策 7:未声明字段警告;已声明不警告
# ---------------------------------------------------------------------- #
def test_undeclared_field_warns_but_still_works():
    m = UserModel()
    with pytest.warns(UserWarning, match="not declared"):
        m.sExtra = "x"
    assert m.sExtra == "x"


def test_declared_field_does_not_warn(recwarn):
    m = UserModel()
    m.sName = "hello"                            # 已声明 -> 无警告
    assert [str(w.message) for w in recwarn.list] == []


# ---------------------------------------------------------------------- #
#  决策 5:连锁 + 按字段防环
# ---------------------------------------------------------------------- #
def test_chaining_fires_other_field():
    m = UserModel()
    m.SetModifyCB("chain", "sName",
                  lambda mm: setattr(mm, "sUpper", mm.sName.upper()))
    fired = []
    m.SetModifyCB("upper", "sUpper", lambda mm: fired.append(mm.sUpper))
    m.sName = "abc"
    assert m.sUpper == "ABC"
    assert fired == ["ABC"]


def test_loop_protection_breaks_cycle():
    calls = []
    m = UserModel()

    def loop_cb(mm):
        calls.append(1)
        mm.sName = mm.sName + "x"                # 再次触发 sName 自身回调 -> 环

    m.SetModifyCB("loop", "sName", loop_cb)
    with pytest.warns(UserWarning, match="loop detected"):
        m.sName = "a"
    assert calls == [1]                          # 没有无限递归


# ---------------------------------------------------------------------- #
#  决策 8:回调异常吞掉 + 带堆栈日志
# ---------------------------------------------------------------------- #
def test_callback_exception_swallowed_and_logged(caplog):
    m = UserModel()
    fired_after = []
    m.SetModifyCB("boom", "nAge",
                  lambda mm: (_ for _ in ()).throw(ValueError("boom")))
    m.SetModifyCB("ok", "nAge", lambda mm: fired_after.append(1))

    with caplog.at_level(logging.ERROR, logger="cmodel"):
        m.nAge = 1                               # 不应抛出

    assert fired_after == [1]                    # 异常被吞掉,后续回调照常
    errors = [r for r in caplog.records if r.levelno == logging.ERROR]
    assert errors and any("callback error" in r.getMessage() for r in errors)
    err = errors[0]
    assert err.exc_info is not None              # 带堆栈
    assert err.exc_info[0] is ValueError


# ---------------------------------------------------------------------- #
#  决策 2 续:ClearModifyCB 四种姿势
# ---------------------------------------------------------------------- #
def test_clearmodifycb_variants():
    m = UserModel()
    fired = []
    m.SetModifyCB("tA", "sName", lambda mm: fired.append("sName-A"))
    m.SetModifyCB("tB", "sName", lambda mm: fired.append("sName-B"))
    m.SetModifyCB("tA", "nAge", lambda mm: fired.append("nAge-A"))

    # 精确 (field, tag)
    m.ClearModifyCB(tag="tA", field="sName")
    m.sName = "x"
    assert fired == ["sName-B"]                  # 只剩 tB

    # 按 field:清该字段全部
    m.ClearModifyCB(field="sName")
    m.sName = "y"
    assert fired == ["sName-B"]                  # sName 已无回调

    # 按 tag:清所有字段下 tA
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
#  契约:_ 属性不触发/不警告;_declared 快照;构造期不警告
# ---------------------------------------------------------------------- #
def test_internal_underscore_attr_does_not_fire_or_warn(recwarn):
    fired = []
    m = UserModel()
    m.SetModifyCB("t", "sName", lambda mm: fired.append(1))
    m._something = 5
    assert fired == []
    assert [str(w.message) for w in recwarn.list] == []


def test_declared_snapshot_captured_after_init():
    m = UserModel()
    assert m._declared == frozenset({"sName", "nAge", "lstTags", "sUpper"})


def test_construction_does_not_warn_on_declared_fields(recwarn):
    UserModel()                                  # 构造期赋值已声明字段 -> 无未声明警告
    msgs = [str(w.message) for w in recwarn.list]
    assert not any("not declared" in x for x in msgs)
