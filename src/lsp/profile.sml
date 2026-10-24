(* Optional local measurements. Normal protocol stdout is never used. *)
structure RuneLspProfile =
struct
  val path=OS.Process.getEnv "RUNE_LSP_PROFILE"
  val stream=case path of NONE=>NONE | SOME file=>SOME(TextIO.openAppend file)
  val timer=Timer.startRealTimer()
  val role=if List.exists(fn arg=>arg="--analysis-worker")(CommandLine.arguments()) then "worker" else "server"
  val job=ref "startup"
  fun sample phase file checked reused items = case stream of NONE=>() | SOME stream=>
    let val stats=Runtime.stats()
        val record=Json.Object[("role",Json.String role),("job",Json.String(!job)),("phase",Json.String phase),("file",Json.String file),
          ("microseconds",Json.intInf(Time.toMicroseconds(Timer.checkRealTimer timer))),
          ("allocated",Json.int(#bytes stats)),("live",Json.int(#live stats)),("heap",Json.int(#heapSize stats)),
          ("collections",Json.int(#collections stats)),("checked",Json.int checked),("reused",Json.int reused),("items",Json.int items)]
    in TextIO.output(stream,Json.encode record ^ "\n");TextIO.flushOut stream end
  fun observe ({phase,file,checked,reused,items}:RuneCompiler.Analysis.observation)=sample phase file checked reused items
  fun retained ()=case stream of NONE=>() | SOME _=>
    if OS.Process.getEnv "RUNE_LSP_PROFILE_GC"=SOME "1" then
      (Runtime.collect();sample "job-retained" "" 0 0 0) else ()
end
