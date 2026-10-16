(* Statistics and acceptance of samples belong to portable SML, not to the
   operating-system adapter. The raw table retains every phase and failure. *)
structure BenchReport =
struct
  type row = {name:string, profile:string, config:string, level:string,
              phase:string, process:string, round:string, status:string,
              seconds:real, user:string, system:string, rss:string,
              instructions:string, bytes:string, objects:string, artifact:string}
  fun parse line : row =
    case String.fields (fn c => c = #"\t") (BenchCatalog.strip line) of
      [name,profile,config,level,phase,process,round,status,seconds,user,system,rss,instructions,bytes,objects,artifact] =>
        {name=name,profile=profile,config=config,level=level,phase=phase,
         process=process,round=round,status=status,
         seconds=(case Real.fromString seconds of
                    SOME r => if Real.isFinite r andalso r >= 0.0 then r else raise Fail "invalid seconds"
                  | NONE => raise Fail "invalid seconds"),
         user=user,system=system,rss=rss,instructions=instructions,bytes=bytes,objects=objects,artifact=artifact}
    | _ => raise Fail "invalid measurement row"
  fun insert x [] = [x]
    | insert x (y::ys) = if x < (y:real) then x::y::ys else y::insert x ys
  fun quantile sorted p =
    let val index = Real.fromInt (List.length sorted - 1) * p
        val low = Real.floor index
        val fraction = index - Real.fromInt low
        val a = List.nth (sorted,low)
        val b = List.nth (sorted,Int.min (low+1,List.length sorted-1))
    in a + fraction * (b-a) end
  fun fmt r = Real.fmt (StringCvt.FIX (SOME 9)) r
  fun key (r:row) = (#name r,#profile r,#config r,#level r,#phase r)
  fun report rows =
    let
      val keys = List.foldl (fn (r,acc) =>
        if List.exists (fn k => k = key r) acc then acc else acc @ [key r]) [] rows
      fun group (k as (name,profile,config,level,phase)) =
        let val all = List.filter (fn r => key r = k) rows
            val valid = List.filter (fn (r:row) => #status r = "pass") all
            val times = List.foldl (fn (r:row,acc) => insert (#seconds r) acc) [] valid
            val stats = if List.null times then "- | -"
                        else fmt (quantile times 0.5) ^ " | " ^
                             fmt (quantile times 0.25) ^ " to " ^ fmt (quantile times 0.75)
            val counts = if phase = "count" andalso not (List.null valid)
                         then let val r = List.hd valid
                              in #instructions r ^ "/" ^ #bytes r ^ "/" ^ #objects r end
                         else "-"
        in print ("| " ^ String.concatWith " | " [name,profile,config,level,phase,
                  Int.toString (List.length valid) ^ "/" ^ Int.toString (List.length all)] ^
                  " | " ^ stats ^ " | " ^ counts ^ " |\n") end
    in
      print "# Benchmark measurement report\n\n";
      print "Every raw sample, failed phase and configuration is retained in `samples.tsv`.\n";
      print "Metadata and source/input snapshots accompany this report. Compilation is\n";
      print "separate from execution. Fresh samples include process startup and shutdown;\n";
      print "repeated samples time Benchmark.run in process. First rounds are retained;\n";
      print "no steady-state or causal performance claim is inferred. Times are seconds.\n";
      print "IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.\n\n";
      print "| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |\n";
      print "|---|---|---|---|---|---|---|---|---|\n";
      List.app group keys;
      print "\nFailure categories and artifact paths:\n\n";
      List.app (fn (r:row) => if #status r = "pass" then ()
                else print ("- " ^ #name r ^ " / " ^ #config r ^ " / " ^ #phase r ^
                            ": " ^ #status r ^ " (`" ^ #artifact r ^ "`).\n")) rows
    end
  fun main () =
    case CommandLine.arguments () of
      [path] => report (List.map parse (List.tl (BenchCatalog.lines path)))
    | _ => raise Fail "usage: bench-report SAMPLES.tsv"
end
