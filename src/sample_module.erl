-module(sample_module).

-compile(export_all).

demo(N) -> N.
demo2(N) -> [N].
demo3(_N) -> 1.