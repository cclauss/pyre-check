/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use crate::testcase;
use crate::testcase_with_bug;

testcase!(
    test_context_annassign,
    r#"
class A: ...
class B(A): ...

xs: list[A] = [B()]
"#,
);

testcase!(
    test_context_assign_annotated_binding,
    r#"
class A: ...
class B(A): ...

xs: list[A] = []
xs = [B()]
"#,
);

testcase!(
    test_context_assign_member,
    r#"
class A: ...
class B(A): ...

class C:
    xs: list[A]

o = C()
o.xs = [B()]
"#,
);

testcase!(
    test_context_class_field_init,
    r#"
class A: ...
class B(A): ...

class C:
    xs: list[A] = [B()]
    def __init__(self):
        self.xs = [B()]
"#,
);

testcase!(
    test_context_return_annot,
    r#"
class A: ...
class B(A): ...

def f() -> list[A]:
    return [B()]
"#,
);

testcase!(
    test_context_parameter,
    r#"
class A: ...
class B(A): ...

def posonly(xs: list[A], /): ...
posonly([B()])

def pos(xs: list[A]): ...
pos([B()])
pos(xs=[B()])

def kwonly(*, xs: list[A]): ...
kwonly(xs=[B()])

def vararg(*args: list[A]): ...
vararg([B()], [B()])

def kwarg(**kwargs: list[A]): ...
kwarg(xs=[B()], ys=[B()])
"#,
);

testcase!(
    test_context_assign_unpacked_list,
    r#"
class A: ...
class B(A): ...

xs: list[A] = []
[*xs] = [B(), B()]
"#,
);

testcase!(
    test_context_for,
    r#"
class A: ...
class B(A): ...

xs: list[A] = []
for xs in [[B()]]:
    pass
"#,
);

testcase!(
    test_set_hint,
    r#"
from typing import Iterable, MutableSet, Literal
x: set[int] = {1}
x: set[int] = {'oops'}  # E: EXPECTED Literal['oops'] <: int
x: set[Literal[1]] = {2}  # E: EXPECTED Literal[2] <: Literal[1]
x: MutableSet[int] = {1}
x: MutableSet[int] = {'oops'}  # E: EXPECTED Literal['oops'] <: int
x: Iterable[int] = {1}
x: object = {1}
x: list[int] = {1}  # E: EXPECTED set[int] <: list[int]
    "#,
);

testcase!(
    test_dict_hint,
    r#"
from typing import Iterable, MutableMapping, Literal
x: dict[str, int] = {"a": 1}
x: dict[str, int] = {"a": "oops"}  # E: EXPECTED Literal['oops'] <: int
x: dict[str, Literal[1]] = {"a": 2} # E: EXPECTED Literal[2] <: Literal[1]
x: MutableMapping[str, int] = {"a": 1}
x: Iterable[str] = {"a": 1}
x: Iterable[int] = {"oops": 1}  # E: EXPECTED Literal['oops'] <: int
x: Iterable[Literal[4]] = {4: "a"}
x: object = {"a": 1}
x: list[str] = {"a": 1}  # E: EXPECTED dict[str, int] <: list[str]
    "#,
);

testcase!(
    test_context_list_comprehension,
    r#"
class A: ...
class B(A): ...
xs: list[A] = [B() for _ in [0]]
"#,
);

testcase!(
    test_context_set_comprehension,
    r#"
class A: ...
class B(A): ...
xs: set[A] = {B() for _ in [0]}
"#,
);

testcase!(
    test_context_dict_comprehension,
    r#"
class A: ...
class B(A): ...
class X: ...
class Y(X): ...
xs: dict[A, X] = {B(): Y() for _ in [0]}
"#,
);

testcase!(
    test_context_if_expr,
    r#"
class A: ...
class B(A): ...
def cond() -> bool: ...
xs: list[A] = [B()] if cond() else [B()]
"#,
);

// Still infer types for unreachable branches (and find errors in them),
// but don't propagate them to the result.
testcase!(
    test_context_if_expr_unreachable,
    r#"
class A: ...
class B(A): ...
def takes_int(x: int) -> None: ...
xs: list[A] = [B()] if True else takes_int("") # E: EXPECTED Literal[''] <: int
ys: list[A] = takes_int("") if False else [B()] # E: EXPECTED Literal[''] <: int
"#,
);

// TODO: Unpacked assignment propagates wrong hint to RHS expression
testcase_with_bug!(
    test_context_assign_unpacked_tuple,
    r#"
class A: ...
class B(A): ...

xs: list[A] = []
(xs, _) = ([B()], None) # E: EXPECTED tuple[list[B], None] <: list[A]
"#,
);

// TODO: No context propagated to subscript assignment target
testcase_with_bug!(
    test_context_assign_subscript,
    r#"
class A: ...
class B(A): ...

xs: list[list[A]] = [[]]
xs[0] = [B()] # E: EXPECTED list[B] <: list[A]
"#,
);

testcase_with_bug!(
    test_generic_get_literal,
    r#"
from typing import assert_type, TypeVar, Literal

class Foo[T]:
    def __init__(self, x: T) -> None: ...
    def get(self) -> T: ...

# Should propagate the context to the argument 42
x: Foo[Literal[42]] = Foo(42)  # E: EXPECTED Foo[int] <: Foo[Literal[42]]
assert_type(x.get(), Literal[42])
"#,
);
