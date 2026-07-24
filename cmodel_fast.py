"""C++ 版 CModel 的 Python 平替入口。

用法: 把 `from cmodel import CModel` 换成 `from cmodel_fast import CModel`, 其余代码不动。
API 与行为(含未声明字段警告、覆盖警告、防环、异常带堆栈日志)与纯 Python 版逐条一致;
热路径(__setattr__ / 变更检测 / 回调派发)跑在 C++。

本文件是极薄的 Python 壳, 只为复刻 Python 版的 `__init_subclass__` 声明快照机制
(决策 6/7)——C++ 无法干净实现 __init_subclass__, 故由这层壳在子类 __init__ 跑完后
调用 C++ 的 _field_names() 快照已声明字段, 写回 self._declared(被 C++ 拦截填充)。
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "cpp", "build"))
import cmodelpb as _cmodelpb  # noqa: E402


class CModel(_cmodelpb.CModel):
    """与 cmodel.CModel 同 API 的 C++ 实现平替。必须子类化, 字段在 __init__ 声明。"""

    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)
        _origin_init = cls.__init__

        def _wrapped_init(self, *args, **kw):
            _origin_init(self, *args, **kw)
            # 构造完成后快照已声明字段(字段存在 C++ 侧, 借 _field_names 取出)
            self._declared = frozenset(self._field_names())

        cls.__init__ = _wrapped_init
