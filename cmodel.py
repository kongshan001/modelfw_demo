"""CModel —— 数据驱动的属性变更回调框架。

典型用法::

    class MyModel(CModel):
        def __init__(self):
            super().__init__()      # 必须先调用
            self.sName = ""          # 在 __init__ 里显式声明字段 + 默认值
            self.nAge = 0

    oModel = MyModel()
    oModel.SetModifyCB(oTag, "sName", onNameCB)   # 注册回调:(分组tag, 字段名, 回调)
    oModel.sName = "test"                          # 赋值即触发 onNameCB(oModel)

回调签名统一为 ``cb(oModel)`` —— 只把 model 实例传进去,回调自己读 ``oModel.sName``
拿新值、也能改别的字段(从而形成连锁)。
"""

import logging
import warnings
from contextlib import contextmanager

logger = logging.getLogger(__name__)

# 「字段尚未赋值过」的哨兵
_UNSET = object()


def _changed(old, new):
    """判断 old -> new 是否算「变更」。

    - 可变 / 不可哈希类型(``type(new).__hash__ is None``,如 list/dict/set):
      用同一性判断,只要换了个新对象就算变更(赋同一对象=原地改,不算)。
    - 不可变类型:用值相等判断;``__eq__`` 抛异常则退回同一性。
    """
    if type(new).__hash__ is None:
        return new is not old
    try:
        return bool(old != new)
    except Exception:
        return new is not old


class CModel:
    """数据驱动模型基类。

    必须**子类化**使用:字段在子类 ``__init__`` 里用 ``self.xxx = 默认值`` 显式声明,
    并在最开头调用 ``super().__init__()``。子类除此之外无需任何额外代码。
    """

    # 子类定义时自动把其 __init__ 包一层:跑完原 __init__ 后,快照「已声明字段集」。
    # 这样子类零负担,框架就能区分「已声明字段」与「动态追加字段」(后者赋值时会警告)。
    # _declared 的存在同时充当「构造已完成」的标记 —— 构造期它还不存在,所以构造期
    # 的字段赋值不会触发「未声明」警告(那时回调注册表也是空的,fire 本就是空操作)。
    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)
        _origin_init = cls.__init__

        def _wrapped_init(self, *args, **kw):
            _origin_init(self, *args, **kw)
            object.__setattr__(
                self,
                "_declared",
                frozenset(k for k in self.__dict__ if not k.startswith("_")),
            )

        cls.__init__ = _wrapped_init

    def __init__(self):
        # `_` 开头一律视为内部状态:__setattr__ 直接落盘,不触发回调、不做声明校验。
        self._callbacks = {}   # {字段名: {tag: 回调}}
        self._firing = set()   # 当前正在 fire 的字段集合(按字段防环)
        self._deferring = False   # transaction 期内: 只记脏字段, 不 fire
        self._dirty = []          # 期内变更过的字段(有序去重)

    # ------------------------------------------------------------------ #
    #  属性写入核心
    # ------------------------------------------------------------------ #
    def __setattr__(self, name, value):
        # 内部状态(_ 开头)直接落盘,绕过一切回调逻辑
        if name.startswith("_"):
            object.__setattr__(self, name, value)
            return

        # 构造完成后(_declared 已就位)才校验声明
        if "_declared" in self.__dict__ and name not in self._declared:
            warnings.warn(
                f"CModel: field {name!r} not declared in __init__, "
                f"assigning dynamically",
                stacklevel=2,
            )

        old = self.__dict__.get(name, _UNSET)
        changed = (old is _UNSET) or _changed(old, value)

        object.__setattr__(self, name, value)   # 先存值,保证回调里读到的是新值
        if changed:
            if self._deferring:                 # transaction 期内: 记脏, 暂不 fire
                if name not in self._dirty:
                    self._dirty.append(name)
            else:
                self._fire(name)

    def _fire(self, name):
        """触发某字段的全部回调;带「按字段粒度」的防环保护。"""
        field_cbs = self._callbacks.get(name)
        if not field_cbs:
            return

        # 防环:该字段已在自身回调链里被触发 -> 警告并中断该链
        if name in self._firing:
            warnings.warn(
                f"CModel: loop detected on field {name!r}, break callback chain",
                stacklevel=2,
            )
            return

        self._firing.add(name)
        try:
            # 拷贝一份遍历,避免回调里改注册表导致迭代异常
            for tag, cb in list(field_cbs.items()):
                try:
                    cb(self)               # 回调签名: cb(oModel)
                except Exception:
                    # 吞掉 + 记日志(带完整堆栈),不影响其余回调与连锁
                    logger.exception(
                        "CModel: callback error on field %r tag %r", name, tag
                    )
        finally:
            self._firing.discard(name)

    # ------------------------------------------------------------------ #
    #  回调注册 / 清理 / 手动触发
    # ------------------------------------------------------------------ #
    def SetModifyCB(self, tag, field, cb):
        """注册回调。注册表结构 ``{field: {tag: cb}}``。

        同一个 ``(tag, field)`` 重复注册会**覆盖**旧回调,并打印一条警告。
        ``tag`` 是分组/注销 key(任意可哈希值),同一 tag 可盯多个字段,
        同一字段也可挂多个 tag。
        """
        field_cbs = self._callbacks.setdefault(field, {})
        if tag in field_cbs:
            warnings.warn(
                f"CModel: overwrite callback for field {field!r} tag {tag!r}",
                stacklevel=2,
            )
        field_cbs[tag] = cb

    def ClearModifyCB(self, tag=None, field=None):
        """清理回调。

        - 只给 ``field``        :清该字段的全部回调
        - 只给 ``tag``          :清所有字段下该 tag 的回调
        - 两个都给              :精确清 (field, tag)
        - 两个都不给            :清空全部回调
        """
        if field is not None:
            if tag is not None:
                self._callbacks.get(field, {}).pop(tag, None)
            else:
                self._callbacks.pop(field, None)
        elif tag is not None:
            for d in self._callbacks.values():
                d.pop(tag, None)
        else:
            self._callbacks.clear()

    def NotifyChange(self, field):
        """强制触发某字段的回调(不依赖值是否变化)。

        主要用于可变类型被**原地修改**后手动补刀 —— 例如 ``oModel.lst.append(x)``
        不经过 ``__setattr__``,框架默认看不见,改完调用本方法通知一次。
        """
        self._fire(field)

    # ---- transaction: 批量写入, 批末每字段只 fire 一次(合并回调通知) ----
    def begin_defer(self):
        self._deferring = True

    def commit_defer(self):
        self._deferring = False
        for f in self._dirty:          # 每脏字段只 fire 一次
            self._fire(f)
        self._dirty.clear()

    def rollback_defer(self):
        self._deferring = False
        self._dirty.clear()            # 异常回滚: 丢弃脏字段, 不 fire

    @contextmanager
    def transaction(self):
        """transaction 上下文: 期内写入只更新值不 fire, 正常退出时每字段 fire 一次;
        抛异常则回滚(不 fire)。"""
        self.begin_defer()
        try:
            yield self
        except Exception:
            self.rollback_defer()
            raise
        else:
            self.commit_defer()


