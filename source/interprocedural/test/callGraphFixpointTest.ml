(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Core
open OUnit2
open Test
open TestHelper
open Interprocedural
open CallGraph
open CallGraphTestHelper
open Data_structures

module Expected = struct
  type t = {
    callable: Target.t;
    returned_callables: CallTarget.t list;
    call_graph: (string * LocationCallees.t) list;
  }
end

let assert_higher_order_call_graph_fixpoint ?(max_iterations = 10) ~source ~expected () context =
  let handle = "test.py" in
  let configuration, pyre_api =
    initialize_pyre_and_fail_on_errors ~context ~handle ~source_content:source ~models_source:None
  in
  let static_analysis_configuration = Configuration.StaticAnalysis.create configuration () in
  let qualifier = Ast.Reference.create (String.chop_suffix_exn handle ~suffix:".py") in
  let source = source_from_qualifier ~pyre_api qualifier in
  let initial_callables = FetchCallables.from_source ~configuration ~pyre_api ~source in
  let definitions = FetchCallables.get_definitions initial_callables in
  let override_graph_heap = OverrideGraph.Heap.from_source ~pyre_api ~source in
  let override_graph_shared_memory = OverrideGraph.SharedMemory.from_heap override_graph_heap in
  let ({ SharedMemory.whole_program_call_graph; define_call_graphs } as call_graph) =
    SharedMemory.build_whole_program_call_graph
      ~scheduler:(Test.mock_scheduler ())
      ~static_analysis_configuration
      ~pyre_api
      ~resolve_module_path:None
      ~override_graph:(Some (OverrideGraph.SharedMemory.read_only override_graph_shared_memory))
      ~store_shared_memory:true
      ~attribute_targets:Target.Set.empty
      ~skip_analysis_targets:Target.Set.empty
      ~definitions
  in
  let dependency_graph =
    DependencyGraph.build_whole_program_dependency_graph
      ~static_analysis_configuration
      ~prune:DependencyGraph.PruneMethod.None
      ~initial_callables
      ~call_graph:whole_program_call_graph
      ~overrides:override_graph_heap
  in
  let fixpoint_state =
    CallGraphFixpoint.compute
      ~scheduler:(Test.mock_scheduler ())
      ~scheduler_policy:(Scheduler.Policy.legacy_fixed_chunk_count ())
      ~pyre_api
      ~call_graph
      ~dependency_graph
      ~override_graph_shared_memory
      ~initial_callables
      ~max_iterations
  in
  List.iter expected ~f:(fun { Expected.callable; call_graph; returned_callables } ->
      let actual_call_graph =
        callable
        |> CallGraphFixpoint.get_model fixpoint_state
        |> Option.value ~default:HigherOrderCallGraph.empty
        |> ImmutableHigherOrderCallGraph.from_higher_order_call_graph
      in
      let expected_call_graph =
        ImmutableHigherOrderCallGraph.from_input
          { ImmutableHigherOrderCallGraph.Input.call_graph; returned_callables }
      in
      assert_equal
        ~cmp:ImmutableHigherOrderCallGraph.equal
        ~printer:(fun call_graph ->
          Format.asprintf
            "For callable %a: %a"
            Target.pp
            callable
            ImmutableHigherOrderCallGraph.pp
            call_graph)
        expected_call_graph
        actual_call_graph);
  OverrideGraph.SharedMemory.cleanup override_graph_shared_memory;
  SharedMemory.cleanup define_call_graphs;
  CallGraphFixpoint.cleanup fixpoint_state;
  ()


let test_higher_order_call_graph_fixpoint =
  test_list
    [
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:
             {|
     def foo():
       return 0
     def bar():
       return foo
     def baz():
       return bar()
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.bar"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "5:9-5:12",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.foo"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.foo"; kind = Normal });
                   ];
               };
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.baz"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "7:9-7:14",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.bar"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.foo"; kind = Normal });
                   ];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:
             {|
     def foo():
       return 0
     def bar(arg):
       return foo
     def baz():
       return bar(foo)
  |}
           ~max_iterations:1
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.baz"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "7:9-7:17",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create
                                     (create_parameterized_target
                                        ~regular:
                                          (Target.Regular.Function
                                             { name = "test.bar"; kind = Normal })
                                        ~parameters:
                                          [
                                            ( create_positional_parameter 0 "arg",
                                              Target.Regular.Function
                                                { name = "test.foo"; kind = Normal }
                                              |> Target.from_regular );
                                          ]);
                                 ]
                               ())) );
                     ( "7:13-7:16",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.foo"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables = [];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:{|
     def foo():
       return foo
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.foo"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "3:9-3:12",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.foo"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.foo"; kind = Normal });
                   ];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:{|
     def foo():
       return foo()
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.foo"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "3:9-3:14",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.foo"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables = [];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:
             {|
     def bar():
       return 0
     def foo():
       if 1 == 1:
         return bar
       else:
         return foo()
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.foo"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "5:5-5:11",
                       LocationCallees.Compound
                         (SerializableStringMap.of_alist_exn
                            [
                              ( "__eq__",
                                ExpressionCallees.from_call
                                  (CallCallees.create
                                     ~call_targets:
                                       [
                                         CallTarget.create_regular
                                           ~implicit_receiver:true
                                           ~receiver_class:"int"
                                           ~return_type:(Some ReturnType.bool)
                                           ~index:0
                                           (Target.Regular.Method
                                              {
                                                class_name = "int";
                                                method_name = "__eq__";
                                                kind = Normal;
                                              });
                                       ]
                                     ()) );
                              ( "__ne__",
                                ExpressionCallees.from_call
                                  (CallCallees.create
                                     ~call_targets:
                                       [
                                         CallTarget.create_regular
                                           ~implicit_receiver:true
                                           ~receiver_class:"int"
                                           ~return_type:(Some ReturnType.bool)
                                           ~index:0
                                           (Target.Regular.Method
                                              {
                                                class_name = "int";
                                                method_name = "__ne__";
                                                kind = Normal;
                                              });
                                       ]
                                     ()) );
                            ]) );
                     ( "6:11-6:14",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.bar"; kind = Normal });
                                 ]
                               ())) );
                     ( "8:11-8:16",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.foo"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.bar"; kind = Normal });
                   ];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:
             {|
     def propagate(x):
       return x
     def bar():
       return 0
     def foo():
       return propagate(bar)
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.foo"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "7:9-7:23",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create
                                     (create_parameterized_target
                                        ~regular:
                                          (Target.Regular.Function
                                             { name = "test.propagate"; kind = Normal })
                                        ~parameters:
                                          [
                                            ( create_positional_parameter 0 "x",
                                              Target.Regular.Function
                                                { name = "test.bar"; kind = Normal }
                                              |> Target.from_regular );
                                          ]);
                                 ]
                               ())) );
                     ( "7:19-7:22",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.bar"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.bar"; kind = Normal });
                   ];
               };
               {
                 Expected.callable =
                   create_parameterized_target
                     ~regular:(Target.Regular.Function { name = "test.propagate"; kind = Normal })
                     ~parameters:
                       [
                         ( create_positional_parameter 0 "x",
                           Target.Regular.Function { name = "test.bar"; kind = Normal }
                           |> Target.from_regular );
                       ];
                 call_graph = [];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.bar"; kind = Normal });
                   ];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:
             {|
     def propagate(x):
       return x
     def wrap_propagate(x):
       return propagate(x)
     def bar():
       return 0
     def foo():
       return wrap_propagate(bar)
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.foo"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "9:9-9:28",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create
                                     (create_parameterized_target
                                        ~regular:
                                          (Target.Regular.Function
                                             { name = "test.wrap_propagate"; kind = Normal })
                                        ~parameters:
                                          [
                                            ( create_positional_parameter 0 "x",
                                              Target.Regular.Function
                                                { name = "test.bar"; kind = Normal }
                                              |> Target.from_regular );
                                          ]);
                                 ]
                               ())) );
                     ( "9:24-9:27",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.bar"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables =
                   [
                     CallTarget.create_regular
                       (Target.Regular.Function { name = "test.bar"; kind = Normal });
                   ];
               };
             ]
           ();
      labeled_test_case __FUNCTION__ __LINE__
      @@ assert_higher_order_call_graph_fixpoint
           ~source:
             {|
     def decorator(f):
       def inner():
         f()
       return inner
     def bar():
       return 0
     def foo():
       return decorator(bar)
  |}
           ~expected:
             [
               {
                 Expected.callable =
                   Target.Regular.Function { name = "test.foo"; kind = Normal }
                   |> Target.from_regular;
                 call_graph =
                   [
                     ( "9:9-9:23",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_call
                            (CallCallees.create
                               ~call_targets:
                                 [
                                   CallTarget.create
                                     (create_parameterized_target
                                        ~regular:
                                          (Target.Regular.Function
                                             { name = "test.decorator"; kind = Normal })
                                        ~parameters:
                                          [
                                            ( create_positional_parameter 0 "f",
                                              Target.Regular.Function
                                                { name = "test.bar"; kind = Normal }
                                              |> Target.from_regular );
                                          ]);
                                 ]
                               ())) );
                     ( "9:19-9:22",
                       LocationCallees.Singleton
                         (ExpressionCallees.from_attribute_access
                            (AttributeAccessCallees.create
                               ~callable_targets:
                                 [
                                   CallTarget.create_regular
                                     (Target.Regular.Function { name = "test.bar"; kind = Normal });
                                 ]
                               ())) );
                   ];
                 returned_callables = [];
                 (* TODO: Expect `inner` with `f=bar` *)
               };
             ]
           ();
    ]


let () = "callGraphFixpoint" >::: [test_higher_order_call_graph_fixpoint] |> Test.run
