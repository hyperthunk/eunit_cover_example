-module(coverage_tests).
-include_lib("eunit/include/eunit.hrl").

basic_test() ->
    ?assertEqual(sample_module:demo(1), 1),
    ?assertEqual(sample_module:demo2(1), [1]),
    ?assertEqual(sample_module:demo3(2), 1).
