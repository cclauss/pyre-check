(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open OUnit2
open IntegrationTest

let test_check_comprehensions =
  test_list
    [
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(input: typing.List[str]) -> typing.List[str]:
        return [a for a in input]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(input: typing.List[str]) -> typing.List[str]:
        return [a for a in input if len(a) < 5]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(input: str) -> typing.List[int]:
        return [a for a in input]
    |}
           ["Incompatible return type [7]: Expected `List[int]` but got `List[str]`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.List[str]:
        return [x for x in [4,3,None, 1] if x]
    |}
           ["Incompatible return type [7]: Expected `List[str]` but got `List[int]`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(l: typing.List[int]) -> None:
        a = [x > 0 and x < 0 for x in l]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      x: str = ""
      [x for x in [1,2,3,4,5] if isinstance(x, int)]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(l: typing.Dict[int, str]) -> None:
        [x if y else 0 for x, y in l.items()]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Dict[int, int]:
        return { 0: x for x in [4,3,2] }
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(d: typing.Dict[int, str]) -> typing.Dict[int, str]:
        return { k: v for k, v in d }
    |}
           ["Unable to unpack [23]: Unable to unpack `int` into 2 values."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(d: typing.Dict[int, str]) -> typing.Dict[int, str]:
        return { k: v for k, v in d.items() }
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(input: typing.List[str]) -> typing.List[str]:
        return [a.lower() for a in input]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      from builtins import str_to_int
      import typing
      def foo(input: typing.List[str]) -> typing.List[int]:
        return [str_to_int(a) for a in input]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(input: typing.Set[str]) -> typing.Set[str]:
        return {a for a in input}
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(input: typing.Set[str]) -> typing.Set[str]:
        return {a.lower() for a in input}
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(a: typing.List[str], b: typing.List[str]) -> int:
        return {x + y for x in a for y in b}
    |}
           ["Incompatible return type [7]: Expected `int` but got `Set[str]`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(a: typing.Dict[str, int]) -> typing.List[int]:
        return [x for x in a]
    |}
           ["Incompatible return type [7]: Expected `List[int]` but got `List[str]`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      def f() -> int:
          x = {
              "a": [k[0] for x in {1: 1}] for k in [[1]]
          }
          return 0
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(a: typing.Dict[str, int]) -> typing.Dict[str, str]:
        return { x:x for x, y in a.items() }
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(a: typing.Dict[str, int]) -> typing.Dict[str, int]:
        return { y:x for x, y in a.items() }
    |}
           ["Incompatible return type [7]: Expected `Dict[str, int]` but got `Dict[int, str]`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      def f() -> None:
        l = lambda y: y
        l(1)
        lambda *y: y
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(a: typing.Dict[str, typing.Optional[int]]) -> typing.Dict[str, int]:
        return { x: y for (x, y) in a.items() if y }
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(a: typing.Dict[str, typing.Optional[int]]) -> typing.Dict[str, int]:
        return { x: y for (x, y) in a.items() }
    |}
           [
             "Incompatible return type [7]: Expected `Dict[str, int]` but got `Dict[str, \
              Optional[int]]`.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      from builtins import int_to_int
      import typing
      def foo(a: typing.Dict[str, typing.Optional[int]]) -> typing.Dict[str, int]:
        return { x: int_to_int(y) for (x, y) in a.items() if y }
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(d: typing.Dict[str, int]) -> None:
        { k: v for k, v in d }
    |}
           [];
    ]


let test_check_yield =
  test_list
    [
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[int, None, None]:
        yield 1
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(i: int) -> typing.Iterable[int]:
        if i > 2:
          return
        else:
          yield i
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[int, None, None]:
        yield 1.0
    |}
           [
             "Incompatible return type [7]: Expected `Generator[int, None, None]` "
             ^ "but got `Generator[float, typing.Any, typing.Any]`.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[None, None, None]:
        yield
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Iterable[None]:
        yield
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[None, None, None]:
        yield
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      import asyncio.coroutines

      @asyncio.coroutines.coroutine
      def get() -> typing.Generator[typing.Any, None, int]: ...
      async def foo() -> int:
        awaited = await get()
        return awaited
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      async def foo() -> typing.AsyncGenerator[int, None]:
        yield 1
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def takes_int(x: int) -> int:
        return x
      async def loop(g: typing.AsyncGenerator[str, None]) -> typing.AsyncGenerator[int, None]:
        async for item in g:
          yield takes_int(item)
    |}
           [
             "Incompatible parameter type [6]: In call `takes_int`, for 1st positional argument, \
              expected `int` but got `str`.";
           ];
      (* Make sure the send type is handled correctly *)
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Iterator[str]:
        x = yield "hello"
        reveal_type(x)
    |}
           ["Revealed type [-1]: Revealed type for `x` is `None`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[str, int, None]:
        x = yield "hello"
        reveal_type(x)
    |}
           ["Revealed type [-1]: Revealed type for `x` is `int`."];
      (* Make sure an empty return works properly in both the sync and async cases *)
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(flag: bool) -> typing.Generator[int, None, None]:
        if flag:
          return
        yield 1
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      async def foo(flag: bool) -> typing.AsyncGenerator[int, None]:
        if flag:
          return
        yield 1
    |}
           [];
      (* return type handling - this applies only to regualar generators, not async per PEP 525 *)
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[int, None, str]:
        yield 1
        return "str"
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[int, None, str]:
        yield 1
        return
    |}
           [
             "Incompatible return type [7]: Expected `Generator[int, None, str]` but got \
              `Generator[typing.Any, typing.Any, None]`.";
           ];
    ]


