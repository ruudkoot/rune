(* Deterministic counter comparisons and reviewed budgets. Instruction counts
   agree within an execution model; allocation agrees across Rune engines. *)
structure BenchCounts =
struct
  type row = {name:string, profile:string, config:string, level:string,
              instructions:IntInf.int, bytes:IntInf.int, objects:IntInf.int}
  fun number s =
    case IntInf.fromString s of
      SOME n => if n >= 0 andalso IntInf.toString n = s then n else raise Fail "invalid count"
    | NONE => raise Fail "missing count"
  fun load path =
    List.mapPartial (fn line =>
      case String.fields (fn c => c = #"\t") (BenchCatalog.strip line) of
        [name,profile,config,level,phase,_,_,status,_,_,_,_,instructions,bytes,objects,_] =>
          if phase <> "count" orelse status <> "pass" then NONE
          else SOME {name=name,profile=profile,config=config,level=level,
                     instructions=number instructions,bytes=number bytes,objects=number objects}
      | _ => raise Fail "invalid counter sample row") (List.tl (BenchCatalog.lines path))
  fun key (r:row) = (#name r,#profile r,#config r,#level r)
  fun model config =
    if List.exists (fn c => c = config) ["rune","rune:opt"] then "stack"
    else if List.exists (fn c => c = config) ["rune:new","rune:jit"] then "register"
    else raise Fail "unknown counter execution model"
  fun compare rows =
    let
      fun check (a:row,b:row) =
        if #name a = #name b andalso #profile a = #profile b andalso #level a = #level b then
          if #bytes a <> #bytes b orelse #objects a <> #objects b then raise Fail "allocation counts disagree"
          else if model (#config a) = model (#config b) andalso #instructions a <> #instructions b
          then raise Fail "instruction counts disagree within execution model" else ()
        else ()
    in List.app (fn a => List.app (fn b => check (a,b)) rows) rows end
  fun budgets path =
    if not (OS.FileSys.access (path,[OS.FileSys.A_READ])) then []
    else List.map (fn line =>
      case String.fields (fn c => c = #"\t") (BenchCatalog.strip line) of
        [name,profile,config,level,instructions,bytes,objects] =>
          {name=name,profile=profile,config=config,level=level,
           instructions=number instructions,bytes=number bytes,objects=number objects}
      | _ => raise Fail "invalid counter budget") (List.tl (BenchCatalog.lines path))
  fun verify rows limits =
    List.app (fn (r:row) =>
      case List.find (fn b => key b = key r) limits of
        NONE => print ("COUNT unbudgeted " ^ #name r ^ " " ^ #profile r ^ " " ^ #config r ^ "\n")
      | SOME b =>
          if #instructions r > #instructions b orelse #bytes r > #bytes b orelse #objects r > #objects b
          then raise Fail ("count budget exceeded: " ^ #name r ^ " " ^ #config r)
          else print ("COUNT within-budget " ^ #name r ^ " " ^ #config r ^ "\n")) rows
  fun write path rows old =
    let val out = TextIO.openOut (path ^ ".tmp")
        fun margin n = n + IntInf.div (n,10)
        fun emit (r:row) = TextIO.output (out,String.concatWith "\t"
          [#name r,#profile r,#config r,#level r,IntInf.toString (margin (#instructions r)),
           IntInf.toString (margin (#bytes r)),IntInf.toString (margin (#objects r))] ^ "\n")
        val _ = TextIO.output (out,"benchmark\tprofile\tconfig\tlevel\tinstructions\tbytes\tobjects\n")
        (* Existing budgets already carry their headroom. *)
        val _ = List.app (fn (b:row) => TextIO.output (out,String.concatWith "\t"
          [#name b,#profile b,#config b,#level b,IntInf.toString (#instructions b),
           IntInf.toString (#bytes b),IntInf.toString (#objects b)] ^ "\n"))
          (List.filter (fn b => not (List.exists (fn r => key r = key b) rows)) old)
        val _ = List.app emit rows
        val _ = TextIO.closeOut out
    in OS.FileSys.rename {old=path ^ ".tmp",new=path} end
  fun main () =
    case CommandLine.arguments () of
      [samples,path,mode] =>
        let val rows = load samples
            val _ = if List.null rows then raise Fail "no accepted counter samples" else ()
            val _ = compare rows
            val old = budgets path
        in if mode = "update" then write path rows old
           else if mode = "check" then verify rows old else raise Fail "invalid count mode";
           print "COUNT comparisons agree\n" end
    | _ => raise Fail "usage: bench-counts SAMPLES BUDGETS check|update"
end
