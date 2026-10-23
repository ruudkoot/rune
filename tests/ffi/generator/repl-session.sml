(* Ordinary REPL source: the generated public and raw sessions remain live
   while later -e entries compile declarations, allocate and collect. *)
structure GeneratedScalarRepl =
struct
  val sessions=ref(NONE:(GeneratedScalars.session * GeneratedScalarsRaw.session) option)
  val collections=ref 0
  fun need message ok=if ok then () else raise Fail message
  fun required name=case OS.Process.getEnv name of SOME value=>value | NONE=>raise Fail("missing " ^ name)
  fun check(public,raw)=
    let val result=GeneratedScalarsRaw.gen_add raw [RuneForeign.Signed 20,RuneForeign.Signed 22]
    in need "generated public record projection"(GeneratedScalars.add public {first=20,second=22}=42);
       need "generated raw status"(size(#bytes result)=8 andalso not(isSome(#pointer result)) andalso
         PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)=0w42) end
  fun beginSession()=
    let val ()=need "REPL initial native resources"(RuneForeign.live()=0w0)
        val paths=[required "RUNE_SCALAR_REPL_LIBRARY"]
        val public=GeneratedScalars.openSession{libraries=paths}
        val raw=GeneratedScalarsRaw.openSession{libraries=paths}
        val ()=sessions:=SOME(public,raw)
        val ()=check(public,raw)
        val ()=need "sessions must retain prepared native calls"(RuneForeign.live()>0w0)
    in collections:= #collections(Runtime.stats()) end
  fun finishSession()=
    let val pair as (public,raw)=valOf(!sessions)
        val ()=need "later REPL entry did not collect"(#collections(Runtime.stats())> !collections)
        val ()=check pair
        val ()=GeneratedScalars.closeSession public
        val ()=GeneratedScalarsRaw.closeSession raw
        val ()=sessions:=NONE
        val ()=need "generated REPL native resource cleanup"(RuneForeign.live()=0w0)
    in print "PASS current generated scalar REPL: public=42 raw-status=42 native-resources=0\n" end
end
