%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ Coverage.
%%
%%   The Initial Developers of the Original Code are Rabbit Technologies Ltd.
%%
%%   Copyright (C) 2010 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(coverage).

-rabbit_boot_step({coverage,
                   [{description, "code coverage"},
                    {mfa,         {?MODULE, start_coverage, []}},
                    {enables,     pre_boot}]}).

-behaviour(application).
-behaviour(supervisor).

-export([start_coverage/0]).
-export([start/0, start/2, stop/1]).
-export([init/1]). 

start() ->
    application:start(coverage).

stop(_State) ->
    io:format(user, "stoping coverage application (~p)~n",
              [cover:modules()]),
    case application:get_env(coverage, directories) of
        undefined ->
            ok;
        {ok, []} ->
            ok;
        _ ->
            report_cover(),
            cover:stop()
    end.

start(normal, []) -> 
    start_coverage(),
    supervisor:start_link(?MODULE, []).

start_coverage() ->
    dbg:tracer(), % port, dbg:trace_port(file, "/tmp/rabbit-trace.log")),
    dbg:tp(cover, '_', '_', [{'_',[],[{return_trace}]}]),
    dbg:p(all,[c, return_to]),
    case application:get_env(coverage, directories) of
        undefined ->
            ok;
        {ok, []} ->
            ok;
        {ok, Directories} ->
            {ok, _} = cover:start([node() | nodes()]),
            lists:foldl(
              fun (Dir, ok) ->
                      case cover:compile_beam_directory(Dir) of
                          {error, _} = Err -> throw(Err);
                          _                -> ok
                      end
              end, ok, Directories)
    end.

init([]) -> 
    {ok, {{one_for_all, 0, 1}, []}}.

report_cover() -> report_cover(["."]).

report_cover(Dirs) -> [report_cover1(lists:concat([Dir])) || Dir <- Dirs], ok.

report_cover1(Root) ->
    Dir = filename:join(Root, "cover"),
    ok = filelib:ensure_dir(filename:join(Dir, "junk")),
    lists:foreach(fun (F) -> file:delete(F) end,
                  filelib:wildcard(filename:join(Dir, "*.html"))),
    {ok, SummaryFile} = file:open(filename:join(Dir, "summary.txt"), [write]),
    {CT, NCT} =
        lists:foldl(
          fun (M,{CovTot, NotCovTot}) ->
                  {ok, {M, {Cov, NotCov}}} = cover:analyze(M, module),
                  ok = report_coverage_percentage(Cov, NotCov, M),
                  {ok,_} = cover:analyze_to_file(
                             M,
                             filename:join(Dir, atom_to_list(M) ++ ".html"),
                             [html]),
                  {CovTot+Cov, NotCovTot+NotCov}
          end,
          {0, 0},
          lists:sort(cover:modules())),
    ok = report_coverage_percentage(CT, NCT, 'TOTAL'),
    ok = file:close(SummaryFile),
    ok.

report_coverage_percentage(Cov, NotCov, Mod) ->
    io:format(user, "~6.2f ~p~n",
              [if
                   Cov+NotCov > 0 -> 100.0*Cov/(Cov+NotCov);
                   true -> 100.0
               end,
               Mod]).