# ---------------------------------------------------------------------- #
#  无感后端选择: CModel 这个名字优先指向 C++ 实现(cmodel_fast / cmodelpb)。
#  - 用户原有 `from cmodel import CModel` 无需改动, 自动用上 C++。
#  - C++ 后端不可用时(未构建 cpp/)静默回退到上面的纯 Python 实现。
#  - 纯 Python 版本始终可用 cmodel.PyCModel 显式取用。
#  - CMODEL_IMPL 环境变量: auto(默认,有 C++ 用 C++)/ cpp(强制,缺失则报错)/ py(强制纯 Python)。
# ---------------------------------------------------------------------- #
PyCModel = CModel  # 纯 Python 版本别名(在可能被替换前先固定下来)

import os as _os
_IMPL = _os.environ.get("CMODEL_IMPL", "auto").lower()
_BACKEND = "py"
if _IMPL == "py":
    pass  # 保持纯 Python
elif _IMPL in ("auto", "cpp"):
    try:
        from cmodel_fast import CModel as _CModelCpp
        CModel = _CModelCpp  # 无感替换为 C++ 实现
        _BACKEND = "cpp"
    except Exception:
        if _IMPL == "cpp":
            raise RuntimeError(
                "CMODEL_IMPL=cpp 但 C++ 后端不可用, 请先构建: cd cpp && cmake -S . -B build && cmake --build build"
            )
        # auto: 静默回退纯 Python
else:
    raise ValueError(f"CMODEL_IMPL 需为 auto/cpp/py, 实际 {_IMPL!r}")


# ---------------------------------------------------------------------- #
#  自测 demo:覆盖全部 8 条决策的行为
# ---------------------------------------------------------------------- #
if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s %(name)s: %(message)s"
    )

    class UserModel(CModel):
        def __init__(self):
            super().__init__()
            self.sName = ""        # 不可变字段
            self.nAge = 0          # 不可变字段
            self.lstTags = []      # 可变字段

    def on_name(m):
        print(f"    [on_name] sName -> {m.sName!r}")

    m = UserModel()

    print("1) 注册 sName 回调(tagA),改值 -> 触发")
    m.SetModifyCB("tagA", "sName", on_name)
    m.sName = "test"

    print("2) 不可变类型,赋同样的值 -> 不触发(值相等)")
    m.sName = "test"

    print("3) 改成新值 -> 触发")
    m.sName = "hello"

    print("4) 可变类型:赋一个新 list -> 触发(走 is)")
    m.SetModifyCB("tagL", "lstTags",
                  lambda mm: print(f"    [on_tags] lstTags -> {mm.lstTags}"))
    m.lstTags = ["a", "b"]

    print("5) 可变类型原地 append -> 不触发(机制盲区),用 NotifyChange 补刀")
    m.lstTags.append("c")
    print(f"    after append: {m.lstTags} (回调没响)")
    m.NotifyChange("lstTags")

    print("6) 未声明字段 -> 警告但仍可赋值")
    m.sExtra = "x"

    print("7) 连锁 + 防环:回调里再改 sName,形成环 -> 中断")
    def loop_cb(mm):
        print("    [loop_cb] entered, set sName again ->")
        mm.sName = mm.sName + "!"   # 再次触发 sName 回调,被防环拦截
    m.SetModifyCB("tagLoop", "sName", loop_cb)
    m.sName = "world"

    print("8) 回调抛异常 -> 吞掉带堆栈,不影响其它")
    m.SetModifyCB("tagBoom", "nAge", lambda mm: (_ for _ in ()).throw(ValueError("boom")))
    m.nAge = 18

    print("9) ClearModifyCB(field='sName') 后再改 -> 不触发")
    m.ClearModifyCB(field="sName")
    m.sName = "cleared"
    print(f"    final sName = {m.sName!r}")