let test_check_yield_from =
  test_list
    [
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[int, None, None]:
        yield from [1]
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo() -> typing.Generator[int, None, None]:
        yield from [""]
    |}
           [
             "Incompatible return type [7]: Expected `Generator[int, None, None]` "
             ^ "but got `Generator[str, None, typing.Any]`.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def generator() -> typing.Generator[int, None, None]:
        yield 1
      def wrapper() -> typing.Generator[int, None, None]:
        yield from generator()
    |}
           [];
      (* return type handling for yield from *)
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing

      yielded_from: typing.Generator[int, None, str]

      def foo() -> typing.Generator[int, None, str]:
        x = yield from yielded_from
        reveal_type(x)
    |}
           ["Revealed type [-1]: Revealed type for `x` is `str`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing

      yielded_from: typing.Iterator[int]

      def foo() -> typing.Generator[int, None, str]:
        x = yield from yielded_from
        reveal_type(x)
    |}
           ["Revealed type [-1]: Revealed type for `x` is `None`."];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      from typing import AsyncGenerator, AsyncIterator

      async def foo(n: int) -> AsyncGenerator[int, None]:
        for i in range(n):
            yield i

      async def bar(n: int) -> AsyncGenerator[int, None]:
        return (2 * i async for i in foo(n))
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      from typing import AsyncGenerator, Generator, AsyncIterator

      async def inner_async_gen(x: int) -> AsyncGenerator[int, None]:
          for y in range(x):
              yield y

      def outer_generator() -> Generator[int, None, None]:
          return (y for x in range(5) async for y in inner_async_gen(x))
    |}
           [
             "Incompatible return type [7]: Expected `Generator[int, None, None]` but got \
              `AsyncGenerator[int, typing.Any]`.";
             "Illegal await [76]: `await` may only be used inside an async definition.";
           ];
    ]


let test_check_generator_edge_cases =
  test_list
    [
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      x: typing.Generator[typing.Any, typing.Any, typing.Any]
      def foo() -> typing.Generator:
        return x
    |}
           [
             "Missing global annotation [5]: Globally accessible variable `x` must be specified "
             ^ "as type that does not contain `Any`.";
             "Invalid type parameters [24]: Generic type `typing.Generator` expects 3 type \
              parameters.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      x: typing.Generator[int, int, int]
      def foo() -> typing.Generator:
        return x
    |}
           [
             "Invalid type parameters [24]: Generic type `typing.Generator` expects 3 type \
              parameters.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(l: typing.List[int])->typing.Generator[int, None, None]:
        return (x for x in l)
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(l: typing.List[typing.Optional[int]])->typing.Generator[int, None, None]:
        return (x for x in l if x)
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(l: typing.List[typing.Optional[int]])->typing.Generator[str, None, None]:
        return (x for x in l if x is not None)
    |}
           [
             "Incompatible return type [7]: Expected `Generator[str, None, None]` "
             ^ "but got `Generator[int, None, None]`.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      def foo(l: typing.Iterable[typing.Any])->typing.Generator[typing.Any, None, None]:
        return (x for x in l)
    |}
           [
             "Missing return annotation [3]: Return type must be specified as type "
             ^ "that does not contain `Any`.";
             "Missing parameter annotation [2]: Parameter `l` must have a type "
             ^ "that does not contain `Any`.";
           ];
      (* send type handling for yield from. The send type is contravariant *)
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing

      generator: typing.Generator[int, float, None]

      def foo() -> typing.Generator[int, str, None]:
        yield from generator
    |}
           [
             "Incompatible return type [7]: Expected `Generator[int, str, None]` but got \
              `Generator[int, float, typing.Any]`.";
           ];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing

      class A: pass
      class B(A): pass

      generator: typing.Generator[int, A, None]

      def foo() -> typing.Generator[int, B, None]:
        yield from generator
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      async def is_odd(i: int) -> bool:
          return i % 2 != 0

      async def foo() -> typing.AsyncGenerator[int, None]:
          return (x for x in range(5) if await is_odd(x))
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      async def double(i: int) -> int:
          return i * 2

      async def foo() -> typing.AsyncGenerator[int, None]:
          return (await double(x) for x in range(5))
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      async def get_list() -> typing.List[int]:
          return [1]

      async def foo() -> typing.AsyncGenerator[int, None]:
          return (x for _ in [1] for x in await get_list())
    |}
           [];
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_type_errors
           {|
      import typing
      async def get_list() -> typing.List[int]:
          return [1]

      async def foo() -> typing.Generator[int, None, None]:
          return (x for x in await get_list())
    |}
           [];
    ]


let () =
  "generator"
  >::: [
         test_check_comprehensions;
         test_check_yield;
         test_check_yield_from;
         test_check_generator_edge_cases;
       ]
  |> Test.run
